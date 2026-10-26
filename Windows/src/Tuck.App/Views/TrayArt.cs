using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Windows.Interop;
using System.Windows.Media.Imaging;
using Color = System.Drawing.Color;
using ImageSource = System.Windows.Media.ImageSource;

namespace Tuck.App.Views;

/// <summary>
/// Draws Tuck's placeholder icon: an indigo tile with a card and the amber pin dot.
/// TODO: replace with the designed icon (.ico) once it exists, like the macOS app.
/// </summary>
internal static partial class TrayArt
{
    private static readonly Color Indigo = Color.FromArgb(0x2B, 0x2D, 0x6E);
    private static readonly Color Gray = Color.FromArgb(0x80, 0x80, 0x80);
    private static readonly Color Amber = Color.FromArgb(0xFF, 0xB5, 0x47);

    public static Icon Icon(bool paused)
    {
        using var bitmap = Draw(32, paused);
        var handle = bitmap.GetHicon();
        try
        {
            // Clone so the icon owns its own handle and the temporary one can be freed.
            using var temporary = System.Drawing.Icon.FromHandle(handle);
            return (Icon)temporary.Clone();
        }
        finally
        {
            DestroyIcon(handle);
        }
    }

    public static ImageSource ImageSource(bool paused)
    {
        using var bitmap = Draw(144, paused);
        var handle = bitmap.GetHbitmap(System.Drawing.Color.Transparent);
        try
        {
            var source = Imaging.CreateBitmapSourceFromHBitmap(handle, IntPtr.Zero, System.Windows.Int32Rect.Empty,
                BitmapSizeOptions.FromEmptyOptions());
            source.Freeze();
            return source;
        }
        finally
        {
            DeleteObject(handle);
        }
    }

    private static Bitmap Draw(int size, bool paused)
    {
        var bitmap = new Bitmap(size, size);
        using var g = Graphics.FromImage(bitmap);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.Clear(Color.Transparent);
        var s = size / 32f;

        using (var tile = RoundedRect(new RectangleF(1 * s, 1 * s, 30 * s, 30 * s), 7 * s))
        using (var fill = new SolidBrush(paused ? Gray : Indigo))
        {
            g.FillPath(fill, tile);
        }
        // A card tucked into a pocket.
        using (var card = RoundedRect(new RectangleF(8 * s, 6 * s, 16 * s, 13 * s), 2.5f * s))
        using (var white = new SolidBrush(Color.White))
        {
            g.FillPath(white, card);
        }
        using (var pocket = RoundedRect(new RectangleF(5 * s, 15 * s, 22 * s, 11 * s), 3 * s))
        using (var pocketFill = new SolidBrush(Color.FromArgb(230, 255, 255, 255)))
        using (var edge = new Pen(paused ? Gray : Indigo, 1.5f * s))
        {
            g.FillPath(pocketFill, pocket);
            g.DrawPath(edge, pocket);
        }
        using (var dot = new SolidBrush(Amber))
        {
            g.FillEllipse(dot, 21 * s, 18.5f * s, 4 * s, 4 * s);
        }
        return bitmap;
    }

    private static GraphicsPath RoundedRect(RectangleF r, float radius)
    {
        var path = new GraphicsPath();
        var d = radius * 2;
        path.AddArc(r.X, r.Y, d, d, 180, 90);
        path.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        path.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        path.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        path.CloseFigure();
        return path;
    }

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool DestroyIcon(IntPtr handle);

    [LibraryImport("gdi32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool DeleteObject(IntPtr handle);
}
