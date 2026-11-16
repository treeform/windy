when defined(macosx):
  import bumpy
  include ../src/windy/platforms/macos/platform

  objc:
    proc isAccessibilityElement(self: NSView): bool
    proc isAccessibilityEnabled(self: NSView): bool
    proc isAccessibilityFocused(self: NSView): bool
    proc accessibilityFocusedUIElement(self: NSView): ID
    proc accessibilityRole(self: NSView): NSString
    proc accessibilityValue(self: NSView): NSString
    proc setAccessibilityValue(self: NSView, x: NSString)
    proc accessibilitySelectedText(self: NSView): NSString
    proc setAccessibilitySelectedText(self: NSView, x: NSString)
    proc accessibilitySelectedTextRange(self: NSView): NSRange
    proc setAccessibilitySelectedTextRange(self: NSView, x: NSRange)
    proc accessibilityVisibleCharacterRange(self: NSView): NSRange
    proc accessibilityNumberOfCharacters(self: NSView): int
    proc accessibilityFrame(self: NSView): NSRect
    proc accessibilityParent(self: NSView): ID
    proc accessibilityIdentifier(self: NSView): NSString
    proc isAccessibilitySelectorAllowed(self: NSView, x: SEL): bool

  proc testAccessibility() =
    ## Exercises registered native text services, Unicode ranges, and cleanup.
    let
      window = newWindow("Accessible editor", ivec2(400, 200), visible = false)
      view = window.inner.contentView
    defer:
      window.close()
      doAssert window.onTextEdit == nil
      doAssert window.textInput.id.len == 0
    var edits: seq[TextInputEdit]
    window.onTextEdit = proc(edit: TextInputEdit) =
      ## Records native requests delivered to the custom editor.
      edits.add(edit)
    autoreleasepool:
      doAssert not view.isAccessibilityElement
      doAssert view.accessibilityFocusedUIElement.int == 0
      doAssert $view.accessibilityValue == ""
      window.runeInputEnabled = true
      window.setTextInputState(TextInputState(
        id: "composer",
        text: "A🌲BéZ",
        selectionStart: 1,
        selectionEnd: 2,
        visibleStart: 1,
        visibleEnd: 5,
        bounds: rect(20, 30, 200, 80),
        multiline: true
      ))
      doAssert view.isAccessibilityElement
      doAssert view.isAccessibilityEnabled
      doAssert not view.isAccessibilityFocused
      doAssert view.accessibilityFocusedUIElement.int == view.int
      doAssert $view.accessibilityRole == "AXTextArea"
      doAssert $view.accessibilityIdentifier == "composer"
      doAssert $view.accessibilityValue == "A🌲BéZ"
      doAssert $view.accessibilitySelectedText == "🌲"
      doAssert view.accessibilityNumberOfCharacters == 6
      doAssert view.accessibilitySelectedTextRange == NSMakeRange(1, 2)
      doAssert view.accessibilityVisibleCharacterRange == NSMakeRange(1, 5)
      doAssert view.accessibilityParent.int == window.inner.int
      doAssert view.isAccessibilitySelectorAllowed(s"setAccessibilityValue:")
      doAssert view.isAccessibilitySelectorAllowed(
        s"setAccessibilitySelectedTextRange:"
      )
      let
        scale = window.contentScale.float64
        frame = view.accessibilityFrame
        content = window.inner.contentRectForFrameRect(window.inner.frame)
      doAssert abs(frame.size.width - 200 / scale) < 0.01
      doAssert abs(frame.size.height - 80 / scale) < 0.01
      doAssert abs(frame.origin.x - content.origin.x - 20 / scale) < 0.01
      doAssert abs(
        frame.origin.y - content.origin.y - content.size.height + 110 / scale
      ) < 0.01
      view.setAccessibilitySelectedText(@"Δ")
      doAssert edits.len == 1
      doAssert edits[0] == TextInputEdit(
        kind: ReplaceText, text: "Δ", start: 1, length: 1
      )
      doAssert $view.accessibilityValue == "AΔBéZ"
      doAssert view.accessibilitySelectedTextRange == NSMakeRange(2, 0)
      view.setAccessibilitySelectedTextRange(NSMakeRange(3, 2))
      doAssert edits[^1] == TextInputEdit(kind: SelectText, start: 3, length: 2)
      doAssert $view.accessibilitySelectedText == "éZ"
      view.setAccessibilityValue(@"Left 🙂\nRight")
      doAssert edits[^1].kind == ReplaceText
      doAssert edits[^1].start == 0 and edits[^1].length == 5
      doAssert $view.accessibilityValue == "Left 🙂\nRight"
      doAssert view.accessibilityNumberOfCharacters == 13
      view.setAccessibilitySelectedTextRange(NSMakeRange(6, 0))
      doAssert edits[^1].start == 5 and edits[^1].length == 0
      doAssert view.accessibilitySelectedTextRange == NSMakeRange(5, 0)
      view.setAccessibilitySelectedTextRange(NSMakeRange(6, 1))
      doAssert edits[^1].start == 5 and edits[^1].length == 1
      doAssert $view.accessibilitySelectedText == "🙂"
      view.setAccessibilitySelectedTextRange(NSMakeRange(uint.high, uint.high))
      doAssert edits[^1].start == 12 and edits[^1].length == 0
      view.NSTextInputClient.insertText((@"🌲").ID, NSMakeRange(5, 2))
      doAssert edits[^1] == TextInputEdit(
        kind: ReplaceText, text: "🌲", start: 5, length: 1
      )
      doAssert $view.accessibilityValue == "Left 🌲\nRight"
      doAssert selectedRange(view.ID, s"selectedRange") == NSMakeRange(7, 0)
      discard setMarkedText(
        view.ID,
        s"setMarkedText:selectedRange:replacementRange:",
        (@"候補").ID,
        NSMakeRange(1, 0),
        kEmptyRange
      )
      doAssert selectedRange(view.ID, s"selectedRange") == NSMakeRange(1, 0)
      view.NSTextInputClient.insertText((@"").ID, kEmptyRange)
      doAssert selectedRange(view.ID, s"selectedRange") == NSMakeRange(7, 0)
      let count = edits.len
      window.runeInputEnabled = false
      doAssert not view.isAccessibilityElement
      doAssert not view.isAccessibilitySelectorAllowed(
        s"setAccessibilityValue:"
      )
      view.setAccessibilityValue(@"Ignored")
      doAssert edits.len == count
      window.runeInputEnabled = true
      window.setTextInputState(TextInputState(
        id: "password", text: "Never expose", password: true
      ))
      doAssert not view.isAccessibilityElement
      doAssert window.textInput.text.len == 0
      doAssert $view.accessibilityValue == ""
      doAssert $view.accessibilitySelectedText == ""
      doAssert view.accessibilityNumberOfCharacters == 0
      view.setAccessibilityValue(@"Ignored")
      doAssert edits.len == count
      window.setTextInputState(TextInputState(
        id: "name", text: "Name", visibleEnd: 4
      ))
      doAssert $view.accessibilityRole == "AXTextField"
      window.setTextInputState(TextInputState())
      doAssert not view.isAccessibilityElement
      doAssert view.accessibilityFocusedUIElement.int == 0
      doAssert $view.accessibilityValue == ""
      doAssert view.accessibilitySelectedTextRange == kEmptyRange
      view.setAccessibilitySelectedText(@"Ignored")
      doAssert edits.len == count

  testAccessibility()
  echo "macOS accessibility tests passed"
