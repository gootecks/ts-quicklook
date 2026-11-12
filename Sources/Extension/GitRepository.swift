import CryptoKit
import Foundation

struct GitCommit {
    let id: Data
    let tree: Data
    let parents: [Data]
    let date: Date?
    let subject: String
}

final class GitRepository {
    private struct EntryKey: Hashable {
        let tree: Data
        let name: String
    }

    private struct Entry {
        let id: Data
        let isTree: Bool
    }

    let head: Data?
    private let gitDirectory: URL
    private let hashSize: Int
    private let store: GitObjectStore
    private var entries: [EntryKey: Entry?] = [:]

    private init(gitDirectory: URL, commonDirectory: URL) {
        self.gitDirectory = gitDirectory
        head = Self.resolve("HEAD", in: [gitDirectory, commonDirectory])
        hashSize = head?.count ?? 20
        store = GitObjectStore(objectsDirectory: commonDirectory.appendingPathComponent("objects"), hashSize: hashSize)
    }

    static func discover(containing file: URL) -> (repository: GitRepository, path: [String])? {
        let resolved = file.resolvingSymlinksInPath()
        var directory = resolved.deletingLastPathComponent()
        var path = [resolved.lastPathComponent]
        let manager = FileManager.default

        for _ in 0 ..< 128 {
            let marker = directory.appendingPathComponent(".git")
            var isDirectory: ObjCBool = false
            if manager.fileExists(atPath: marker.path, isDirectory: &isDirectory) {
                var gitDirectory = marker
                if !isDirectory.boolValue {
                    guard let text = try? String(contentsOf: marker, encoding: .utf8),
                          text.hasPrefix("gitdir:")
                    else { return nil }
                    let target = text.dropFirst(7).trimmingCharacters(in: .whitespacesAndNewlines)
                    gitDirectory = URL(fileURLWithPath: target, relativeTo: directory).standardizedFileURL
                }
                var commonDirectory = gitDirectory
                let pointer = gitDirectory.appendingPathComponent("commondir")
                if let text = try? String(contentsOf: pointer, encoding: .utf8) {
                    let target = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    commonDirectory = URL(fileURLWithPath: target, relativeTo: gitDirectory).standardizedFileURL
                }
                return (GitRepository(gitDirectory: gitDirectory, commonDirectory: commonDirectory), path)
            }
            guard directory.path != "/" else { return nil }
            path.insert(directory.lastPathComponent, at: 0)
            directory.deleteLastPathComponent()
        }
        return nil
    }

