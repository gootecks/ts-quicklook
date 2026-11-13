import Foundation

enum TransportStream {
    static func matches(_ head: Data) -> Bool {
        let count = head.count
        if count == 0 {
            return false
        }
        let sizes = [188, 192, 204]
        let maxStart = min(1024, count)
        return head.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Bool in
            for size in sizes {
                for start in 0 ..< maxStart {
                    let last = start + 4 * size
                    if last >= count {
                        break
                    }
                    if raw[start] != 0x47 {
                        continue
                    }
                    let allSync = (1 ... 4).allSatisfy { raw[start + $0 * size] == 0x47 }
                    if allSync {
                        return true
                    }
                }
            }
            return false
        }
    }
}
