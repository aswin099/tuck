using System.Windows;
using System.Windows.Controls;
using Tuck.App.ViewModels;

namespace Tuck.App.Views;

/// <summary>Right-hand pane in the popup showing the full selected item and its details.</summary>
public partial class PreviewPane : UserControl
{
    public PreviewPane() => InitializeComponent();

    private void OnRevealSecret(object sender, RoutedEventArgs e)
    {
        if (DataContext is ItemViewModel item) item.RevealSecret = true;
    }
}
