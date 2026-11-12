var
  NSAccessibilityFocusedUIElementChangedNotification {.importc.}: NSString
  NSAccessibilityValueChangedNotification {.importc.}: NSString
  NSAccessibilitySelectedTextChangedNotification {.importc.}: NSString

proc NSAccessibilityPostNotification(
  element: ID, notification: NSString
) {.cdecl, importc.}

proc NSAccessibilityFrameInView(
  view: NSView, frame: NSRect
): NSRect {.cdecl, importc.}

proc hasTextInput(window: Window): bool =
  ## Checks whether an editable, nonsecure field is available to text services.
  window != nil and not window.state.closed and
    window.state.runeInputEnabled and window.textInput.id.len > 0 and
    not window.textInput.password

proc utf16Offset(text: string, index: int): uint =
  ## Converts a rune offset to the UTF-16 offset used by Cocoa text ranges.
  var count = 0
  for rune in text.runes:
    if count >= index:
      break
    result += (if rune.int > 0xffff: 2.uint else: 1.uint)
    inc count

proc runeOffset(text: string, index: uint, roundUp = false): int =
  ## Converts UTF-16 offsets without splitting a surrogate pair.
  var count = 0.uint
  for rune in text.runes:
    let size = if rune.int > 0xffff: 2.uint else: 1.uint
    if count >= index or (count + size > index and not roundUp):
      break
    count += size
    inc result

proc textRange(text: string, first, last: int): NSRange =
  ## Converts a half-open rune range to a bounded native range.
  let
    start = text.utf16Offset(min(first, last))
    finish = text.utf16Offset(max(first, last))
  NSMakeRange(start, finish - start)

proc runeRange(text: string, range: NSRange): tuple[first, last: int] =
  ## Clamps a native range and expands partial surrogate selections safely.
  let
    total = text.utf16Offset(int.high)
    start = min(range.location, total)
    finish = start + min(range.length, total - start)
  result.first = text.runeOffset(start)
  result.last = text.runeOffset(finish, range.length > 0)

proc selectedTextRange(window: Window): NSRange =
  ## Returns the active editor's selection in UTF-16 code units.
  if not window.hasTextInput:
    return kEmptyRange
  window.textInput.text.textRange(
    window.textInput.selectionStart,
    window.textInput.selectionEnd
  )

proc notifyTextInput(window: Window, old: TextInputState) =
  ## Notifies accessibility clients only when published editor state changes.
  if window.inner.int == 0:
    return
  let view = window.inner.contentView.ID
  if old.id != window.textInput.id or old.password != window.textInput.password:
    NSAccessibilityPostNotification(
      view, NSAccessibilityFocusedUIElementChangedNotification
    )
  if old.text != window.textInput.text:
    NSAccessibilityPostNotification(
      view, NSAccessibilityValueChangedNotification
    )
  if old.selectionStart != window.textInput.selectionStart or
    old.selectionEnd != window.textInput.selectionEnd or
    old.text != window.textInput.text:
      NSAccessibilityPostNotification(
        view, NSAccessibilitySelectedTextChangedNotification
      )

proc setTextInputState*(window: Window, state: TextInputState) =
  ## Publishes focused editor state for macOS accessibility text services.
  ## Requires runeInputEnabled. Publish an empty id to clear the field.
  ## Republish after applying edits or changing focus, selection, or layout.
  if window.state.closed:
    return
  let old = window.textInput
  window.textInput = state
  if state.password:
    window.textInput.text.setLen(0)
    window.textInput.selectionStart = 0
    window.textInput.selectionEnd = 0
  let count = window.textInput.text.runeLen
  window.textInput.selectionStart = clamp(state.selectionStart, 0, count)
  window.textInput.selectionEnd = clamp(state.selectionEnd, 0, count)
  window.notifyTextInput(old)

proc applyTextEdit(window: Window, edit: TextInputEdit) =
  ## Mirrors an accepted native edit before delivering it to the UI callback.
  if not window.hasTextInput or window.onTextEdit == nil:
    return
  let
    old = window.textInput
    runes = old.text.toRunes
    first = clamp(edit.start, 0, runes.len)
    last = first + clamp(edit.length, 0, runes.len - first)
  var bounded = edit
  bounded.start = first
  bounded.length = last - first
  case edit.kind
  of SelectText:
    window.textInput.selectionStart = first
    window.textInput.selectionEnd = last
  of ReplaceText:
    var text: string
    for i in 0 ..< first:
      text.add($runes[i])
    text.add(edit.text)
    for i in last ..< runes.len:
      text.add($runes[i])
    window.textInput.text = text
    window.textInput.selectionStart = first + edit.text.runeLen
    window.textInput.selectionEnd = window.textInput.selectionStart
  window.onTextEdit(bounded)
  window.notifyTextInput(old)

