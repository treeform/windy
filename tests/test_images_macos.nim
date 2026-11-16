when defined(macosx):
  include ../src/windy/platforms/macos/platform
  import chroma

  type
    NSPasteboardItem = distinct NSObject
    NSMutableArray = distinct NSObject

  objc:
    proc pasteboardItems(self: NSPasteboard): NSArray
    proc writeObjects(self: NSPasteboard, x: NSArray): bool
    proc pasteboardWithUniqueName(class: typedesc[NSPasteboard]): NSPasteboard
    proc releaseGlobally(self: NSPasteboard)
    proc types(self: NSPasteboardItem): NSArray
    proc dataForType(self: NSPasteboardItem, x: NSPasteboardType): NSData
    proc setData(
      self: NSPasteboardItem,
      x: NSData,
      forType: NSPasteboardType
    ): bool
    proc addObject(self: NSMutableArray, x: ID)

  proc testImageClipboard() =
    ## Checks lossless image copies while preserving every clipboard type.
    init()
    let
      pasteboard = NSPasteboard.generalPasteboard()
      saved = NSMutableArray.new()
      items = pasteboard.pasteboardItems()
    defer:
      pasteboard.clearContents()
      if saved.NSArray.count > 0:
        doAssert pasteboard.writeObjects(saved.NSArray)
      saved.ID.release()
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
    let source = newImage(2, 2)
    source[0, 0] = rgbx(255, 0, 0, 255)
    source[1, 0] = rgbx(0, 255, 0, 255)
    source[0, 1] = rgbx(0, 0, 255, 255)
    source[1, 1] = rgbx(60, 40, 20, 128)
    setClipboardImage(source)
    doAssert getClipboardContentKinds() == {ImageContent}
    let copied = getClipboardImage()
    doAssert copied != nil
    doAssert copied.width == 2 and copied.height == 2
    doAssert copied.data == source.data
    var rejected = false
    try:
      setClipboardImage(nil)
    except WindyError:
      rejected = true
    doAssert rejected
    doAssert getClipboardImage().data == source.data
    setClipboardString("Text still works")
    doAssert getClipboardContentKinds() == {TextContent}
    doAssert getClipboardString() == "Text still works"

  proc testFilePaths() =
    ## Checks modern native URLs and path-only callbacks without file reads.
    const
      Paths = @[
        "/tmp/Runway picture café.png",
        "/tmp/Runway document with spaces.pdf"
      ]
      NativePaths = @[
        "/tmp/Runway picture cafe\u0301.png",
        "/tmp/Runway document with spaces.pdf"
      ]
    let
      pasteboard = NSPasteboard.pasteboardWithUniqueName()
      urls = NSMutableArray.new()
    defer:
      pasteboard.releaseGlobally()
      urls.ID.release()
    for path in Paths:
      urls.addObject(NSURL.fileURLWithPath(@path, false).ID)
    doAssert pasteboard.writeObjects(urls.NSArray)
    let paths = pasteboardFilePaths(pasteboard)
    doAssert paths == NativePaths, $paths
    var received: seq[string]
    let window = Window()
    window.onFileDropPaths = proc(paths: seq[string]) =
      ## Records a drop without eagerly opening any path.
      received = paths
    window.onFileDrop = proc(path, data: string) =
      ## Rejects fallback delivery while a path callback is installed.
      doAssert false
    window.deliverFileDrop(Paths)
    doAssert received == Paths
    doAssert window.deliverPasteboardDrop(pasteboard)
    doAssert received == NativePaths

  proc testImageDrop() =
    ## Delivers image pixels without requiring a source file path.
    let
      pasteboard = NSPasteboard.pasteboardWithUniqueName()
      source = newImage(2, 2)
      window = Window()
    defer:
      pasteboard.releaseGlobally()
    source[0, 0] = rgbx(255, 0, 0, 255)
    source[1, 1] = rgbx(30, 60, 120, 128)
    var encoded = source.encodePng()
    doAssert pasteboard.setData(
      NSData.dataWithBytes(encoded[0].addr, encoded.len),
      NSPasteboardTypePNG
    )
    var called = false
    window.onFileDropPaths = proc(paths: seq[string]) =
      ## Rejects nonexistent file paths for a raw image drop.
      doAssert false
    window.onFileDrop = proc(name, data: string) =
      ## Checks the image contents rather than its native representation.
      doAssert name == "Dropped image.png"
      doAssert decodePng(data).convertToImage().data == source.data
      called = true
    doAssert window.deliverPasteboardDrop(pasteboard)
    doAssert called

  testImageClipboard()
  testFilePaths()
  testImageDrop()
  echo "Native image clipboard and file paths passed."
