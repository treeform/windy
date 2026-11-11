when defined(macosx):
  include ../src/windy/platforms/macos/platform

  type
    NSPasteboardItem = distinct NSObject
    NSMutableArray = distinct NSObject

  objc:
    proc retainCount(self: ID): uint
    proc windowNumber(self: NSWindow): int
    proc postEvent(self: NSApplication, x: NSEvent, atStart: bool)
    proc initWithString(
      self: NSAttributedString,
      x: NSString
    ): NSAttributedString
    proc pasteboardItems(self: NSPasteboard): NSArray
    proc writeObjects(self: NSPasteboard, x: NSArray): bool
    proc types(self: NSPasteboardItem): NSArray
    proc dataForType(self: NSPasteboardItem, x: NSPasteboardType): NSData
    proc setData(
      self: NSPasteboardItem,
      x: NSData,
      forType: NSPasteboardType
    ): bool
    proc addObject(self: NSMutableArray, x: ID)
    proc keyEventWithType(
      class: typedesc[NSEvent],
      x: uint,
      location: NSPoint,
      modifierFlags: uint,
      timestamp: float64,
      windowNumber: int,
      context: ID,
      characters: NSString,
      charactersIgnoringModifiers: NSString,
      isARepeat: bool,
      keyCode: uint16
    ): NSEvent

  when defined(useCpu):
    proc testCpuImages() =
      ## Checks image ownership after replacement and repeated close.
      let
        window = newWindow("CPU ownership", ivec2(32, 32), visible = false)
        image = newImage(32, 32)
      window.presentPixels(image)
      let first = window.cpuImage.ID
      first.retain()
      defer:
        first.release()
      let firstCount = first.retainCount()
      window.presentPixels(image)
      doAssert first.retainCount() == firstCount - 1
      let last = window.cpuImage.ID
      last.retain()
      defer:
        last.release()
      let lastCount = last.retainCount()
      window.close()
      doAssert last.retainCount() == lastCount - 1
      doAssert window.cpuImage.int == 0
      window.close()
      window.presentPixels(image)
      doAssert window.cpuImage.int == 0

    testCpuImages()

  proc testFrameClosures() =
    ## Checks closing and creating windows during frame callbacks.
    let
      first = newWindow("First", ivec2(32, 32), visible = false)
      second = newWindow("Second", ivec2(32, 32), visible = false)
      third = newWindow("Third", ivec2(32, 32), visible = false)
    var
      child: Window
      thirdFrames, childFrames: int
    first.onFrame = proc() =
      ## Closes the current and next windows and creates another window.
      first.close()
      second.close()
      child = newWindow("Child", ivec2(32, 32), visible = false)
      child.onFrame = proc() =
        ## Counts frames for the newly created window.
        inc childFrames
    second.onFrame = proc() =
      ## Rejects callbacks for a window closed earlier in this frame.
      doAssert false, "Closed window received a frame"
    third.onFrame = proc() =
      ## Counts frames for the surviving window.
      inc thirdFrames
    pollEvents()
    doAssert first.closed and second.closed
    doAssert thirdFrames == 1 and childFrames == 0
    pollEvents()
    doAssert thirdFrames == 2 and childFrames == 1
    third.close()
    child.close()

  testFrameClosures()

  proc testWindowOwnership() =
    ## Checks that closing releases the view and its tracking area.
    let
      window = newWindow("View ownership", ivec2(32, 32), visible = false)
      view = window.inner.contentView.ID
    view.retain()
    defer:
      view.release()
    autoreleasepool:
      discard updateTrackingAreas(view, s"updateTrackingAreas")
    let tracking = window.trackingArea.ID
    doAssert tracking.int != 0
    tracking.retain()
    defer:
      tracking.release()
    window.close()
    for i in 0 ..< 5:
      drainEvents()
    doAssert view.retainCount() == 1
    doAssert tracking.retainCount() == 1
    doAssert window.trackingArea.int == 0

  testWindowOwnership()

  proc testKeyboardQueue() =
    ## Checks that one poll delivers all queued key transitions in order.
    let window = newWindow("Keyboard queue", ivec2(32, 32), visible = false)
    defer:
      window.close()
    var presses, releases: seq[Button]
    window.onButtonPress = proc(button: Button) =
      ## Records press order.
      presses.add(button)
    window.onButtonRelease = proc(button: Button) =
      ## Records release order.
      releases.add(button)
    autoreleasepool:
      for keyCode in [0.uint16, 11, 8]:
        for eventType in [10.uint, 11]:
          let event = NSEvent.keyEventWithType(
            eventType,
            NSMakePoint(0, 0),
            0,
            0,
            window.inner.windowNumber(),
            0.ID,
            @"a",
            @"a",
            false,
            keyCode
          )
          NSApp.postEvent(event, false)
      pollEvents()
    doAssert presses == @[KeyA, KeyB, KeyC]
    doAssert releases == presses
    for button in presses:
      doAssert window.buttonPressed[button]
      doAssert window.buttonReleased[button]
      doAssert not window.buttonDown[button]

  testKeyboardQueue()

  proc testNativeTextInput() =
    ## Checks native and legacy insertions remain single Unicode edits.
    const Text = "First 🙂 世界\nSecond\tline"
    let
      window = newWindow("Text insertion", ivec2(32, 32), visible = false)
      client = window.inner.contentView.NSTextInputClient
    defer:
      window.close()
      doAssert window.onTextInput == nil
    var
      insertions: seq[string]
      runes: seq[Rune]
    window.runeInputEnabled = true
    window.onTextInput = proc(text: string) =
      ## Records complete insertions.
      insertions.add(text)
    window.onRune = proc(rune: Rune) =
      ## Records legacy fallback callbacks.
      runes.add(rune)
    autoreleasepool:
      client.insertText((@Text).ID, kEmptyRange)
      client.insertText((@Text).ID)
      let attributed = NSAttributedString.alloc().initWithString(@Text)
      client.insertText(attributed.ID, kEmptyRange)
      attributed.ID.release()
      doAssert insertions == @[Text, Text, Text]
      doAssert runes.len == 0
      client.insertText((@("a" & $Rune(0xf700) & "b")).ID)
      doAssert insertions[^1] == "ab"
      window.runeInputEnabled = false
      client.insertText((@Text).ID, kEmptyRange)
      client.insertText((@Text).ID)
      doAssert insertions.len == 4
      window.runeInputEnabled = true
      window.onTextInput = nil
      client.insertText((@Text).ID)
      doAssert runes == "First 🙂 世界Secondline".toRunes

  testNativeTextInput()

  proc testNativePaste() =
    ## Checks paste captures text before a dictation tool restores clipboard.
    const Text = "Dictated 🙂 text\nwith another paragraph."
    let
      window = newWindow("Native paste", ivec2(32, 32), visible = false)
      view = window.inner.contentView
      pasteboard = NSPasteboard.generalPasteboard()
      saved = NSMutableArray.new()
    defer:
      window.close()
      pasteboard.clearContents()
      if saved.NSArray.count > 0:
        doAssert pasteboard.writeObjects(saved.NSArray)
      saved.ID.release()
    let items = pasteboard.pasteboardItems()
    for i in 0 ..< items.count.int:
      let
        original = items[i].NSPasteboardItem
        copy = NSPasteboardItem.new()
        types = original.types()
      for j in 0 ..< types.count.int:
        let
          kind = types[j].NSPasteboardType
          data = original.dataForType(kind)
        if data.int != 0:
          doAssert copy.setData(data, kind)
      saved.addObject(copy.ID)
      copy.ID.release()
    var insertions: seq[string]
    window.runeInputEnabled = true
    window.onTextInput = proc(text: string) =
      ## Records native paste values before the next frame.
      insertions.add(text)
    setClipboardString(Text)
    view.paste(0.ID)
    setClipboardString("Restored clipboard")
    doAssert insertions == @[Text]
    window.runeInputEnabled = false
    view.paste(0.ID)
    doAssert insertions == @[Text]

  testNativePaste()

  proc testSyntheticPasteModifiers() =
    ## Checks Cmd+V works when synthetic events omit flagsChanged events.
    let window = newWindow("Synthetic paste", ivec2(32, 32), visible = false)
    defer:
      window.close()
    var
      shortcuts: int
      insertions: seq[string]
    window.runeInputEnabled = true
    window.onButtonPress = proc(button: Button) =
      ## Checks the command modifier is already visible in the key callback.
      if button == KeyV:
        doAssert window.buttonDown[KeyLeftSuper]
        inc shortcuts
    window.onTextInput = proc(text: string) =
      ## Rejects ordinary text insertion for a command shortcut.
      insertions.add(text)
    autoreleasepool:
      for eventType in [10.uint, 11]:
        let
          flags =
            if eventType == 10:
              ModifierClassCommand
            else:
              0.uint
          event = NSEvent.keyEventWithType(
            eventType,
            NSMakePoint(0, 0),
            flags,
            0,
            window.inner.windowNumber(),
            0.ID,
            @"v",
            @"v",
            false,
            9
          )
        NSApp.postEvent(event, false)
      pollEvents()
    doAssert shortcuts == 1
    doAssert insertions.len == 0
    doAssert not window.buttonDown[KeyLeftSuper]
    doAssert not window.buttonDown[KeyV]
    window.syncModifierState(ModifierClassCommand or DeviceRightCommand)
    window.syncModifierState(ModifierClassCommand)
    doAssert window.buttonDown[KeyRightSuper]
    doAssert not window.buttonDown[KeyLeftSuper]
    window.syncModifierState(0)
    doAssert not window.buttonDown[KeyRightSuper]

  testSyntheticPasteModifiers()

  proc testWindowCenter() =
    ## Checks that native frame centers agree on Retina and 1x screens.
    for size in [ivec2(320, 200), ivec2(800, 600)]:
      for style in [DecoratedResizable, Decorated, Undecorated]:
        let window = newWindow(
          "Centered window",
          size,
          style = style,
          visible = false
        )
        defer:
          window.close()
        let
          frame = window.inner.frame
          screen = window.inner.screen.frame
          dx = frame.origin.x + frame.size.width / 2 -
            (screen.origin.x + screen.size.width / 2)
          dy = frame.origin.y + frame.size.height / 2 -
            (screen.origin.y + screen.size.height / 2)
        doAssert abs(dx) <= 1 and abs(dy) <= 1

  testWindowCenter()

  proc testMouseInside() =
    ## Checks containment for drags outside each edge and focus updates.
    let
      window = newWindow("Mouse bounds", ivec2(100, 100), visible = false)
      bounds = window.inner.contentView.bounds
      width = bounds.size.width
      height = bounds.size.height
    defer:
      window.close()
    for point in [
      NSMakePoint(-0.1, height / 2),
      NSMakePoint(width, height / 2),
      NSMakePoint(width / 2, height + 0.1),
      NSMakePoint(width / 2, 0)
    ]:
      handleMouseMove(window, NSMakePoint(width / 2, height / 2))
      doAssert window.mouseInside
      handleMouseMove(window, point)
      doAssert not window.mouseInside
    handleMouseMove(window, NSMakePoint(0, height))
    doAssert window.mouseInside
    doAssert window.mousePos == ivec2(0, 0)

  testMouseInside()
  echo "Windy macOS regression tests passed"
else:
  echo "Windy macOS regression tests skipped"
