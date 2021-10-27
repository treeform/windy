import wayland/protocol

let display = connect()
display.onError:
  echo "Error for ", objId.uint32, ": ", code, ", ", message

let reg = display.registry
var compositor: Compositor

reg.onGlobal:
  echo (id: name.uint32, iface: iface, version: version)
  case iface
  of "wl_compositor":
    compositor = reg.bindInterface(Compositor, name, iface, version)

sync display