proc replaceNativeText(window: Window, text: string, range: NSRange) =
  ## Sends an explicit Cocoa replacement range to the editor as one edit.
  let selection = window.textInput.text.runeRange(range)
  window.applyTextEdit(TextInputEdit(
    kind: ReplaceText,
    start: selection.first,
    length: selection.last - selection.first,
    text: text
  ))

proc accessibilityElement(self: ID, cmd: SEL): bool {.cdecl.} =
  ## Exposes the view as a native element while a custom editor is active.
  windows.forNSWindow(self.NSView.window).hasTextInput

proc accessibilityRole(self: ID, cmd: SEL): NSString {.cdecl.} =
  ## Identifies the focused editor using standard native text roles.
  let window = windows.forNSWindow(self.NSView.window)
  if not window.hasTextInput:
    return @"AXGroup"
  if window.textInput.multiline:
    @"AXTextArea"
  else:
    @"AXTextField"

proc accessibilityFocused(self: ID, cmd: SEL): bool {.cdecl.} =
  ## Reports keyboard focus only for the key window's active editor.
  let window = windows.forNSWindow(self.NSView.window)
  window.hasTextInput and window.focused

proc accessibilityFocusedUIElement(self: ID, cmd: SEL): ID {.cdecl.} =
  ## Lets AppKit find the custom field behind the first-responder view.
  if windows.forNSWindow(self.NSView.window).hasTextInput:
    self
  else:
    0.ID

proc accessibilityValue(self: ID, cmd: SEL): NSString {.cdecl.} =
  ## Returns the active document without exposing secure field contents.
  let window = windows.forNSWindow(self.NSView.window)
  if window.hasTextInput:
    @(window.textInput.text)
  else:
    @""

proc setAccessibilityValue(self: ID, cmd: SEL, value: NSString) {.cdecl.} =
  ## Replaces the complete editable document through the normal edit queue.
  let window = windows.forNSWindow(self.NSView.window)
  if window.hasTextInput and value.int != 0:
    window.applyTextEdit(TextInputEdit(
      kind: ReplaceText,
      start: 0,
      length: window.textInput.text.runeLen,
      text: $value
    ))

proc accessibilitySelectedTextRange(
  self: ID, cmd: SEL
): NSRange {.cdecl.} =
  ## Exposes the current selection in Cocoa's UTF-16 indexing.
  windows.forNSWindow(self.NSView.window).selectedTextRange

proc setAccessibilitySelectedTextRange(
  self: ID, cmd: SEL, range: NSRange
) {.cdecl.} =
  ## Changes a selection after translating native character offsets.
  let window = windows.forNSWindow(self.NSView.window)
  if window.hasTextInput:
    let selection = window.textInput.text.runeRange(range)
    window.applyTextEdit(TextInputEdit(
      kind: SelectText,
      start: selection.first,
      length: selection.last - selection.first
    ))

proc accessibilitySelectedText(self: ID, cmd: SEL): NSString {.cdecl.} =
  ## Returns exactly the text covered by the current selection.
  let window = windows.forNSWindow(self.NSView.window)
  var text: string
  if window.hasTextInput:
    let
      first = min(
        window.textInput.selectionStart, window.textInput.selectionEnd
      )
      last = max(window.textInput.selectionStart, window.textInput.selectionEnd)
    var index = 0
    for rune in window.textInput.text.runes:
      if index >= first and index < last:
        text.add($rune)
      inc index
  @text

proc setAccessibilitySelectedText(
  self: ID, cmd: SEL, value: NSString
) {.cdecl.} =
  ## Replaces selected text while keeping insertion and undo atomic.
  let window = windows.forNSWindow(self.NSView.window)
  if window.hasTextInput and value.int != 0:
    window.replaceNativeText($value, window.selectedTextRange)

proc accessibilityNumberOfCharacters(self: ID, cmd: SEL): int {.cdecl.} =
  ## Counts native UTF-16 characters rather than UTF-8 bytes or runes.
  let window = windows.forNSWindow(self.NSView.window)
  if window.hasTextInput:
    window.textInput.text.utf16Offset(int.high).int
  else:
    0

