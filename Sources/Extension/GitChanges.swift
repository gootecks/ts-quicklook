import Foundation

struct GitChanges {
    enum Kind { case added, modified }

    var lines: [Int: Kind] = [:]
    var deletions: Set<Int> = []
    var summary = ""

    static func load(for fileURL: URL, contents: Data) -> GitChanges? {
        guard let (repository, path) = GitRepository.discover(containing: fileURL) else { return nil }
        var result = GitChanges()

        guard let headID = repository.head, let head = repository.commit(headID) else {
            result.summary = "No commits yet"
            return result
        }

        let committed = repository.blobID(at: path, in: head.tree)
        guard committed != nil || repository.indexContains(path.joined(separator: "/")) else {
            result.summary = "Untracked"
            return result
        }

        if committed != repository.blobHash(of: contents) {
            let base = committed.map { repository.blob($0) } ?? Data()
            guard let base, let hunks = LineDiff.hunks(from: base, to: contents) else {
                result.summary = "Uncommitted changes"
                return result
            }
            if !hunks.isEmpty {
                result.mark(hunks)
                let added = hunks.reduce(0) { $0 + $1.newCount }
                let removed = hunks.reduce(0) { $0 + $1.oldCount }
                result.summary = "Uncommitted changes · +\(added) \u{2212}\(removed)"
                return result
            }
        }

        guard let committed, let last = repository.lastChange(of: path, blob: committed, from: head) else {
            result.summary = "No uncommitted changes"
            return result
        }
        let previous = last.previous.map { repository.blob($0) } ?? Data()
        if let previous, let current = repository.blob(committed),
           let hunks = LineDiff.hunks(from: previous, to: current) {
            result.mark(hunks)
        }

        var fields = [String(last.commit.id.gitHex.prefix(7))]
        if let date = last.commit.date {
            fields.append(RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date()))
        }
        fields.append(last.commit.subject)
        result.summary = fields.joined(separator: " · ")
        return result
    }

    mutating func mark(_ hunks: [LineHunk]) {
        for hunk in hunks {
            if hunk.newCount == 0 {
                deletions.insert(hunk.newStart)
            } else {
                let kind: Kind = hunk.oldCount == 0 ? .added : .modified
                for line in hunk.newStart ..< hunk.newStart + hunk.newCount { lines[line] = kind }
            }
        }
    }
}
