import Foundation
import zlib

struct GitObject {
    enum Kind: Int { case commit = 1, tree = 2, blob = 3, tag = 4 }

    let kind: Kind
    let data: Data
}

extension UnsafeRawBufferPointer {
    func be32(_ offset: Int) -> Int {
        Int(self[offset]) << 24 | Int(self[offset + 1]) << 16 | Int(self[offset + 2]) << 8 | Int(self[offset + 3])
    }
}

extension Data {
    init?(gitHex text: String) {
        let characters = Array(text)
        guard characters.count == 40 || characters.count == 64 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(characters.count / 2)
        for index in stride(from: 0, to: characters.count, by: 2) {
            guard let high = characters[index].hexDigitValue,
                  let low = characters[index + 1].hexDigitValue
            else { return nil }
            bytes.append(UInt8(high << 4 | low))
        }
        self.init(bytes)
    }

    var gitHex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

enum GitZlib {
    static let limit = 64 << 20

    static func decompress(_ source: UnsafeRawBufferPointer, from offset: Int, expected: Int?) -> Data? {
        guard offset >= 0, offset < source.count, let base = source.baseAddress else { return nil }
        var stream = z_stream()
        guard inflateInit_(&stream, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else { return nil }
        defer { inflateEnd(&stream) }
        stream.next_in = UnsafeMutablePointer(mutating: base.advanced(by: offset).assumingMemoryBound(to: UInt8.self))
        stream.avail_in = UInt32(min(source.count - offset, Int(UInt32.max)))

        var output = [UInt8](repeating: 0, count: max(expected ?? 16384, 64))
        var written = 0
        while true {
            let status: Int32 = output.withUnsafeMutableBufferPointer { buffer in
                stream.next_out = buffer.baseAddress! + written
                stream.avail_out = UInt32(buffer.count - written)
                let status = zlib.inflate(&stream, Z_NO_FLUSH)
                written = buffer.count - Int(stream.avail_out)
                return status
            }
            if status == Z_STREAM_END {
                break
            }
            guard status == Z_OK, written == output.count, output.count < limit else { return nil }
            output.append(contentsOf: repeatElement(0, count: output.count))
        }
        return Data(output[0 ..< written])
    }
}

final class GitPack {
    private let index: Data
    private let pack: Data
    private let hashSize: Int
    private let count: Int
    private let namesOffset: Int
    private let offsetsOffset: Int
    private let largeOffset: Int

    init?(indexURL: URL, hashSize: Int) {
        let packURL = indexURL.deletingPathExtension().appendingPathExtension("pack")
        guard let index = try? Data(contentsOf: indexURL, options: .alwaysMapped),
              let pack = try? Data(contentsOf: packURL, options: .alwaysMapped),
              index.count >= 8 + 1024,
              index.prefix(8).elementsEqual([0xFF, 0x74, 0x4F, 0x63, 0, 0, 0, 2])
        else { return nil }
        let count = index.withUnsafeBytes { $0.be32(8 + 255 * 4) }
        self.index = index
        self.pack = pack
        self.hashSize = hashSize
        self.count = count
        namesOffset = 8 + 1024
        offsetsOffset = namesOffset + count * hashSize + count * 4
        largeOffset = offsetsOffset + count * 4
        guard index.count >= largeOffset + 2 * hashSize else { return nil }
    }

    func offset(of id: Data) -> Int? {
        index.withUnsafeBytes { raw -> Int? in
            id.withUnsafeBytes { key -> Int? in
                guard let names = raw.baseAddress, let target = key.baseAddress else { return nil }
                let first = Int(key[0])
                var low = first == 0 ? 0 : raw.be32(8 + (first - 1) * 4)
                var high = raw.be32(8 + first * 4)
                guard low <= high, high <= count else { return nil }
                while low < high {
                    let middle = (low + high) / 2
                    let order = memcmp(names + namesOffset + middle * hashSize, target, hashSize)
                    if order == 0 {
                        let value = raw.be32(offsetsOffset + middle * 4)
                        if value & 0x8000_0000 == 0 {
                            return value
                        }
                        let position = largeOffset + (value & 0x7FFF_FFFF) * 8
                        guard position + 8 <= raw.count else { return nil }
                        return raw.be32(position) << 32 | raw.be32(position + 4)
                    }
                    if order < 0 {
                        low = middle + 1
                    } else {
                        high = middle
                    }
                }
                return nil
            }
        }
    }

    func object(at offset: Int, store: GitObjectStore, depth: Int) -> GitObject? {
        guard depth < 128 else { return nil }
        return pack.withUnsafeBytes { raw -> GitObject? in
            var position = offset
            guard let header = Self.readHeader(raw, position: &position),
                  header.size <= GitZlib.limit
            else { return nil }

            if let kind = GitObject.Kind(rawValue: header.type) {
                guard let data = GitZlib.decompress(raw, from: position, expected: header.size) else { return nil }
                return GitObject(kind: kind, data: data)
            }

            let base: GitObject?
            if header.type == 6 {
                base = deltaBaseByOffset(raw, position: &position, offset: offset, store: store, depth: depth)
            } else if header.type == 7 {
                guard position + hashSize <= raw.count else { return nil }
                let id = Data(raw[position ..< position + hashSize])
                position += hashSize
                base = store.object(id, depth: depth + 1)
            } else {
                return nil
            }

            guard let base,
                  let delta = GitZlib.decompress(raw, from: position, expected: header.size),
                  let data = Self.apply([UInt8](delta), to: [UInt8](base.data))
            else { return nil }
            return GitObject(kind: base.kind, data: data)
        }
    }

