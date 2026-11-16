import
  std/[monotimes, times],
  pixie,
  ../../../common,
  ../x11/keysym,
  ./state,
  ./xembed/xlib

type
  XembedTray* = ref object
    display: Display
    root, manager, icon, popup, tooltipWindow: xlib.Window
    selection, managerAtom, opcode, embed, embedInfo: Atom
    visual: ptr Visual
    depth: cint
    colormap: Colormap
    gc, popupGc: GC
    fonts: FontSet
    state: TrayState
    width, height, popupWidth, popupHeight: int
    hovered: int
    hoverStart: MonoTime
    pointerInside: bool
    errorCode: int
    available*: bool

const
  RowHeight = 26
  SeparatorHeight = 9
  MenuPadding = 6
  TooltipDelayMs = 700
  EventBatchSize = 64
  MaximumIconExtent = 1024
  CwBackPixmap = 1.culong
  CwBackPixel = 2.culong
  CwBorderPixel = 8.culong
  CwOverrideRedirect = 512.culong
  CwEventMask = 2048.culong
  CwColormap = 8192.culong
  ZPixmap = 2.cint
  GetImageRequest = 73

var
  errorTray: XembedTray
  previousErrorHandler: ErrorHandleProc

proc trayError(d: Display, event: ptr XErrorEvent): cint {.cdecl.} =
  ## Captures only this private connection's errors, preserving other clients.
  if errorTray != nil and d == errorTray.display:
    # The panel can unmap or resize the plug between exposure and XGetImage.
    if event.errorCode.int == badMatch.ord and event.requestCode.int == GetImageRequest:
      return 0
    if errorTray.errorCode == 0 or event.errorCode.int notin [badWindow.ord, badDrawable.ord]:
      errorTray.errorCode = event.errorCode.int
  elif previousErrorHandler != nil:
    return previousErrorHandler(d, event)

template withErrors(tray: XembedTray, body: untyped) =
  block:
    errorTray = tray
    previousErrorHandler = XSetErrorHandler(trayError)
    try:
      body
    finally:
      # Drain errors before restoring the process-wide handler.
      tray.display.XSync()
      discard XSetErrorHandler(previousErrorHandler)
      errorTray = nil
    if tray.errorCode notin [0, badWindow.ord, badDrawable.ord]:
      let code = tray.errorCode
      tray.errorCode = 0
      raise newException(WindyError, "XEmbed X11 error: " & $code)
    tray.errorCode = 0

proc atom(tray: XembedTray, name: string): Atom =
  ## Interns an atom on the private display.
  tray.display.XInternAtom(name.cstring, 0)

proc hidePopup(tray: XembedTray) =
  ## Releases menu grabs before destroying the popup.
  if tray.popup != 0:
    tray.display.XUngrabPointer(CurrentTime)
    discard tray.display.XUngrabKeyboard(CurrentTime)
    tray.display.XDestroyWindow(tray.popup)
    tray.popup = 0
  if tray.popupGc != nil:
    tray.display.XFreeGC(tray.popupGc)
    tray.popupGc = nil

proc hideTooltip(tray: XembedTray) =
  ## Removes a visible tooltip when interaction or embedding changes.
  if tray.tooltipWindow != 0:
    tray.display.XDestroyWindow(tray.tooltipWindow)
    tray.tooltipWindow = 0

proc removeIcon(tray: XembedTray) =
  ## Releases the plug and its resources while keeping manager discovery alive.
  tray.hidePopup()
  tray.hideTooltip()
  if tray.icon != 0:
    tray.display.XDestroyWindow(tray.icon)
    tray.icon = 0
  if tray.gc != nil:
    tray.display.XFreeGC(tray.gc)
    tray.gc = nil
  if tray.colormap != 0:
    tray.display.XFreeColormap(tray.colormap)
    tray.colormap = 0
  tray.pointerInside = false

proc managerChanged(tray: XembedTray) =
  ## Resolves the manager after startup or an ownership announcement.
  let owner = tray.display.XGetSelectionOwner(tray.selection)
  if owner != tray.manager:
    tray.removeIcon()
    tray.manager = owner
    if owner != 0:
      tray.display.XSelectInput(owner, StructureNotifyMask)
  tray.available = owner != 0

