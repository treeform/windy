import ../../common, ../../internal
import wayland/protocol

var
  initialized: bool

  display: Display
  registry: Registry

  compositor: Compositor
  shm: Shm
  shell: XdgWmBase

  shmFormats: seq[ShmFormat]


proc init* =
  if initialized: return

  display = connect()
  display.onError:
    raise WindyError.newException("Wayland error for " & $objId.uint32 & ": " & $code & ", " & message)
  
  registry = display.registry

  registry.onGlobal:
    case iface
    of "wl_compositor":
      compositor = registry.bindInterface(Compositor, name, iface, version)
    
    of "wl_shm":
      shm = registry.bindInterface(Shm, name, iface, version)

      shm.onFormat:
        shmFormats.add format
    
    of "xdg_wm_base":
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

  initialized = true
