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
        let oldIDs = lines(of: old, table: &table)
        let newIDs = lines(of: new, table: &table)
        var differ = Differ(
            old: oldIDs,
            new: newIDs,
            removed: [Bool](repeating: false, count: oldIDs.count),
            inserted: [Bool](repeating: false, count: newIDs.count)
        )
        differ.mark(0 ..< oldIDs.count, 0 ..< newIDs.count)
        return collectHunks(removed: differ.removed, inserted: differ.inserted)
    }

    private static func collectHunks(removed: [Bool], inserted: [Bool]) -> [LineHunk] {
        var found: [LineHunk] = []
        var oldIndex = 0
        var newIndex = 0
        while oldIndex < removed.count || newIndex < inserted.count {
            let oldEnd = skipFlagged(removed, from: oldIndex)
            let newEnd = skipFlagged(inserted, from: newIndex)
            if oldEnd > oldIndex || newEnd > newIndex {
                found.append(LineHunk(oldCount: oldEnd - oldIndex, newStart: newIndex + 1, newCount: newEnd - newIndex))
                oldIndex = oldEnd
                newIndex = newEnd
            } else {
                oldIndex += 1
                newIndex += 1
            }
        }
        return found
    }

    private static func skipFlagged(_ flags: [Bool], from start: Int) -> Int {
        var index = start
        while index < flags.count, flags[index] {
            index += 1
        }
        return index
    }

    private static func lines(of data: Data, table: inout [[UInt8]: Int]) -> [Int] {
        let bytes = [UInt8](data)
        var ids: [Int] = []
        var start = 0

        func add(_ end: Int) {
            var stop = end
            if stop > start, bytes[stop - 1] == 0x0D {
                stop -= 1
            }
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
        if start < bytes.count {
            add(bytes.count)
        }
        return ids
    }

    private struct Differ {
        let old: [Int]
        let new: [Int]
        var removed: [Bool]
        var inserted: [Bool]

        mutating func flagAll(_ oldRange: Range<Int>, _ newRange: Range<Int>) {
            for index in oldRange {
                removed[index] = true
            }
            for index in newRange {
                inserted[index] = true
            }
        }

        private func trimmed(_ oldRange: Range<Int>, _ newRange: Range<Int>) -> (old: Range<Int>, new: Range<Int>) {
            var oldLow = oldRange.lowerBound
            var oldHigh = oldRange.upperBound
            var newLow = newRange.lowerBound
            var newHigh = newRange.upperBound
            while oldLow < oldHigh, newLow < newHigh, old[oldLow] == new[newLow] {
                oldLow += 1
                newLow += 1
            }
            while oldLow < oldHigh, newLow < newHigh, old[oldHigh - 1] == new[newHigh - 1] {
                oldHigh -= 1
                newHigh -= 1
            }
            return (oldLow ..< oldHigh, newLow ..< newHigh)
        }

        private mutating func markExact(_ oldRange: Range<Int>, _ newRange: Range<Int>) {
            let difference = Array(new[newRange]).difference(from: Array(old[oldRange]))
            for change in difference {
                switch change {
                case let .remove(offset, _, _): removed[oldRange.lowerBound + offset] = true
                case let .insert(offset, _, _): inserted[newRange.lowerBound + offset] = true
                }
            }
        }

        mutating func mark(_ oldInput: Range<Int>, _ newInput: Range<Int>) {
            let (oldRange, newRange) = trimmed(oldInput, newInput)
            if oldRange.isEmpty || newRange.isEmpty {
                flagAll(oldRange, newRange)
                return
            }
            if oldRange.count + newRange.count <= LineDiff.exactLimit {
                markExact(oldRange, newRange)
                return
            }
            let anchors = uniqueAnchors(oldRange, newRange)
            if anchors.isEmpty {
                flagAll(oldRange, newRange)
                return
            }
            var lastOld = oldRange.lowerBound
            var lastNew = newRange.lowerBound
            for anchor in anchors {
                mark(lastOld ..< anchor.old, lastNew ..< anchor.new)
                lastOld = anchor.old + 1
                lastNew = anchor.new + 1
            }
            mark(lastOld ..< oldRange.upperBound, lastNew ..< newRange.upperBound)
        }

        private func uniqueAnchors(_ oldRange: Range<Int>, _ newRange: Range<Int>) -> [(old: Int, new: Int)] {
            var countOld: [Int: Int] = [:]
            var positionNew: [Int: Int] = [:]
            var countNew: [Int: Int] = [:]
            for index in oldRange {
                countOld[old[index], default: 0] += 1
            }
            for index in newRange {
                countNew[new[index], default: 0] += 1
                positionNew[new[index]] = index
            }

            var pairs: [(old: Int, new: Int)] = []
            for index in oldRange where countOld[old[index]] == 1 && countNew[old[index]] == 1 {
                if let match = positionNew[old[index]] {
                    pairs.append((index, match))
                }
            }
            return Self.longestIncreasingChain(pairs)
        }

        private static func longestIncreasingChain(_ pairs: [(old: Int, new: Int)]) -> [(old: Int, new: Int)] {
            guard !pairs.isEmpty else { return [] }
            var piles: [Int] = []
            var links = [Int](repeating: -1, count: pairs.count)
            for (index, pair) in pairs.enumerated() {
                var low = 0
                var high = piles.count
                while low < high {
                    let middle = (low + high) / 2
                    if pairs[piles[middle]].new < pair.new {
                        low = middle + 1
                    } else {
                        high = middle
                    }
                }
                if low > 0 {
                    links[index] = piles[low - 1]
                }
                if low == piles.count {
                    piles.append(index)
                } else {
                    piles[low] = index
                }
            }

            var chain: [(old: Int, new: Int)] = []
            var cursor = piles[piles.count - 1]
            while cursor >= 0 {
                chain.append(pairs[cursor])
                cursor = links[cursor]
            }
            return chain.reversed()
        }
    }
}