proc newXembedTray*(state: TrayState): XembedTray =
  ## Starts XEmbed discovery without initializing Windy's window or GL backend.
  result = XembedTray(state: state, hovered: -1)
  result.display = XOpenDisplay(nil)
  if result.display == nil: return
  try:
    result.root = result.display.defaultRootWindow()
    result.selection = result.atom("_NET_SYSTEM_TRAY_S" & $result.display.defaultScreen())
    result.managerAtom = result.atom("MANAGER")
    result.opcode = result.atom("_NET_SYSTEM_TRAY_OPCODE")
    result.embed = result.atom("_XEMBED")
    result.embedInfo = result.atom("_XEMBED_INFO")
    withErrors(result):
      result.display.XSelectInput(result.root, StructureNotifyMask)
      result.managerChanged()
  except:
    discard result.display.XCloseDisplay()
    result.display = nil
    raise

proc visualInfo(tray: XembedTray) =
  ## Uses the manager's requested visual, falling back to the screen default.
  let screen = tray.display.screen(tray.display.defaultScreen())
  tray.visual = screen.rootVisual
  tray.depth = screen.rootDepth
  var
    kind: Atom
    format: cint
    length, remaining: culong
    data: cstring
  tray.display.XGetWindowProperty(tray.manager, tray.atom("_NET_SYSTEM_TRAY_VISUAL"),
    0, 1, false, AnyPropertyType, kind.addr, format.addr, length.addr, remaining.addr, data.addr)
  if data != nil:
    defer: XFree(data)
    if format == 32 and length == 1:
      var info = XVisualInfo(visualid: cast[ptr culong](data)[])
      var count: cint
      let found = tray.display.XGetVisualInfo(1, info.addr, count.addr)
      if found != nil:
        tray.visual = found.visual
        tray.depth = found.depth
        XFree(found)

proc dock(tray: XembedTray) =
  ## Creates a mapped XEmbed plug and requests docking with the current manager.
  tray.visualInfo()
  tray.width = 24
  tray.height = 24
  tray.colormap = tray.display.XCreateColormap(tray.root, tray.visual, 0)
  var attrs = XSetWindowAttributes(
    colormap: tray.colormap, borderPixel: 0,
    eventMask: ExposureMask or StructureNotifyMask or ButtonReleaseMask or
      EnterWindowMask or LeaveWindowMask)
  # ParentRelative is valid when the embedder uses the same visual/depth.
  let screen = tray.display.screen(tray.display.defaultScreen())
  var mask = CwColormap or CwBorderPixel or CwEventMask
  if tray.depth == screen.rootDepth:
    attrs.backgroundPixmap = ParentRelative
    mask = mask or CwBackPixmap
  else:
    mask = mask or CwBackPixel
  tray.icon = tray.display.XCreateWindow(tray.root, 0, 0, 24, 24, 0,
    tray.depth.cuint, 1, tray.visual, mask, attrs.addr)
  tray.gc = tray.display.XCreateGC(tray.icon, 0, nil)
  var info: array[2, culong] = [0.culong, 1.culong]
  tray.display.XChangeProperty(tray.icon, tray.embedInfo, tray.embedInfo, 32,
    pmReplace, info[0].addr, 2)
  tray.display.Xutf8SetWMProperties(tray.icon, tray.state.tooltip.cstring,
    tray.state.tooltip.cstring, nil, 0, nil, nil, nil)
  var event: XEvent
  event.client = XClientMessageEvent(kind: xeClientMessage, window: tray.manager,
    message_type: tray.opcode, format: 32)
  event.client.data.l = [CurrentTime.clong, 0.clong, tray.icon.clong, 0.clong, 0.clong]
  tray.display.XSendEvent(tray.manager, false, NoEventMask, event.addr)
  tray.display.XMapWindow(tray.icon)

proc channel(value: uint8, mask: culong): culong =
  ## Scales a color channel into an arbitrary TrueColor visual mask.
  if mask == 0: return 0
  var shift = 0
  while ((mask shr shift) and 1) == 0: inc shift
  ((value.culong * (mask shr shift) + 127) div 255 shl shift) and mask

