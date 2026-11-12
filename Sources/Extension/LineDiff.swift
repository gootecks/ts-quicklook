import Foundation

struct LineHunk: Equatable {
    let oldCount: Int
    let newStart: Int
    let newCount: Int
}

enum LineDiff {
    static let maxBytes = 4 << 20
    private static let exactLimit = 1500

    static func hunks(from old: Data, to new: Data) -> [LineHunk]? {
        guard old.count <= maxBytes, new.count <= maxBytes else { return nil }
        var table: [[UInt8]: Int] = [:]
        let a = lines(of: old, table: &table)
        let b = lines(of: new, table: &table)
        var removed = [Bool](repeating: false, count: a.count)
        var inserted = [Bool](repeating: false, count: b.count)
        mark(a, 0, a.count, b, 0, b.count, &removed, &inserted)

        var found: [LineHunk] = []
        var i = 0
        var j = 0
        while i < a.count || j < b.count {
            let startOld = i
            let startNew = j
            var moved = true
            while moved {
                moved = false
                while i < a.count, removed[i] {
                    i += 1
                    moved = true
                }
                while j < b.count, inserted[j] {
                    j += 1
                    moved = true
                }
            }
            if i > startOld || j > startNew {
                found.append(LineHunk(oldCount: i - startOld, newStart: startNew + 1, newCount: j - startNew))
            } else {
                i += 1
                j += 1
            }
        }
        return found
    }

    private static func lines(of data: Data, table: inout [[UInt8]: Int]) -> [Int] {
        let bytes = [UInt8](data)
        var ids: [Int] = []
        var start = 0

        func add(_ end: Int) {
            var stop = end
            if stop > start, bytes[stop - 1] == 0x0D { stop -= 1 }
            let key = Array(bytes[start ..< stop])
            if let id = table[key] {
                ids.append(id)
            } else {
                table[key] = table.count
                ids.append(table.count - 1)
            }
        }

        for index in bytes.indices where bytes[index] == 0x0A {
            add(index)
            start = index + 1
        }
        if start < bytes.count { add(bytes.count) }
        return ids
    }

    private static func mark(
        _ a: [Int], _ aStart: Int, _ aEnd: Int,
        _ b: [Int], _ bStart: Int, _ bEnd: Int,
        _ removed: inout [Bool], _ inserted: inout [Bool]
    ) {
        var aLow = aStart
        var aHigh = aEnd
        var bLow = bStart
        var bHigh = bEnd
        while aLow < aHigh, bLow < bHigh, a[aLow] == b[bLow] {
            aLow += 1
            bLow += 1
        }
        while aLow < aHigh, bLow < bHigh, a[aHigh - 1] == b[bHigh - 1] {
            aHigh -= 1
            bHigh -= 1
        }
        if aLow == aHigh || bLow == bHigh {
            for index in aLow ..< aHigh { removed[index] = true }
            for index in bLow ..< bHigh { inserted[index] = true }
            return
        }

        if (aHigh - aLow) + (bHigh - bLow) <= exactLimit {
            let difference = Array(b[bLow ..< bHigh]).difference(from: Array(a[aLow ..< aHigh]))
            for change in difference {
                switch change {
                case let .remove(offset, _, _): removed[aLow + offset] = true
                case let .insert(offset, _, _): inserted[bLow + offset] = true
                }
            }
            return
        }

        let anchors = uniqueAnchors(a, aLow, aHigh, b, bLow, bHigh)
        if anchors.isEmpty {
            for index in aLow ..< aHigh { removed[index] = true }
            for index in bLow ..< bHigh { inserted[index] = true }
            return
        }
        var lastA = aLow
        var lastB = bLow
        for anchor in anchors {
            mark(a, lastA, anchor.a, b, lastB, anchor.b, &removed, &inserted)
            lastA = anchor.a + 1
            lastB = anchor.b + 1
        }
        mark(a, lastA, aHigh, b, lastB, bHigh, &removed, &inserted)
    }

    private static func uniqueAnchors(
        _ a: [Int], _ aLow: Int, _ aHigh: Int,
        _ b: [Int], _ bLow: Int, _ bHigh: Int
    ) -> [(a: Int, b: Int)] {
        var countA: [Int: Int] = [:]
        var positionB: [Int: Int] = [:]
        var countB: [Int: Int] = [:]
        for index in aLow ..< aHigh { countA[a[index], default: 0] += 1 }
        for index in bLow ..< bHigh {
            countB[b[index], default: 0] += 1
            positionB[b[index]] = index
        }

        var pairs: [(a: Int, b: Int)] = []
        for index in aLow ..< aHigh where countA[a[index]] == 1 && countB[a[index]] == 1 {
            if let match = positionB[a[index]] { pairs.append((index, match)) }
        }
        guard !pairs.isEmpty else { return [] }

        var piles: [Int] = []
        var links = [Int](repeating: -1, count: pairs.count)
        for (index, pair) in pairs.enumerated() {
            var low = 0
            var high = piles.count
            while low < high {
                let middle = (low + high) / 2
                if pairs[piles[middle]].b < pair.b { low = middle + 1 } else { high = middle }
            }
            if low > 0 { links[index] = piles[low - 1] }
            if low == piles.count { piles.append(index) } else { piles[low] = index }
        }

        var chain: [(a: Int, b: Int)] = []
        var cursor = piles[piles.count - 1]
        while cursor >= 0 {
            chain.append(pairs[cursor])
            cursor = links[cursor]
        }
        return chain.reversed()
    }
}
