# Included by platform.nim so native edits can use the window's private state.
import uia

const
  WM_GETOBJECT = 0x003d
  WM_PASTE = 0x0302

proc hasTextInput(window: Window): bool =
  ## Never expose secure fields or an editor that no longer owns text input.
  not window.state.closed and window.state.runeInputEnabled and
    window.textInput.id.len > 0 and not window.textInput.password

proc clearNativeText(window: Window) =
  ## Invalidates retained automation objects before releasing window ownership.
  let provider = window.textProvider
  window.textProvider = nil
  window.textInput = TextInputState()
  windyTextDestroy(provider)

proc utf16Offset(text: string, index: int): cint =
  ## Windows uses UTF-16 code units while Silky selections use rune offsets.
  var count = 0
  for rune in text.runes:
    if count >= index:
      break
    result += (if rune.int > 0xffff: 2 else: 1)
    inc count

proc runeOffset(text: string, index: int, roundUp = false): int =
  ## Expands nonempty selections that land inside a surrogate pair.
  var count = 0
  for rune in text.runes:
    let size = if rune.int > 0xffff: 2 else: 1
    if count >= index or (count + size > index and not roundUp):
      break
    count += size
    inc result

proc publishNativeText(window: Window) =
  let state = window.textInput
  var text = state.text.wstr()
  windyTextPublish(
    window.textProvider, cast[ptr WCHAR](text[0].addr),
    state.text.utf16Offset(min(state.selectionStart, state.selectionEnd)),
    state.text.utf16Offset(max(state.selectionStart, state.selectionEnd)),
    state.text.utf16Offset(state.visibleStart),
    state.text.utf16Offset(state.visibleEnd),
    state.bounds.x, state.bounds.y, state.bounds.w, state.bounds.h,
    cint(window.onTextEdit != nil),
    cint(GetForegroundWindow() == window.hWnd and GetFocus() == window.hWnd)
  )

proc setTextInputState*(window: Window, state: TextInputState) =
  ## Publishes the focused nonsecure editor through Windows UI Automation.
  ## The native provider exposes Value and Text patterns without a hidden edit
  ## control, so keyboard focus, rendering and IME stay owned by Windy/Silky.
  if window.state.closed:
    return
  if state.id.len == 0 or state.password or not window.state.runeInputEnabled:
    window.clearNativeText()
    return
  if state.id != window.textInput.id:
    window.pendingSurrogate = 0
    window.clearNativeText()
  window.textInput = state
  let count = state.text.runeLen
  window.textInput.selectionStart = clamp(state.selectionStart, 0, count)
  window.textInput.selectionEnd = clamp(state.selectionEnd, 0, count)
  if window.textProvider == nil:
    var id = state.id.wstr()
    window.textProvider = windyTextCreate(window.textRoot, cast[ptr WCHAR](id[0].addr))
  window.publishNativeText()

proc nativeTextEdit(
  context: pointer, kind, start, finish: cint, value: ptr WCHAR
): cint {.cdecl.} =
  ## Runs only in wndProc, never on an automation client's COM worker thread.
  let window = cast[Window](context)
  if not window.hasTextInput or window.onTextEdit == nil:
    return 0
  let
    runes = window.textInput.text.toRunes
    first = window.textInput.text.runeOffset(max(0, start.int))
    last = if finish < 0: runes.len else:
      max(first, window.textInput.text.runeOffset(finish.int, finish > start))
  var edit = TextInputEdit(
    kind: (if kind == 0: ReplaceText else: SelectText),
    start: first, length: last - first
  )
  if edit.kind == ReplaceText:
    if value == nil:
      return 0
    edit.text = $value
    var text: string
    for i in 0 ..< first:
      text.add($runes[i])
    text.add(edit.text)
    for i in last ..< runes.len:
      text.add($runes[i])
    window.textInput.text = text
    window.textInput.selectionStart = first + edit.text.runeLen
    window.textInput.selectionEnd = window.textInput.selectionStart
  else:
    window.textInput.selectionStart = first
    window.textInput.selectionEnd = last
  # Mirror edits immediately so a client's next request sees the new state,
  # even when Silky has not yet consumed its ordered input queue.
  try:
    window.onTextEdit(edit)
    window.publishNativeText()
    result = 1
  except CatchableError:
    # Exceptions must not escape a C/COM callback boundary.
    result = 0
