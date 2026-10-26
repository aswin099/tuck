namespace Tuck.App.Views;

public sealed record Option<T>(T Value, string Label);

/// <summary>Choices shown in the Settings drop-downs.</summary>
public static class SettingsOptions
{
    public static IReadOnlyList<Option<int>> HistoryLimits { get; } =
        [new(50, "50 items"), new(100, "100 items"), new(200, "200 items"), new(500, "500 items"), new(1000, "1000 items")];

    public static IReadOnlyList<Option<int>> RetentionDays { get; } =
        [new(0, "Never"), new(1, "1 day"), new(7, "1 week"), new(30, "1 month"), new(90, "3 months")];

    public static IReadOnlyList<Option<PopupPosition>> PopupPositions { get; } =
        [new(PopupPosition.Cursor, "At the mouse pointer"), new(PopupPosition.Center, "In the center of the screen")];

    public static IReadOnlyList<Option<int>> RowLines { get; } = [new(1, "1"), new(2, "2"), new(3, "3")];

    public static IReadOnlyList<Option<SecretHandling>> SecretHandlings { get; } =
        [new(SecretHandling.Keep, "Save normally"), new(SecretHandling.Hide, "Save hidden"), new(SecretHandling.Skip, "Don't save")];

    public static IReadOnlyList<Option<int>> SecretLifetimes { get; } =
        [new(1, "1 minute"), new(5, "5 minutes"), new(15, "15 minutes"), new(60, "1 hour"), new(0, "Never")];
}
