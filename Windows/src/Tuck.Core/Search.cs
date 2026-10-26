using System.Globalization;

namespace Tuck.Core;

public static class Search
{
    private static readonly CompareInfo Compare = CultureInfo.InvariantCulture.CompareInfo;

    /// <summary>
    /// Case- and accent-insensitive search. Every whitespace-separated token in
    /// <paramref name="query"/> must appear in the item's text or source app. An empty query matches all.
    /// </summary>
    public static IReadOnlyList<ClipItem> Filter(
        IEnumerable<ClipItem> items,
        string query,
        ClipKind? kind = null,
        string? sourceApp = null)
    {
        var tokens = query.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
        return items.Where(item =>
        {
            if (kind is not null && item.Kind != kind) return false;
            if (sourceApp is not null && !string.Equals(item.SourceApp, sourceApp, StringComparison.OrdinalIgnoreCase)) return false;
            if (tokens.Length == 0) return true;
            // Hidden secrets are only found by their label, never by their content.
            var text = item.IsSecret ? item.DisplayPreview : item.Text ?? "";
            var haystack = text + " " + (item.SourceApp ?? "");
            return tokens.All(token =>
                Compare.IndexOf(haystack, token, CompareOptions.IgnoreCase | CompareOptions.IgnoreNonSpace) >= 0);
        }).ToList();
    }
}
