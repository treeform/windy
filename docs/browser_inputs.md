# Manual browser input check

Use `tests/manual_inputs.nim` to compare native and browser input.
Received text appears in the window or tab title. The console logs every
callback and the keys held when it runs.

Run the native test from the repository root:

```sh
nim r tests/manual_inputs.nim
```

Compile with the shared examples configuration, then open it with Emscripten:

```sh
nim c -d:emscripten tests/manual_inputs.nim
emrun examples/emscripten/manual_inputs.html
```

Open the browser console, then click the canvas. The background turns red
while a modifier is held, flashes green for received text, and turns blue for
other held keys. F2 toggles rune input and Escape clears the displayed text.

- Type `wasd`, spaces, uppercase letters, and characters from your keyboard
  layout. Each character should appear once in the title and as one `onRune`
  callback. Physical key callbacks should identify the key independently of
  the character it produces.
- Hold a letter to repeat it. Each repeat should produce a press and a rune.
- Turn rune input off with F2. Keys should still report presses and releases,
  but no text should be added. Turn it back on and check typing again.
- Quickly press and release Control-A or Command-A. The A callbacks should
  show the modifier held, and the shortcut should not append text to the title.
- Try left and right Shift, Control, Alt, and Command/Super. Check their names
  and held state in the log. Test both Shift keys held together and release
  only one. The other should remain held.
- Try arrows, function keys, and numpad keys. They should report their own
  buttons; navigation keys should not generate text or move browser focus.
- Hold a key and switch away from the window. Releases should occur before
  the focus-change callback. Return and check that no keys remain stuck.

These checks intentionally use real browser events. Compiling an example in
CI does not verify browser event delivery.