proc paintIcon(tray: XembedTray) =
  ## Scales the icon and paints premultiplied alpha using the selected visual.
  if tray.icon == 0 or tray.width <= 0 or tray.height <= 0: return
  let image = tray.display.XCreateImage(tray.visual, tray.depth.cuint, ZPixmap, 0,
    nil, tray.width.cuint, tray.height.cuint, 32, 0)
  if image == nil: raise newException(WindyError, "Unable to allocate XEmbed image")
  defer: discard XDestroyImage(image)
  image.data = cast[cstring](calloc(tray.height.csize_t, image.bytesPerLine.csize_t))
  if image.data == nil: raise newException(WindyError, "Unable to allocate XEmbed pixels")
  let
    rgbMask = tray.visual.redMask or tray.visual.greenMask or tray.visual.blueMask
    alphaMask = if tray.depth == 32: (0xffffffff.culong xor rgbMask) else: 0.culong
    scale = min(tray.width.float32 / tray.state.icon.width.float32,
      tray.height.float32 / tray.state.icon.height.float32)
    width = max(1, int(tray.state.icon.width.float32 * scale))
    height = max(1, int(tray.state.icon.height.float32 * scale))
    resized = tray.state.icon.resize(width, height)
    offsetX = (tray.width - width) div 2
    offsetY = (tray.height - height) div 2
  var background: ptr XImage
  if alphaMask == 0:
    discard tray.display.XClearArea(tray.icon, 0, 0, 0, 0, 0)
    background = tray.display.XGetImage(tray.icon, 0, 0, tray.width.cuint,
      tray.height.cuint, high(culong), ZPixmap)
  defer:
    if background != nil: discard XDestroyImage(background)
  for y in 0..<tray.height:
    for x in 0..<tray.width:
      var c: ColorRGBX
      if x >= offsetX and x < offsetX + width and y >= offsetY and y < offsetY + height:
        c = resized[x - offsetX, y - offsetY]
      var pixel = channel(c.r, tray.visual.redMask) or
        channel(c.g, tray.visual.greenMask) or channel(c.b, tray.visual.blueMask)
      if alphaMask != 0:
        pixel = pixel or channel(c.a, alphaMask)
      elif background != nil:
        let bg = XGetPixel(background, x.cint, y.cint)
        for mask in [tray.visual.redMask, tray.visual.greenMask, tray.visual.blueMask]:
          let part = ((bg and mask) * (255 - c.a).culong div 255) and mask
          pixel = pixel + part
      discard XPutPixel(image, x.cint, y.cint, pixel)
  discard tray.display.XPutImage(tray.icon, tray.gc, image, 0, 0, 0, 0,
    tray.width.cuint, tray.height.cuint)

proc ensureFonts(tray: XembedTray) =
  ## Uses Xlib UTF-8 text with server fonts, without changing process locale.
  if tray.fonts != nil: return
  var
    missing: ptr cstring
    count: cint
    defaultString: cstring
  tray.fonts = tray.display.XCreateFontSet("-*-*-medium-r-normal--14-*-*-*-*-*-*-*,fixed",
    missing.addr, count.addr, defaultString.addr)
  if missing != nil: XFreeStringList(missing)
  if tray.fonts == nil:
    raise newException(WindyError, "No X11 font set is available for the tray menu")

proc textWidth(tray: XembedTray, text: string): int =
  ## Measures a UTF-8 label using the popup's font set.
  tray.ensureFonts()
  Xutf8TextEscapement(tray.fonts, text.cstring, text.len.cint).int

proc rowHeight(entry: TrayMenuEntry): int =
  ## Gives separators less space than selectable rows.
  if entry.kind == TrayMenuSeparator: SeparatorHeight else: RowHeight

proc rowAt(tray: XembedTray, x, y: int): int =
  ## Returns a selectable row within the popup bounds.
  if x < 0 or x >= tray.popupWidth: return -1
  var top = MenuPadding
  for index, entry in tray.state.menu:
    if y >= top and y < top + entry.rowHeight():
      return if entry.kind == TrayMenuOption: index else: -1
    top += entry.rowHeight()
  -1

proc popupPixel(tray: XembedTray, rgb: culong): culong =
  ## Packs popup colors for the default screen visual, including RGB565.
  let visual = tray.display.screen(tray.display.defaultScreen()).rootVisual
  channel(uint8((rgb shr 16) and 255), visual.redMask) or
    channel(uint8((rgb shr 8) and 255), visual.greenMask) or
    channel(uint8(rgb and 255), visual.blueMask)

proc paintPopup(tray: XembedTray) =
  ## Draws the flat menu, highlighting the selected option.
  discard tray.display.XSetForeground(tray.popupGc, tray.popupPixel(0xf4f4f4))
  discard tray.display.XFillRectangle(tray.popup, tray.popupGc, 0, 0,
    tray.popupWidth.cuint, tray.popupHeight.cuint)
  var top = MenuPadding
  for index, entry in tray.state.menu:
    if index == tray.hovered:
      discard tray.display.XSetForeground(tray.popupGc, tray.popupPixel(0x3366aa))
      discard tray.display.XFillRectangle(tray.popup, tray.popupGc, 2, top.cint,
        (tray.popupWidth - 4).cuint, RowHeight.cuint)
    discard tray.display.XSetForeground(tray.popupGc,
      tray.popupPixel(if index == tray.hovered: 0xffffff else: 0x202020))
    if entry.kind == TrayMenuSeparator:
      discard tray.display.XDrawLine(tray.popup, tray.popupGc, MenuPadding.cint,
        (top + 4).cint, (tray.popupWidth - MenuPadding).cint, (top + 4).cint)
    else:
      tray.display.Xutf8DrawString(tray.popup, tray.fonts, tray.popupGc,
        MenuPadding.cint, (top + 18).cint, entry.text.cstring, entry.text.len.cint)
    top += entry.rowHeight()

