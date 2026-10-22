import
  pixie,
  ../../common,
  ./backends,
  ./native/[state, drm, framebuffer, touch]

when HasX11:
  import ./x11
  type Window* = x11.Window
else:
  type Window* = ref object
    onCloseRequest*, onFrame*, onMove*, onResize*, onFocusChange*: Callback
    onMouseMove*, onScroll*, onImeChange*: Callback
    onButtonPress*, onButtonRelease*: ButtonCallback
    onRune*: RuneCallback
    onFileDrop*: FileDropCallback
    onTouch*: TouchCallback
    direct*: DirectWindowState

var windows: seq[Window]

proc close*(window: Window) =
  if window.direct == nil or window.direct.closed:
    return
  let data = window.direct
  data.closed = true
  try:
    if data.touch != nil:
      try:
        for event in data.touch.cancel():
          data.contacts.setLen(0)
          if window.onTouch != nil: window.onTouch(event)
      finally:
        data.touch.close()
  finally:
    try:
      if data.fb != nil: data.fb.close()
      if data.drm != nil and data.screen != nil:
        data.drm.closeScreen(data.screen)
    finally:
      if data.drm != nil:
        for index, screen in data.drm.screens:
          if screen == data.screen:
            data.drm.screens.delete(index)
            break
        if data.drm.screens.len == 0:
          data.drm.close()
      for index, current in windows:
        if current == window:
          windows.delete(index)
          break

proc newDirectWindow*(title: string, backend: LinuxBackend,
    options: LinuxWindowOptions): Window =
  let path = if options.device.len > 0: options.device
    elif backend == FbdevBackend: "/dev/fb0" else: "/dev/dri/card0"
  result = Window(direct: DirectWindowState(title: title, device: path, backend: backend))
  let data = result.direct
  try:
    if backend == FbdevBackend:
      for window in windows:
        if window.direct.device == path:
          raise newException(WindyError, "Framebuffer is already owned: " & path)
      data.fb = openFramebuffer(path, options.rotation)
    else:
      if options.output.len == 0:
        raise newException(WindyError, "A DRM connector must be selected")
      for window in windows:
        if window.direct.backend == DrmBackend and window.direct.device == path:
          data.drm = window.direct.drm
          break
      if data.drm == nil:
        data.drm = openDrm(path)
      data.drm.openOutput(@[options.output], options.rotation)
      data.screen = data.drm.screens[^1]
    if options.touchDevice.len > 0:
      for window in windows:
        if window.direct.touch != nil and window.direct.touch.path == options.touchDevice:
          raise newException(WindyError, "Touchscreen is already assigned")
      let
        width = if data.fb != nil: data.fb.width else: data.screen.width
        height = if data.fb != nil: data.fb.height else: data.screen.height
      data.touch = openTouch(options.touchDevice, width, height, options.touchRotation)
    windows.add result
  except:
    result.close()
    raise

proc size*(window: Window): IVec2 =
  let data = window.direct
  if data.fb != nil: ivec2(data.fb.width.int32, data.fb.height.int32)
  else: ivec2(data.screen.width.int32, data.screen.height.int32)

proc framebufferSize*(window: Window): IVec2 = window.size
proc closed*(window: Window): bool = window.direct.closed
proc closeRequested*(window: Window): bool = window.direct.closeRequested
proc `closeRequested=`*(window: Window, value: bool) = window.direct.closeRequested = value
proc title*(window: Window): string = window.direct.title
proc `title=`*(window: Window, value: string) = window.direct.title = value
proc contentScale*(window: Window): float32 = 1
proc fullscreen*(window: Window): bool = true
proc visible*(window: Window): bool = not window.closed
proc focused*(window: Window): bool = not window.closed
proc pos*(window: Window): IVec2 = ivec2(0, 0)
proc touches*(window: Window): seq[TouchContact] = window.direct.contacts
proc buttonDown*(window: Window): ButtonView = ButtonView({})
proc buttonPressed*(window: Window): ButtonView = ButtonView({})
proc buttonReleased*(window: Window): ButtonView = ButtonView({})

proc presentPixels*(window: Window, image: Image) =
  if window.closed:
    raise newException(WindyError, "Cannot present to a closed window")
  let data = window.direct
  if data.fb != nil:
    data.fb.present(image)
  else:
    for index, screen in data.drm.screens:
      if screen == data.screen:
        data.drm.present(index, image)
        return

proc pollEvents*() =
  let current = windows
  for window in current:
    if window.closed: continue
    let data = window.direct
    if data.touch != nil:
      for event in data.touch.poll():
        var found = -1
        for index, contact in data.contacts:
          if contact.id == event.contact.id: found = index
        if event.phase in {TouchEnd, TouchCancel}:
          if found >= 0: data.contacts.delete(found)
        elif found >= 0:
          data.contacts[found] = event.contact
        else:
          data.contacts.add event.contact
        if window.onTouch != nil: window.onTouch(event)
        if window.closed: break
    if not window.closed and window.onFrame != nil:
      window.onFrame()

proc hasWindows*(): bool = windows.len > 0

proc unsupported*() =
  raise newException(WindyError, "Operation is unavailable on a direct display")

proc minimized*(window: Window): bool = unsupported()
proc maximized*(window: Window): bool = unsupported()
proc style*(window: Window): WindowStyle = unsupported()
proc runeInputEnabled*(window: Window): bool = unsupported()
proc cursor*(window: Window): Cursor = unsupported()
proc mousePos*(window: Window): IVec2 = unsupported()
proc mousePrevPos*(window: Window): IVec2 = unsupported()
proc mouseDelta*(window: Window): IVec2 = unsupported()
proc mouseInside*(window: Window): bool = unsupported()
proc mouseCaptured*(window: Window): bool = unsupported()
proc scrollDelta*(window: Window): Vec2 = unsupported()
proc buttonToggle*(window: Window): ButtonView = unsupported()
proc imeCursorIndex*(window: Window): int = unsupported()
proc imeCompositionString*(window: Window): string = unsupported()
proc url*(window: Window): string = unsupported()
