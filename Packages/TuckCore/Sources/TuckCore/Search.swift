import Foundation

public enum Search {
    /// Case- and diacritic-insensitive search. Every whitespace-separated token in
    /// `query` must appear in the item's text or source app. An empty query matches all.
    public static func filter(
        _ items: [ClipItem],
        query: String,
        kind: ClipKind? = nil,
        sourceApp: String? = nil
    ) -> [ClipItem] {
        let tokens = query.split(whereSeparator: \.isWhitespace).map(String.init)
        return items.filter { item in
            if let kind, item.kind != kind { return false }
            if let sourceApp, item.sourceApp != sourceApp { return false }
            guard !tokens.isEmpty else { return true }
            let haystack = (item.text ?? "") + " " + (item.sourceApp ?? "")
            return tokens.allSatisfy {
                haystack.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
    }
}