proc floatingWindow(tray: XembedTray, x, y, width, height: int): xlib.Window =
  ## Creates an undecorated popup constrained to the X screen.
  let screen = tray.display.screen(tray.display.defaultScreen())
  var attrs = XSetWindowAttributes(overrideRedirect: 1, backgroundPixel: tray.popupPixel(0xf4f4f4),
    borderPixel: tray.popupPixel(0x555555), eventMask: ExposureMask or ButtonPressMask or
      ButtonReleaseMask or PointerMotionMask or KeyPressMask)
  result = tray.display.XCreateWindow(tray.root,
    max(0, min(x, screen.size.x.int - width - 2)).cint,
    max(0, min(y, screen.size.y.int - height - 2)).cint,
    width.cuint, height.cuint, 1, screen.rootDepth.cuint, 1, screen.rootVisual,
    CwBackPixel or CwBorderPixel or CwOverrideRedirect or CwEventMask, attrs.addr)
  tray.display.XMapWindow(result)
  tray.display.XRaiseWindow(result)

proc showPopup(tray: XembedTray, x, y: int) =
  ## Opens the menu and acquires input only for its lifetime.
  tray.hideTooltip()
  tray.hidePopup()
  if tray.state.menu.len == 0: return
  tray.popupWidth = 100
  tray.popupHeight = MenuPadding * 2
  for entry in tray.state.menu:
    tray.popupHeight += entry.rowHeight()
    if entry.kind == TrayMenuOption:
      tray.popupWidth = max(tray.popupWidth, tray.textWidth(entry.text) + MenuPadding * 2)
  tray.popup = tray.floatingWindow(x, y, tray.popupWidth, tray.popupHeight)
  tray.popupGc = tray.display.XCreateGC(tray.popup, 0, nil)
  tray.hovered = -1
  if tray.display.XGrabPointer(tray.popup, 0, (ButtonPressMask or ButtonReleaseMask or
      PointerMotionMask).cuint, GrabModeAsync, GrabModeAsync, 0, 0, CurrentTime) != GrabSuccess:
    tray.hidePopup()
    return
  if tray.display.XGrabKeyboard(tray.popup, 0, GrabModeAsync, GrabModeAsync, CurrentTime) != GrabSuccess:
    tray.hidePopup()
    return
  tray.paintPopup()

proc showTooltip(tray: XembedTray) =
  ## Displays the current tooltip after a quiet hover interval.
  if tray.state.tooltip.len == 0: return
  var root, child: xlib.Window
  var rootX, rootY, windowX, windowY: cint
  var mask: cuint
  if tray.display.XQueryPointer(tray.root, root.addr, child.addr, rootX.addr,
      rootY.addr, windowX.addr, windowY.addr, mask.addr) == 0: return
  let width = tray.textWidth(tray.state.tooltip) + MenuPadding * 2
  tray.tooltipWindow = tray.floatingWindow(rootX.int + 12, rootY.int + 20, width, RowHeight)

proc paintTooltip(tray: XembedTray) =
  ## Paints tooltip text after the window becomes visible.
  let gc = tray.display.XCreateGC(tray.tooltipWindow, 0, nil)
  defer: tray.display.XFreeGC(gc)
  discard tray.display.XSetForeground(gc, tray.popupPixel(0x202020))
  tray.display.Xutf8DrawString(tray.tooltipWindow, tray.fonts, gc, MenuPadding,
    18, tray.state.tooltip.cstring, tray.state.tooltip.len.cint)

proc setActive*(tray: XembedTray, active: bool) =
  ## Docks or removes this backend's icon without stopping host discovery.
  if tray.display == nil: return
  if (active and tray.available and tray.icon == 0) or (not active and tray.icon != 0):
    withErrors(tray):
      if active: tray.dock()
      else: tray.removeIcon()

