import Foundation

enum TextChunker {
    /// Keeps every character, including separators. Splits on paragraph/sentence boundaries when possible.
    static func split(_ text: String, limit: Int = 6_000) -> [String] {
        precondition(limit > 0)
        var chunks: [String] = []
        var start = text.startIndex
        while start < text.endIndex {
            let end = text.index(start, offsetBy: limit, limitedBy: text.endIndex) ?? text.endIndex
            if end == text.endIndex { chunks.append(String(text[start...])); break }
            let lower = text.index(start, offsetBy: limit / 2)
            let tail = text[lower..<end]
            let split: String.Index
            if let paragraph = tail.range(of: "\n\n", options: .backwards) { split = paragraph.upperBound }
            else if let newline = tail.lastIndex(of: "\n") { split = text.index(after: newline) }
            else if let sentence = tail.range(of: ". ", options: .backwards) { split = sentence.upperBound }
            else if let space = tail.lastIndex(where: { $0.isWhitespace }) { split = text.index(after: space) }
            else { split = end }
            chunks.append(String(text[start..<split]))
            start = split
        }
        return chunks
    }

    static func restoringWhitespace(_ translation: String, from original: String) -> String {
        let leading = original.prefix(while: { $0.isWhitespace })
        let trailing = original.reversed().prefix(while: { $0.isWhitespace }).reversed()
        return String(leading) + translation.trimmingCharacters(in: .whitespacesAndNewlines) + String(trailing)
    }
}
