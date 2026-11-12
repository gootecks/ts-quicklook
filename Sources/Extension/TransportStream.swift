import Foundation

enum TransportStream {
    static func matches(_ head: Data) -> Bool {
        let count = head.count
        if count == 0 { return false }
        let sizes = [188, 192, 204]
        let maxStart = min(1024, count)
        return head.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Bool in
            for size in sizes {
                for start in 0..<maxStart {
                    let last = start + 4 * size
                    if last >= count { break }
                    if raw[start] != 0x47 { continue }
                    var ok = true
                    for k in 1...4 where raw[start + k * size] != 0x47 {
                        ok = false
                        break
                    }
                    if ok { return true }
                }
            }
            return false
        }
    }
}
