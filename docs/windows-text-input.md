# Windows text services

The Windows backend implements the same `TextInputState` / `onTextEdit` API as
macOS accessibility. This enables a custom editor, including Silky text boxes,
to expose text and selection to dictation and accessibility clients.

A persistent UI Automation fragment root is registered before the window is
shown. Each focused field gets an Edit child with Value and Text patterns, a
field identity, screen bounds, text, selection, and visible ranges. The root
exists even before an editor is focused, avoiding a cached generic HWND
provider when a client inspects a new window early.

COM reads use locked snapshots. Replacements and selection changes are sent to
the window thread, where `onTextEdit` runs. The callback should apply the edit
and publish the resulting state. Changing the field identity, disabling input,
clearing the field, or closing the window invalidates retained providers and
ranges. Password contents are never published.

`WM_PASTE` reads the clipboard synchronously and delivers its text through
`onTextInput` before a dictation tool can restore the clipboard. Shortcuts with
no scan code use their virtual keys, and UTF-16 surrogate pairs in `WM_CHAR`
are combined into one Unicode rune. Existing keyboard and IME processing is
otherwise preserved. Applications retain ownership of shortcut actions,
editing policy, newline handling, undo, rendering, and focus.

The bridge uses the stable COM ABI because older MinGW SDKs bundled with Nim
lack the text-provider declarations. A C++ compiler is required on Windows;
MinGW runtime libraries are linked statically, with no new compiler runtime
DLL requirement. The code does not call into Nim from COM worker threads.

## Validation

From the Windy repository root on Windows:

```powershell
nim c -d:useCpu -o:tests/windows_text_fixture.exe tests/windows_text_fixture.nim
powershell.exe -NoProfile -File tests/test_windows_text_input.ps1
nim r -d:useCpu tests/test_cpu_pixels.nim
nim c tests/test.nim
```

The native test uses a minimal custom editor and a separate .NET UI Automation
client. It checks early discovery, replacement, text and selection ranges,
Unicode, native paste followed by immediate clipboard restoration, virtual-key
shortcuts, password and disabled fields, focus loss, and provider lifetime.
It does not need Runway, Silky, OpenGL, a microphone, or an AI service. It restores
the clipboard and closes its own fixture window.

## Limits

`TextInputState` supplies field bounds rather than per-character geometry.
Point-to-character hit testing and programmatic range scrolling return
`E_NOTIMPL`. This is not a complete screen-reader or TSF implementation.
Actual microphone-to-editor dictation with the current Wispr Flow Windows
client has not yet been verified.

Microsoft documents the provider contract in
[server-side UI Automation providers](https://learn.microsoft.com/en-us/windows/win32/winauto/uiauto-serversideprovider)
and [Edit controls](https://learn.microsoft.com/en-us/windows/win32/winauto/uiauto-supporteditcontroltype).