proc accessibilityVisibleCharacterRange(
  self: ID, cmd: SEL
): NSRange {.cdecl.} =
  ## Returns the visible portion supplied by the editor's layout.
  let window = windows.forNSWindow(self.NSView.window)
  if window.hasTextInput:
    window.textInput.text.textRange(
      window.textInput.visibleStart,
      window.textInput.visibleEnd
    )
  else:
    kEmptyRange

proc accessibilityFrame(self: ID, cmd: SEL): NSRect {.cdecl.} =
  ## Converts framebuffer editor bounds to screen points, including Retina.
  let window = windows.forNSWindow(self.NSView.window)
  if not window.hasTextInput:
    return
  let
    view = self.NSView
    bounds = window.textInput.bounds
    scale = window.contentScale.float64
    frame = NSMakeRect(
      bounds.x.float64 / scale,
      view.bounds.size.height - (bounds.y + bounds.h).float64 / scale,
      bounds.w.float64 / scale,
      bounds.h.float64 / scale
    )
  NSAccessibilityFrameInView(view, frame)

proc accessibilityParent(self: ID, cmd: SEL): ID {.cdecl.} =
  ## Connects the custom field to its native window.
  self.NSView.window.ID

proc accessibilityLabel(self: ID, cmd: SEL): NSString {.cdecl.} =
  ## Supplies a generic label for custom text input controls.
  @"Text input"

proc accessibilityIdentifier(self: ID, cmd: SEL): NSString {.cdecl.} =
  ## Distinguishes active fields while reusing the native content view.
  let window = windows.forNSWindow(self.NSView.window)
  if window.hasTextInput:
    @(window.textInput.id)
  else:
    @""

proc accessibilitySelectorAllowed(
  self: ID, cmd: SEL, selector: SEL
): bool {.cdecl.} =
  ## Advertises setters only while a writable custom field is active.
  if selector.int == s"setAccessibilityValue:".int or
    selector.int == s"setAccessibilitySelectedText:".int or
    selector.int == s"setAccessibilitySelectedTextRange:".int:
      let window = windows.forNSWindow(self.NSView.window)
      return window.hasTextInput and window.onTextEdit != nil
  true

proc registerAccessibilityMethods(cls: Class) =
  ## Registers typed Objective-C methods used by the AppKit AX bridge.
  template register(name, signature: string, handler: untyped) =
    ## Preserves native type encodings for AppKit method introspection.
    discard class_addMethod(
      cls,
      s(name),
      cast[IMP](handler),
      signature.cstring
    )
  register("isAccessibilityElement", "B@:", accessibilityElement)
  register("isAccessibilityEnabled", "B@:", accessibilityElement)
  register("isAccessibilityFocused", "B@:", accessibilityFocused)
  register(
    "accessibilityFocusedUIElement", "@@:", accessibilityFocusedUIElement
  )
  register("accessibilityRole", "@@:", accessibilityRole)
  register("accessibilityValue", "@@:", accessibilityValue)
  register("setAccessibilityValue:", "v@:@", setAccessibilityValue)
  register("accessibilitySelectedText", "@@:", accessibilitySelectedText)
  register(
    "setAccessibilitySelectedText:", "v@:@", setAccessibilitySelectedText
  )
  register("accessibilitySelectedTextRange", "{_NSRange=QQ}@:",
    accessibilitySelectedTextRange)
  register("setAccessibilitySelectedTextRange:", "v@:{_NSRange=QQ}",
    setAccessibilitySelectedTextRange)
  register("accessibilityVisibleCharacterRange", "{_NSRange=QQ}@:",
    accessibilityVisibleCharacterRange)
  register("accessibilityNumberOfCharacters", "q@:",
    accessibilityNumberOfCharacters)
  register("accessibilityFrame", "{CGRect={CGPoint=dd}{CGSize=dd}}@:",
    accessibilityFrame)
  register("accessibilityParent", "@@:", accessibilityParent)
  register("accessibilityWindow", "@@:", accessibilityParent)
  register("accessibilityTopLevelUIElement", "@@:", accessibilityParent)
  register("accessibilityLabel", "@@:", accessibilityLabel)
  register("accessibilityIdentifier", "@@:", accessibilityIdentifier)
  register("isAccessibilitySelectorAllowed:", "B@::",
    accessibilitySelectorAllowed)