    private static func resolve(_ name: String, in directories: [URL], depth: Int = 0) -> Data? {
        guard depth < 8, !name.contains("..") else { return nil }
        for directory in directories {
            guard let text = try? String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8) else {
                continue
            }
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.hasPrefix("ref:") {
                let target = value.dropFirst(4).trimmingCharacters(in: .whitespaces)
                return resolve(target, in: directories, depth: depth + 1)
            }
            return Data(gitHex: value)
        }
        guard let common = directories.last,
              let packed = try? String(contentsOf: common.appendingPathComponent("packed-refs"), encoding: .utf8)
        else { return nil }
        let suffix = " " + name
        for line in packed.split(separator: "\n") where line.hasSuffix(suffix) {
            return Data(gitHex: String(line.dropLast(suffix.count)))
        }
        return nil
    }

    func commit(_ id: Data) -> GitCommit? {
        guard let object = store.object(id), object.kind == .commit else { return nil }
        let text = String(decoding: object.data, as: UTF8.self)
        let split = text.range(of: "\n\n")
        let header = split.map { text[..<$0.lowerBound] } ?? text[...]
        let message = split.map { text[$0.upperBound...] } ?? ""

        var tree: Data?
        var parents: [Data] = []
        var date: Date?
        for line in header.split(separator: "\n") {
            if line.hasPrefix("tree ") {
                tree = Data(gitHex: String(line.dropFirst(5)))
            } else if line.hasPrefix("parent ") {
                if let parent = Data(gitHex: String(line.dropFirst(7))) { parents.append(parent) }
            } else if line.hasPrefix("committer ") {
                let fields = line.split(separator: " ")
                if fields.count >= 3, let seconds = TimeInterval(fields[fields.count - 2]) {
                    date = Date(timeIntervalSince1970: seconds)
                }
            }
        }
        guard let tree else { return nil }
        let subject = message.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? ""
        return GitCommit(id: id, tree: tree, parents: parents, date: date, subject: subject)
    }

    func blob(_ id: Data) -> Data? {
        guard let object = store.object(id), object.kind == .blob else { return nil }
        return object.data
    }

    func blobID(at path: [String], in tree: Data) -> Data? {
        var current = tree
        for (index, component) in path.enumerated() {
            guard let found = entry(component, in: current) else { return nil }
            if index == path.count - 1 { return found.isTree ? nil : found.id }
            guard found.isTree else { return nil }
            current = found.id
        }
        return nil
    }

    private func entry(_ name: String, in tree: Data) -> Entry? {
        let key = EntryKey(tree: tree, name: name)
        if let cached = entries[key] { return cached }
        let found = lookup(name, in: tree)
        entries[key] = .some(found)
        return found
    }

    private func lookup(_ name: String, in tree: Data) -> Entry? {
        guard let object = store.object(tree), object.kind == .tree else { return nil }
        let bytes = [UInt8](object.data)
        let target = Array(name.utf8)
        var position = 0
        while position < bytes.count {
            guard let space = bytes[position...].firstIndex(of: 0x20),
                  let end = bytes[space...].firstIndex(of: 0),
                  end + 1 + hashSize <= bytes.count
            else { return nil }
            if bytes[(space + 1) ..< end].elementsEqual(target) {
                let isTree = bytes[position ..< space].elementsEqual("40000".utf8)
                return Entry(id: Data(bytes[(end + 1) ..< (end + 1 + hashSize)]), isTree: isTree)
            }
            position = end + 1 + hashSize
        }
        return nil
    }

    func lastChange(of path: [String], blob: Data, from head: GitCommit) -> (commit: GitCommit, previous: Data?)? {
        var current = head
        let deadline = Date().addingTimeInterval(1.5)
        while Date() < deadline {
            guard !current.parents.isEmpty else { return (current, nil) }
            var unchanged: GitCommit?
            var previous: Data?
            for (index, id) in current.parents.enumerated() {
                guard let parent = commit(id) else { return nil }
                let found = blobID(at: path, in: parent.tree)
                if found == blob {
                    unchanged = parent
                    break
                }
                if index == 0 { previous = found }
            }
            guard let next = unchanged else { return (current, previous) }
            current = next
        }
        return nil
    }

    func blobHash(of contents: Data) -> Data {
        let header = Data("blob \(contents.count)\u{0}".utf8)
        if hashSize == 32 {
            var hasher = SHA256()
            hasher.update(data: header)
            hasher.update(data: contents)
            return Data(hasher.finalize())
        }
        var hasher = Insecure.SHA1()
        hasher.update(data: header)
        hasher.update(data: contents)
        return Data(hasher.finalize())
    }

    func indexContains(_ path: String) -> Bool {
        let url = gitDirectory.appendingPathComponent("index")
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return false }
        let target = Array(path.utf8)
        let fixed = 40 + hashSize + 2

        return data.withUnsafeBytes { raw -> Bool in
            guard raw.count >= 12, raw[0 ..< 4].elementsEqual("DIRC".utf8) else { return false }
            let version = raw.be32(4)
            let count = raw.be32(8)
            guard (2 ... 4).contains(version) else { return false }
            var position = 12
            var previous: [UInt8] = []

            for _ in 0 ..< count {
                guard position + fixed <= raw.count else { return false }
                let flags = Int(raw[position + fixed - 2]) << 8 | Int(raw[position + fixed - 1])
                var cursor = position + fixed
                if version >= 3, flags & 0x4000 != 0 { cursor += 2 }

                if version == 4 {
                    guard cursor < raw.count else { return false }
                    var byte = raw[cursor]
                    cursor += 1
                    var strip = Int(byte & 0x7f)
                    while byte & 0x80 != 0 {
                        guard cursor < raw.count, strip < 1 << 32 else { return false }
                        byte = raw[cursor]
                        cursor += 1
                        strip = ((strip + 1) << 7) | Int(byte & 0x7f)
                    }
                    guard strip <= previous.count else { return false }
                    previous.removeLast(strip)
                    while cursor < raw.count, raw[cursor] != 0 {
                        previous.append(raw[cursor])
                        cursor += 1
                    }
                    if previous == target { return true }
                    position = cursor + 1
                } else {
                    var end = cursor
                    while end < raw.count, raw[end] != 0 { end += 1 }
                    if end - cursor == target.count, raw[cursor ..< end].elementsEqual(target) { return true }
                    position += (end - position + 8) & ~7
                }
            }
            return false
        }
    }
}