proc update*(tray: XembedTray, state: TrayState) =
  ## Replaces icon content and dismisses menus containing old callbacks.
  tray.state = state
  if tray.display == nil or tray.icon == 0: return
  withErrors(tray):
    tray.hidePopup()
    tray.hideTooltip()
    tray.display.Xutf8SetWMProperties(tray.icon, state.tooltip.cstring,
      state.tooltip.cstring, nil, 0, nil, nil, nil)
    tray.paintIcon()

proc poll*(tray: XembedTray): seq[Callback] =
  ## Reads only this connection's events; idle calls make no server round trips.
  if tray.display == nil: return
  let tooltipDue = tray.pointerInside and tray.popup == 0 and tray.tooltipWindow == 0 and
    tray.state.tooltip.len > 0 and (getMonoTime() - tray.hoverStart).inMilliseconds >= TooltipDelayMs
  if tray.display.XPending() == 0 and not tooltipDue: return
  withErrors(tray):
    for unused in 0..<EventBatchSize:
      if tray.display.XPending() == 0: break
      var event: XEvent
      tray.display.XNextEvent(event.addr)
      let window = event.any.window
      case event.kind
      of xeClientMessage:
        if event.client.message_type == tray.managerAtom and event.client.format == 32 and
            event.client.data.l[1].culong == tray.selection:
          tray.managerChanged()
        elif event.client.message_type == tray.embed and window == tray.icon and
            event.client.data.l[1] == 0:
          tray.paintIcon()
      of xeDestroy:
        if window == tray.manager:
          tray.manager = 0
          tray.available = false
          tray.removeIcon()
        elif window == tray.icon:
          tray.icon = 0
          tray.removeIcon()
      of xeConfigure:
        if window == tray.icon:
          tray.width = min(MaximumIconExtent, max(1, event.configure.size.x.int))
          tray.height = min(MaximumIconExtent, max(1, event.configure.size.y.int))
          tray.paintIcon()
      of xeExpose:
        if window == tray.icon: tray.paintIcon()
        elif window == tray.popup: tray.paintPopup()
        elif window == tray.tooltipWindow: tray.paintTooltip()
      of xeEnter:
        if window == tray.icon:
          tray.pointerInside = true
          tray.hoverStart = getMonoTime()
      of xeLeave:
        if window == tray.icon:
          tray.pointerInside = false
          tray.hideTooltip()
      of xeButtonPress:
        if window == tray.popup:
          tray.hovered = tray.rowAt(event.button.pos.x.int, event.button.pos.y.int)
          if tray.hovered < 0: tray.hidePopup()
      of xeButtonRelease:
        if window == tray.icon:
          tray.hideTooltip()
          if event.button.button == 1 and tray.state.onClick != nil:
            result.add tray.state.onClick
          elif event.button.button == 3:
            tray.showPopup(event.button.rootPos.x.int, event.button.rootPos.y.int)
        elif window == tray.popup:
          let index = tray.rowAt(event.button.pos.x.int, event.button.pos.y.int)
          if index >= 0:
            let callback = tray.state.menuCallback((index + 1).int32)
            tray.hidePopup()
            if callback != nil: result.add callback
      of xeMotion:
        if window == tray.popup:
          tray.hovered = tray.rowAt(event.motion.pos.x.int, event.motion.pos.y.int)
          tray.paintPopup()
      of xeKeyPress:
        if window == tray.popup:
          let key = XLookupKeysym(event.key.addr, 0)
          if key == xk_Escape: tray.hidePopup()
          elif key == xk_Return:
            let callback = tray.state.menuCallback((tray.hovered + 1).int32)
            tray.hidePopup()
            if callback != nil: result.add callback
          elif key in [xk_Up, xk_Down]:
            let direction = if key == xk_Up: -1 else: 1
            if tray.hovered < 0 and direction < 0: tray.hovered = 0
            for unused in 0..<tray.state.menu.len:
              tray.hovered = (tray.hovered + direction + tray.state.menu.len) mod tray.state.menu.len
              if tray.state.menu[tray.hovered].kind == TrayMenuOption: break
            tray.paintPopup()
      else: discard
    if tooltipDue and tray.pointerInside and tray.popup == 0:
      tray.showTooltip()

proc close*(tray: XembedTray) =
  ## Releases windows, fonts, grabs, and the private display connection.
  if tray == nil or tray.display == nil: return
  withErrors(tray):
    tray.removeIcon()
    if tray.fonts != nil: tray.display.XFreeFontSet(tray.fonts)
  discard tray.display.XCloseDisplay()
  tray.display = nil
  tray.available = false
