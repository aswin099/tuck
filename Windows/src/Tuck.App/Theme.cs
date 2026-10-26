using System.Windows;
using System.Windows.Media;
using Microsoft.Win32;

namespace Tuck.App;

/// <summary>
/// Tuck's colors (DESIGN.md) for light and dark mode, following the Windows app theme.
/// Views use them as DynamicResource "Tuck.*" so they update when the user switches themes.
/// </summary>
public static class Theme
{
    public static bool IsDark { get; private set; }

    public static void Apply()
    {
        IsDark = ReadAppsUseDarkTheme();
        var r = Application.Current.Resources;
        void Set(string key, string hex) => r[key] = Freeze(new SolidColorBrush((Color)ColorConverter.ConvertFromString(hex)));

        if (IsDark)
        {
            Set("Tuck.Surface", "#2B2B2B");
            Set("Tuck.SurfaceAlt", "#323232");
            Set("Tuck.Border", "#3D3D3D");
            Set("Tuck.Text", "#FFFFFF");
            Set("Tuck.TextSecondary", "#C5C5C5");
            Set("Tuck.TextTertiary", "#A0A0A0");
            Set("Tuck.Accent", "#8E94F2");
            Set("Tuck.OnAccent", "#14153A");
            Set("Tuck.Selected", "#388E94F2");
            Set("Tuck.Hover", "#14FFFFFF");
            Set("Tuck.Warning", "#FCB75C");
        }
        else
        {
            Set("Tuck.Surface", "#F9F9F9");
            Set("Tuck.SurfaceAlt", "#FFFFFF");
            Set("Tuck.Border", "#E0E0E0");
            Set("Tuck.Text", "#1B1B1B");
            Set("Tuck.TextSecondary", "#5C5C5C");
            Set("Tuck.TextTertiary", "#6B6B6B");
            Set("Tuck.Accent", "#2B2D6E");
            Set("Tuck.OnAccent", "#FFFFFF");
            Set("Tuck.Selected", "#292B2D6E");
            Set("Tuck.Hover", "#0A000000");
            Set("Tuck.Warning", "#9D5D00");
        }
        // Amber is the pin marker in both themes.
        Set("Tuck.Amber", "#FFB547");
    }

    /// <summary>Re-applies the colors when the user changes the Windows theme.</summary>
    public static void FollowSystem()
    {
        Apply();
        SystemEvents.UserPreferenceChanged += (_, e) =>
        {
            if (e.Category == UserPreferenceCategory.General)
            {
                Application.Current.Dispatcher.Invoke(Apply);
            }
        };
    }

    private static bool ReadAppsUseDarkTheme()
    {
        using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
        return key?.GetValue("AppsUseLightTheme") is int light && light == 0;
    }

    private static T Freeze<T>(T freezable) where T : Freezable
    {
        freezable.Freeze();
        return freezable;
    }
}
