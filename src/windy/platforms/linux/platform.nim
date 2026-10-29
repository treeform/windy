import ./backends
export backends

when not HasDirect:
  include x11

  proc setLinuxBackend*(backend: LinuxBackend) =
    if backend != X11Backend:
      raise newException(WindyError, "Backend was not compiled into Windy")
else:
  import pixie, ../../common, ./direct
  import ../../http
  export http
  when HasX11:
    import ./x11
    export x11.quitRequested, x11.onQuitRequest, x11.multiClickInterval, x11.multiClickRadius
  else:
    var
      quitRequested*: bool
      onQuitRequest*: Callback
  type Window* = direct.Window
  var selected = when HasX11: X11Backend elif HasFbdev: FbdevBackend else: DrmBackend

  proc setLinuxBackend*(backend: LinuxBackend) =
    if backend == selected: return
    if direct.hasWindows():
      raise newException(WindyError, "Close windows before changing backend")
    when HasX11:
      if x11.hasWindows():
        raise newException(WindyError, "Close windows before changing backend")
    case backend
    of X11Backend:
      when not HasX11: raise newException(WindyError, "X11 backend was not compiled")
    of FbdevBackend:
      when not HasFbdev: raise newException(WindyError, "fbdev backend was not compiled")
    of DrmBackend:
      when not HasDrm: raise newException(WindyError, "DRM backend was not compiled")
    selected = backend

  proc newWindow*(title: string, size: IVec2, style = DecoratedResizable,
      visible = true, vsync = true, openglVersion = OpenGL4Dot1,
      msaa = msaaDisabled, depthBits = 24, stencilBits = 8,
      linuxOptions = LinuxWindowOptions()): Window =
    if selected == X11Backend:
      when HasX11:
        return x11.newWindow(title, size, style, visible, vsync, openglVersion,
          msaa, depthBits, stencilBits, linuxOptions)
      else: raise newException(WindyError, "X11 backend was not compiled")
    if vsync and selected == FbdevBackend:
      raise newException(WindyError, "Framebuffer pixel presentation requires vsync=false")
    direct.newDirectWindow(title, selected, linuxOptions, vsync)

  proc pollEvents*() =
    if selected == X11Backend:
      when HasX11: x11.pollEvents()
    else:
      direct.pollEvents()
      pollHttp()

  proc closed*(window: Window): bool =
    when HasX11:
      if window.direct == nil: return x11.closed(window)
    direct.closed(window)

  proc size*(window: Window): IVec2 =
    when HasX11:
      if window.direct == nil: return x11.size(window)
    direct.size(window)

  proc framebufferSize*(window: Window): IVec2 =
    when HasX11:
      if window.direct == nil: return x11.framebufferSize(window)
    direct.framebufferSize(window)

  proc title*(window: Window): string =
    when HasX11:
      if window.direct == nil: return x11.title(window)
    direct.title(window)

  proc contentScale*(window: Window): float32 =
    when HasX11:
      if window.direct == nil: return x11.contentScale(window)
    direct.contentScale(window)

  proc fullscreen*(window: Window): bool =
    when HasX11:
      if window.direct == nil: return x11.fullscreen(window)
    direct.fullscreen(window)

  proc visible*(window: Window): bool =
    when HasX11:
      if window.direct == nil: return x11.visible(window)
    direct.visible(window)

  proc focused*(window: Window): bool =
    when HasX11:
      if window.direct == nil: return x11.focused(window)
    direct.focused(window)

  proc pos*(window: Window): IVec2 =
    when HasX11:
      if window.direct == nil: return x11.pos(window)
    direct.pos(window)

  proc touches*(window: Window): seq[TouchContact] =
    when HasX11:
      if window.direct == nil: return x11.touches(window)
    direct.touches(window)

  proc buttonDown*(window: Window): ButtonView =
    when HasX11:
      if window.direct == nil: return x11.buttonDown(window)
    direct.buttonDown(window)

  proc buttonPressed*(window: Window): ButtonView =
    when HasX11:
      if window.direct == nil: return x11.buttonPressed(window)
    direct.buttonPressed(window)

  proc buttonReleased*(window: Window): ButtonView =
    when HasX11:
      if window.direct == nil: return x11.buttonReleased(window)
    direct.buttonReleased(window)

  proc closeRequested*(window: Window): bool =
    when HasX11:
      if window.direct == nil: return x11.closeRequested(window)
    direct.closeRequested(window)

  proc close*(window: Window) =
    when HasX11:
      if window.direct == nil:
        x11.close(window)
        return
    direct.close(window)

  proc `title=`*(window: Window, value: string) =
    when HasX11:
      if window.direct == nil:
        x11.`title=`(window, value)
        return
    direct.`title=`(window, value)

  proc `closeRequested=`*(window: Window, value: bool) =
    when HasX11:
      if window.direct == nil:
        x11.`closeRequested=`(window, value)
        return
    direct.`closeRequested=`(window, value)

  when defined(useCpu):
    proc presentPixels*(window: Window, image: Image) =
      when HasX11:
        if window.direct == nil:
          x11.presentPixels(window, image)
          return
      direct.presentPixels(window, image)

  proc minimized*(window: Window): bool =
    when HasX11:
      if window.direct == nil: return x11.minimized(window)
    direct.unsupported()

  proc maximized*(window: Window): bool =
    when HasX11:
      if window.direct == nil: return x11.maximized(window)
    direct.unsupported()

  proc style*(window: Window): WindowStyle =
    when HasX11:
      if window.direct == nil: return x11.style(window)
    direct.unsupported()

  proc runeInputEnabled*(window: Window): bool =
    when HasX11:
      if window.direct == nil: return x11.runeInputEnabled(window)
    direct.unsupported()

  proc cursor*(window: Window): Cursor =
    when HasX11:
      if window.direct == nil: return x11.cursor(window)
    direct.unsupported()

  proc mousePos*(window: Window): IVec2 =
    when HasX11:
      if window.direct == nil: return x11.mousePos(window)
    direct.unsupported()

  proc mousePrevPos*(window: Window): IVec2 =
    when HasX11:
      if window.direct == nil: return x11.mousePrevPos(window)
    direct.unsupported()

  proc mouseDelta*(window: Window): IVec2 =
    when HasX11:
      if window.direct == nil: return x11.mouseDelta(window)
    direct.unsupported()

  proc mouseInside*(window: Window): bool =
    when HasX11:
      if window.direct == nil: return x11.mouseInside(window)
    direct.unsupported()

  proc mouseCaptured*(window: Window): bool =
    when HasX11:
      if window.direct == nil: return x11.mouseCaptured(window)
    direct.unsupported()

  proc scrollDelta*(window: Window): Vec2 =
    when HasX11:
      if window.direct == nil: return x11.scrollDelta(window)
    direct.unsupported()

  proc buttonToggle*(window: Window): ButtonView =
    when HasX11:
      if window.direct == nil: return x11.buttonToggle(window)
    direct.unsupported()

  proc imeCursorIndex*(window: Window): int =
    when HasX11:
      if window.direct == nil: return x11.imeCursorIndex(window)
    direct.unsupported()

  proc imeCompositionString*(window: Window): string =
    when HasX11:
      if window.direct == nil: return x11.imeCompositionString(window)
    direct.unsupported()

  proc url*(window: Window): string =
    when HasX11:
      if window.direct == nil: return x11.url(window)
    direct.unsupported()

  proc makeContextCurrent*(window: Window) =
    when HasX11:
      if window.direct == nil:
        x11.makeContextCurrent(window)
        return
    direct.unsupported()

  proc swapBuffers*(window: Window) =
    when HasX11:
      if window.direct == nil:
        x11.swapBuffers(window)
        return
    direct.unsupported()

  proc centerWindow*(window: Window) =
    when HasX11:
      if window.direct == nil:
        x11.centerWindow(window)
        return
    direct.unsupported()

  proc focus*(window: Window) =
    when HasX11:
      if window.direct == nil:
        x11.focus(window)
        return
    direct.unsupported()

  proc captureMouse*(window: Window) =
    when HasX11:
      if window.direct == nil:
        x11.captureMouse(window)
        return
    direct.unsupported()

  proc releaseMouse*(window: Window) =
    when HasX11:
      if window.direct == nil:
        x11.releaseMouse(window)
        return
    direct.unsupported()

  proc closeIme*(window: Window) =
    when HasX11:
      if window.direct == nil:
        x11.closeIme(window)
        return
    direct.unsupported()

  proc `visible=`*(window: Window, value: bool) =
    when HasX11:
      if window.direct == nil:
        x11.`visible=`(window, value)
        return
    direct.unsupported()

  proc `pos=`*(window: Window, value: IVec2) =
    when HasX11:
      if window.direct == nil:
        x11.`pos=`(window, value)
        return
    direct.unsupported()

  proc `size=`*(window: Window, value: IVec2) =
    when HasX11:
      if window.direct == nil:
        x11.`size=`(window, value)
        return
    direct.unsupported()

  proc `maximized=`*(window: Window, value: bool) =
    when HasX11:
      if window.direct == nil:
        x11.`maximized=`(window, value)
        return
    direct.unsupported()

  proc `minimized=`*(window: Window, value: bool) =
    when HasX11:
      if window.direct == nil:
        x11.`minimized=`(window, value)
        return
    direct.unsupported()

  proc `fullscreen=`*(window: Window, value: bool) =
    when HasX11:
      if window.direct == nil:
        x11.`fullscreen=`(window, value)
        return
    direct.unsupported()

  proc `style=`*(window: Window, value: WindowStyle) =
    when HasX11:
      if window.direct == nil:
        x11.`style=`(window, value)
        return
    direct.unsupported()

  proc `runeInputEnabled=`*(window: Window, value: bool) =
    when HasX11:
      if window.direct == nil:
        x11.`runeInputEnabled=`(window, value)
        return
    direct.unsupported()

  proc `cursor=`*(window: Window, value: Cursor) =
    when HasX11:
      if window.direct == nil:
        x11.`cursor=`(window, value)
        return
    direct.unsupported()

  proc `icon=`*(window: Window, value: Image) =
    when HasX11:
      if window.direct == nil:
        x11.`icon=`(window, value)
        return
    direct.unsupported()

  proc getClipboardString*(): string =
    if selected != X11Backend: direct.unsupported()
    when HasX11:
      return x11.getClipboardString()
    else: direct.unsupported()

  proc setClipboardString*(value: string) =
    if selected != X11Backend: direct.unsupported()
    when HasX11:
      x11.setClipboardString(value)
    else: direct.unsupported()

  proc getClipboardContentKinds*(): set[ClipboardContentKind] =
    if selected != X11Backend: direct.unsupported()
    when HasX11:
      return x11.getClipboardContentKinds()
    else: direct.unsupported()

  proc getClipboardImage*(): Image =
    if selected != X11Backend: direct.unsupported()
    when HasX11:
      return x11.getClipboardImage()
    else: direct.unsupported()

  proc getConfigHome*(appName: string): string =
    if selected != X11Backend: direct.unsupported()
    when HasX11:
      return x11.getConfigHome(appName)
    else: direct.unsupported()

  proc getConfig*(appName, fileName: string): string =
    if selected != X11Backend: direct.unsupported()
    when HasX11:
      return x11.getConfig(appName, fileName)
    else: direct.unsupported()

  proc setConfig*(appName, fileName, content: string) =
    if selected != X11Backend: direct.unsupported()
    when HasX11:
      x11.setConfig(appName, fileName, content)
    else: direct.unsupported()

  proc openUrl*(url: string) =
    if selected != X11Backend: direct.unsupported()
    when HasX11:
      x11.openUrl(url)
    else: direct.unsupported()

  proc openTempTextFile*(title, text: string) =
    if selected != X11Backend: direct.unsupported()
    when HasX11:
      x11.openTempTextFile(title, text)
    else: direct.unsupported()

  proc openFileDialog*(title = "Open File", filters: seq[FileDialogFilter] = @[], defaultPath = ""): string =
    if selected != X11Backend: direct.unsupported()
    when HasX11:
      return x11.openFileDialog(title, filters, defaultPath)
    else: direct.unsupported()

  proc saveFileDialog*(title = "Save File", filters: seq[FileDialogFilter] = @[], defaultPath = "", defaultName = ""): string =
    if selected != X11Backend: direct.unsupported()
    when HasX11:
      return x11.saveFileDialog(title, filters, defaultPath, defaultName)
    else: direct.unsupported()
