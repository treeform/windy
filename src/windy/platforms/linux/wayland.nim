import ../../common, vmath, wayland/egl, wayland/protocol

type
  OutputInfo = ref object
    pos: IVec2
    mode: IVec2
    scale: int = 1

var outputs: seq[OutputInfo]

var
  initialized: bool

  display: Display
  registry: Registry

  compositor: Compositor
  shm: Shm
  shell: XdgWmBase

  pixelFormats: seq[PixelFormat]

proc init* =
  if initialized: return

  display = connect()
  display.onError:
    raise WindyError.newException("Wayland error for " & $objId.uint32 & ": " &
        $code & ", " & message)

  registry = display.registry

  registry.onGlobal:
    case iface
    of Compositor.iface:
      compositor = registry.bindInterface(Compositor, name, iface, version)

    of Shm.iface:
      shm = registry.bindInterface(Shm, name, iface, version)

      shm.onFormat:
        pixelFormats.add format

    of XdgWmBase.iface:
      shell = registry.bindInterface(XdgWmBase, name, iface, version)

      shell.onPing:
        shell.pong(serial)

    of Output.iface:
      let outputObj = registry.bindInterface(Output, name, iface, min(version, 3))
      var info = OutputInfo()
      outputs.add(info)

      outputObj.onGeometry:
        info.pos = pos

      outputObj.onMode:
        # Prefer the current mode, then preferred, otherwise first advertised.
        if ModeFlag.current in flags:
          info.mode = size
        elif ModeFlag.prefered in flags and info.mode == ivec2(0, 0):
          info.mode = size
        elif info.mode == ivec2(0, 0):
          info.mode = size

      outputObj.onScale:
        if factor > 0:
          info.scale = factor

      outputObj.onDone:
        if info.scale <= 0:
          info.scale = 1

  sync display

  if compositor == nil or shm == nil or shell == nil:
    raise WindyError.newException(
      "Not enough Wayland interfaces, missing: " &
      (if compositor == nil: "wl_compositor " else: "") &
      (if shm == nil: "wl_shm " else: "") &
      (if shell == nil: "xdg_wm_base " else: "")
    )

  sync display

  initEgl()

  initialized = true

proc getScreens*(): seq[common.Screen] =
  ## Enumerate Wayland outputs and return them as Screen records.
  init()
  # Pump events so that output geometry/mode/scale are populated.
  display.sync

  if outputs.len == 0:
    # Fallback: single 1920x1080 primary if no outputs were advertised.
    return @[common.Screen(left: 0, top: 0, right: 1920, bottom: 1080, primary: true)]

  for i, o in outputs:
    let mode = if o.mode == ivec2(0, 0): ivec2(1920, 1080) else: o.mode
    let scale = max(o.scale, 1)
    result.add common.Screen(
      left: o.pos.x,
      top: o.pos.y,
      right: o.pos.x + mode.x * scale,
      bottom: o.pos.y + mode.y * scale,
      primary: i == 0 or (o.pos.x == 0 and o.pos.y == 0)
    )

when isMainModule:
  init()
  let srf = compositor.newSurface
  let ssrf = shell.shellSurface(srf)
  let tl = ssrf.toplevel

  commit srf

  ssrf.onConfigure:
    ssrf.ackConfigure(serial)
    commit srf

  tl.onClose: quit()

  sync display

  let buf = shm.create(ivec2(128, 128), PixelFormat.xrgb8888)
  attach srf, buf.buffer, ivec2(0, 0)
  commit srf

  makeCurrent newOpenglContext()

  # how to draw on window?
  # i tried:
  #   creating context on window (incompatible native window (wl_window vs. protocol.Window))
  #   eglCreateDRMImageMESA/eglExportDRMImageMESA/wl_drm.newBuffer (fails via BadAlloc)
  # in this code works:
  #   setting pixels manually on buf.dataAddr (no OpenGL)

  while true: sync display
