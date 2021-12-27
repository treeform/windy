import vmath, opengl
import ../../common, ../../internal
import wayland/[protocol, sharedBuffer, egl]

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
    raise WindyError.newException("Wayland error for " & $objId.uint32 & ": " & $code & ", " & message)
  
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

  loadExtensions()

  var fbo: uint32
  glGenFramebuffers(1, fbo.addr)

  while true: sync display
