import std/[os, posix], lindefs, ../../[common, internal]

# NOTE udev gets us userspace devices for initial discovery and hotplug events.
#
# Beyond that, there are 3 different ways to get device events on linux:
# 1. the joystick subsystem, it's deprecated and we don't use it.
# 2. the evdev subsystem, with standardized names at the kernel level.
# 3. the hidraw subsystem, needing to parse raw vendor frames, but supporting features beyond axes and buttons.
#
# We only use the evdev subsystem as of now.

var
  epoll: cint
  udev: ptr udev
  udevMonitor: ptr udev_monitor
  udevMonitorFd: cint
  devices: array[maxGamepads, ptr libevdev]
  devicePaths: array[maxGamepads, cstring]
  deviceAbsInfo: array[maxGamepads, array[6, ptr input_absinfo]]
  gamepadStates: array[maxGamepads, GamepadState]
  defaultAbsInfo: input_absinfo = input_absinfo(minimum: -32768, maximum: 32767)

gamepadPlatform()

proc gamepadConnected*(gamepadId: int): bool =
  devices[gamepadId] != nil

proc gamepadResetAbsInfo*(gamepadId: int) =
  for j in 0..<6:
    deviceAbsInfo[gamepadId][j] = addr defaultAbsInfo

proc strncmp(a: cstring, b: cstring, n: cint): cint {.importc, header: "<string.h>".}

proc gamepadEvent(device: ptr udev_device, added: bool) =
  # Final filtering and registration of gamepad devices,
  # silently treating open errors as unavailable devices.
  # The rare possible cases of failure, beyond code errors, are dire conditions like out of memory.
  let devnode = udev_device_get_devnode(device)
  if devnode != nil and strncmp(devnode, "/dev/input/event", 16) == 0:
    let syspath = udev_device_get_syspath(device)
    if added:
      for i in 0..<maxGamepads:
        if devices[i] == nil:
          let fd = open(devnode, O_RDONLY or O_NONBLOCK)
          if fd < 0:
            return

          var device: ptr libevdev
          if libevdev_new_from_fd(fd, addr device) != 0:
            discard close(fd)
            return

          var ev = epoll_event(events: EPOLLIN, data: epoll_data_t(u32: uint32 i))
          if epoll_ctl(epoll, EPOLL_CTL_ADD, fd, addr ev) != 0:
            libevdev_free(device)
            discard close(fd)
            return

          devices[i] = device
          devicePaths[i] = syspath
          gamepadStates[i].name = $libevdev_get_name(device)

          # Cache the absolute info for the supported device axes,
          # handling odd cases where faulty drivers report broken ranges to prevent division by zero.
          for j in 0..<6:
            if not libevdev_has_event_code(device, EV_ABS, uint16 j):
              continue # Device says it doesn't report this axis code.

            let info = libevdev_get_abs_info(device, uint16 j)
            if info != nil and info.maximum > info.minimum:
              deviceAbsInfo[i][j] = info

          if onGamepadConnected != nil: onGamepadConnected(i)
          break
    else:
      for i in 0..<maxGamepads:
        if devicePaths[i] == syspath:
          gamepadResetAbsInfo(i)

          let fd = libevdev_get_fd(devices[i])
          discard epoll_ctl(epoll, EPOLL_CTL_DEL, fd, nil)
          libevdev_free(devices[i])
          discard close(fd)

          devices[i] = nil
          devicePaths[i] = nil
          gamepadResetState(gamepadStates[i])

          if onGamepadDisconnected != nil: onGamepadDisconnected(i)
          break