    private static func readHeader(
        _ raw: UnsafeRawBufferPointer,
        position: inout Int
    ) -> (type: Int, size: Int)? {
        guard position >= 0, position < raw.count else { return nil }
        var byte = raw[position]
        position += 1
        let type = Int(byte >> 4) & 7
        var size = Int(byte & 0x0F)
        var shift = 4
        while byte & 0x80 != 0 {
            guard position < raw.count, shift < 60 else { return nil }
            byte = raw[position]
            position += 1
            size |= Int(byte & 0x7F) << shift
            shift += 7
        }
        return (type, size)
    }

    private func deltaBaseByOffset(
        _ raw: UnsafeRawBufferPointer,
        position: inout Int,
        offset: Int,
        store: GitObjectStore,
        depth: Int
    ) -> GitObject? {
        guard position < raw.count else { return nil }
        var byte = raw[position]
        position += 1
        var distance = Int(byte & 0x7F)
        while byte & 0x80 != 0 {
            guard position < raw.count, distance < 1 << 48 else { return nil }
            byte = raw[position]
            position += 1
            distance = ((distance + 1) << 7) | Int(byte & 0x7F)
        }
        guard distance > 0, distance <= offset else { return nil }
        return object(at: offset - distance, store: store, depth: depth + 1)
    }

    private static func readCopyOperand(
        _ command: UInt8,
        _ delta: [UInt8],
        _ position: inout Int
    ) -> (start: Int, length: Int)? {
        var start = 0
        var length = 0
        for bit in 0 ..< 4 where command & (1 << bit) != 0 {
            guard position < delta.count else { return nil }
            start |= Int(delta[position]) << (8 * bit)
            position += 1
        }
        for bit in 0 ..< 3 where command & (0x10 << bit) != 0 {
            guard position < delta.count else { return nil }
            length |= Int(delta[position]) << (8 * bit)
            position += 1
        }
        return (start, length == 0 ? 0x10000 : length)
    }

    private static func apply(_ delta: [UInt8], to base: [UInt8]) -> Data? {
        var position = 0

        func size() -> Int? {
            var value = 0
            var shift = 0
            while position < delta.count, shift < 60 {
                let byte = delta[position]
                position += 1
                value |= Int(byte & 0x7F) << shift
                if byte & 0x80 == 0 {
                    return value
                }
                shift += 7
            }
            return nil
        }

        guard let baseSize = size(), baseSize == base.count,
              let resultSize = size(), resultSize <= GitZlib.limit
        else { return nil }
        var output = [UInt8]()
        output.reserveCapacity(resultSize)

        while position < delta.count {
            let command = delta[position]
            position += 1
            if command & 0x80 != 0 {
                guard let (start, length) = readCopyOperand(command, delta, &position) else { return nil }
                guard start + length <= base.count else { return nil }
                output.append(contentsOf: base[start ..< start + length])
            } else if command != 0 {
                let length = Int(command)
                guard position + length <= delta.count else { return nil }
                output.append(contentsOf: delta[position ..< position + length])
                position += length
            } else {
                return nil
            }
        }
        guard output.count == resultSize else { return nil }
        return Data(output)
    }
}

final class GitObjectStore {
    private let directories: [URL]
    private let hashSize: Int

    private lazy var packs: [GitPack] = directories.flatMap { directory -> [GitPack] in
        let folder = directory.appendingPathComponent("pack")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.filter { $0.hasSuffix(".idx") }.compactMap {
            GitPack(indexURL: folder.appendingPathComponent($0), hashSize: hashSize)
        }
    }

    init(objectsDirectory: URL, hashSize: Int) {
        var all = [objectsDirectory]
        let alternates = objectsDirectory.appendingPathComponent("info/alternates")
        if let text = try? String(contentsOf: alternates, encoding: .utf8) {
            for line in text.split(separator: "\n") where !line.hasPrefix("#") {
                all.append(URL(fileURLWithPath: String(line), relativeTo: objectsDirectory).standardizedFileURL)
            }
        }
        directories = all
        self.hashSize = hashSize
    }

    func object(_ id: Data, depth: Int = 0) -> GitObject? {
        guard id.count == hashSize, depth < 128 else { return nil }
        for pack in packs {
            if let offset = pack.offset(of: id) {
                return pack.object(at: offset, store: self, depth: depth)
            }
        }
        let hex = id.gitHex
        for directory in directories {
            let url = directory
                .appendingPathComponent(String(hex.prefix(2)))
                .appendingPathComponent(String(hex.dropFirst(2)))
            if let compressed = try? Data(contentsOf: url), let object = Self.loose(compressed) {
                return object
            }
        }
        return nil
    }

    private static func loose(_ compressed: Data) -> GitObject? {
        let inflated = compressed.withUnsafeBytes { GitZlib.decompress($0, from: 0, expected: nil) }
        guard let raw = inflated, let end = raw.firstIndex(of: 0), let header = String(
            bytes: raw[..<end],
            encoding: .utf8
        ) else { return nil }
        let kind: GitObject.Kind
        switch header.split(separator: " ").first {
        case "commit": kind = .commit
        case "tree": kind = .tree
        case "blob": kind = .blob
        case "tag": kind = .tag
        default: return nil
        }
        return GitObject(kind: kind, data: Data(raw[(end + 1)...]))
    }
}
