# Third-party notices

Tuck uses the following open-source packages. Each keeps its own license.

## KeyboardShortcuts
- Author: Sindre Sorhus
- License: MIT
- Source: https://github.com/sindresorhus/KeyboardShortcuts
- Use: global hotkey registration and the hotkey recorder in Settings (macOS app)

## .NET runtime and System.Security.Cryptography.ProtectedData
- Author: Microsoft and the .NET Foundation
- License: MIT
- Source: https://github.com/dotnet/runtime and https://github.com/dotnet/wpf
- Use: the Windows app runs on .NET 10 with WPF. The release download bundles the .NET runtime, and ProtectedData provides Windows DPAPI encryption for the history file

## xUnit (tests only, not shipped)
- License: Apache 2.0
- Source: https://github.com/xunit/xunit

When release builds are produced, copy each dependency's full license text into this file.