proc gamepadSetup() =
  for i in 0..<maxGamepads:
    gamepadResetAbsInfo(i)

  epoll = epoll_create1(O_CLOEXEC)
  if epoll < 0: raiseOSError(osLastError())
  
  udev = udev_new()
  if udev == nil: raiseOSError(osLastError())

  # Setup a udev monitor to listen for hotplug events.
  udevMonitor = udev_monitor_new_from_netlink(udev, "udev")
  if udev_monitor == nil: raiseOSError(osLastError())
  discard udev_monitor_filter_add_match_subsystem_devtype(udevMonitor, "input", nil)
  discard udev_monitor_enable_receiving(udevMonitor)

  udevMonitorFd = udev_monitor_get_fd(udevMonitor)
  let fl = fcntl(udevMonitorFd, F_GETFL)
  if fl < 0: raiseOSError(osLastError())
  discard fcntl(udevMonitorFd, F_SETFL, fl or O_NONBLOCK)

  var ev = epoll_event(events: EPOLLIN, data: epoll_data_t(u32: 0xFFFFFFFF'u32))
  let rc = epoll_ctl(epoll, EPOLL_CTL_ADD, udevMonitorFd, addr ev)
  if rc < 0: raiseOSError(osLastError())

  # Enumerate gamepads already connected.
  let enumerate = udev_enumerate_new(udev)
  discard udev_enumerate_add_match_subsystem(enumerate, "input")
  discard udev_enumerate_add_match_property(enumerate, "ID_INPUT_JOYSTICK", "1") # Matches every input device otherwise.
  discard udev_enumerate_scan_devices(enumerate)
  var entry: ptr udev_list_entry
  udev_list_entry_foreach(udev_enumerate_get_list_entry(enumerate)):
    let name = udev_list_entry_get_name(entry)
    let device = udev_device_new_from_syspath(udev, name)
    gamepadEvent(device, true)
    discard udev_device_unref(device)
  discard udev_enumerate_unref(enumerate)

proc gamepadPoll() =
  for i in 0..<maxGamepads:
    let state = addr gamepadStates[i]
    state.pressed = 0
    state.released = 0

  const maxEvents = maxGamepads + 1
  var events: array[maxEvents, epoll_event]
  var event: input_event
  let n = epoll_wait(epoll, addr events[0], maxEvents, 0)
  for i in 0..<n:
    # Ignore ERR and HUP events. These are always returned by epoll_wait.
    if (events[i].events and EPOLLIN) == 0:
      continue

    # Hotplug events use an invalid gamepad index.
    let index = events[i].data.u32
    if index == 0xFFFFFFFF'u32:
      let device = udev_monitor_receive_device(udevMonitor)
      let action = udev_device_get_action(device)
      if action != nil and udev_device_get_property_value(device, "ID_INPUT_JOYSTICK") == "1":
        if action == "add": gamepadEvent(device, true)
        elif action == "remove": gamepadEvent(device, false)
      discard udev_device_unref(device)
    # Gamepad events are read until there are none left for the device.
    else:
      let device = devices[index]
      assert device != nil
      let state = addr gamepadStates[index]
      var buttons = state.buttons
      template btn(value: bool, id: GamepadButton) =
        let bit = uint32 1 shl id.int
        if value: buttons = buttons or bit
        else: buttons = buttons and (not bit)
      var readFlag: cint = LIBEVDEV_READ_FLAG_NORMAL
      while true:
        case libevdev_next_event(device, readFlag, addr event)
        # libev caught a SYN_DROPPED event, switch to sync mode.
        of LIBEVDEV_READ_STATUS_SYNC:
          readFlag = LIBEVDEV_READ_FLAG_SYNC
        # done reading the device snapshot, resume after sync.
        of -EAGAIN:
          if readFlag == LIBEVDEV_READ_FLAG_SYNC:
            readFlag = LIBEVDEV_READ_FLAG_NORMAL
          else: break
        # reading the device normally.
        else: discard

        # Translate the event into gamepad state.
        case event.`type`
        of EV_KEY: btn(event.value != 0, case event.code
          of BTN_A: GamepadA
          of BTN_B: GamepadB
          of BTN_X: GamepadY
          of BTN_Y: GamepadX
          of BTN_TL: GamepadL1
          of BTN_TR: GamepadR1
          of BTN_TL2: GamepadL2
          of BTN_TR2: GamepadR2
          of BTN_SELECT: GamepadSelect
          of BTN_START: GamepadStart
          of BTN_MODE: GamepadHome
          of BTN_THUMBL: GamepadL3
          of BTN_THUMBR: GamepadR3
          else: continue)
        of EV_ABS:
          template axis(): float32 =
            let abs = deviceAbsInfo[index][event.code]
            let norm = 2.0 * float32(event.value - abs.minimum) / float32(abs.maximum - abs.minimum) - 1.0
            gamepadFilterDeadZone(norm)
          template pressure(id: GamepadButton) =
            state.pressures[id.int] = axis()
            btn(event.value != 0, id)
          template dpad(neg: GamepadButton, pos: GamepadButton) =
            btn(event.value < 0, neg)
            btn(event.value > 0, pos)
          case event.code
            of ABS_X: state.axes[GamepadLStickX.int] = axis()
            of ABS_Y: state.axes[GamepadLStickY.int] = axis()
            of ABS_RX: state.axes[GamepadRStickX.int] = axis()
            of ABS_RY: state.axes[GamepadRStickY.int] = axis()
            of ABS_Z: pressure(GamepadL2)
            of ABS_RZ: pressure(GamepadR2)
            of ABS_HAT0X: dpad(GamepadLeft, GamepadRight)
            of ABS_HAT0Y: dpad(GamepadUp, GamepadDown)
            else: discard
        else: discard
      gamepadUpdateButtons()
