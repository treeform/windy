{.passL: "-ludev -levdev."}

# <sys/epoll.h>
type
  epoll_data_t* {.union.} = object
    `ptr`*: pointer
    fd*: cint
    u32*: uint32
    u64*: uint64
  epoll_event* = object
    events*: uint32
    data*: epoll_data_t

const
  EPOLL_CTL_ADD* = 1
  EPOLL_CTL_DEL* = 2
  EPOLL_CTL_MOD* = 3
  EPOLLIN* = 0x001

{.push importc, cdecl.}

proc epoll_create1*(flags: cint): cint
proc epoll_ctl*(epfd: cint, op: cint, fd: cint, event: ptr epoll_event): cint
proc epoll_wait*(epfd: cint, events: ptr epoll_event, maxevents: cint, timeout: cint): cint

# <libudev.h>
type
  dev_t* = uint64

  udev* = object
  udev_list_entry* = object
  udev_device* = object
  udev_monitor* = object
  udev_enumerate* = object

proc udev_ref*(udev: ptr udev): ptr udev
proc udev_unref*(udev: ptr udev): ptr udev
proc udev_new*(): ptr udev

proc udev_list_entry_get_next*(list_entry: ptr udev_list_entry): ptr udev_list_entry
proc udev_list_entry_get_by_name*(list_entry: ptr udev_list_entry, name: cstring): ptr udev_list_entry
proc udev_list_entry_get_name*(list_entry: ptr udev_list_entry): cstring
proc udev_list_entry_get_value*(list_entry: ptr udev_list_entry): cstring

template udev_list_entry_foreach*(first_entry: ptr udev_list_entry, body: untyped) =
  entry = first_entry
  while entry != nil:
    body
    entry = udev_list_entry_get_next(entry)

proc udev_device_ref*(udev_device: ptr udev_device): ptr udev_device
proc udev_device_unref*(udev_device: ptr udev_device): ptr udev_device
proc udev_device_get_udev*(udev_device: ptr udev_device): ptr udev
proc udev_device_new_from_syspath*(udev: ptr udev, syspath: cstring): ptr udev_device
proc udev_device_new_from_devnum*(udev: ptr udev, `type`: cchar, devnum: dev_t): ptr udev_device
proc udev_device_new_from_subsystem_sysname*(udev: ptr udev, subsystem: cstring, sysname: cstring): ptr udev_device
proc udev_device_new_from_device_id*(udev: ptr udev, id: cstring): ptr udev_device
proc udev_device_new_from_environment*(udev: ptr udev): ptr udev_device
proc udev_device_get_parent*(udev_device: ptr udev_device): ptr udev_device
proc udev_device_get_parent_with_subsystem_devtype*(udev_device: ptr udev_device, subsystem: cstring, devtype: cstring): ptr udev_device
proc udev_device_get_devpath*(udev_device: ptr udev_device): cstring
proc udev_device_get_subsystem*(udev_device: ptr udev_device): cstring
proc udev_device_get_devtype*(udev_device: ptr udev_device): cstring
proc udev_device_get_syspath*(udev_device: ptr udev_device): cstring
proc udev_device_get_sysname*(udev_device: ptr udev_device): cstring
proc udev_device_get_sysnum*(udev_device: ptr udev_device): cstring
proc udev_device_get_devnode*(udev_device: ptr udev_device): cstring
proc udev_device_get_is_initialized*(udev_device: ptr udev_device): cint
proc udev_device_get_devlinks_list_entry*(udev_device: ptr udev_device): ptr udev_list_entry
proc udev_device_get_properties_list_entry*(udev_device: ptr udev_device): ptr udev_list_entry
proc udev_device_get_tags_list_entry*(udev_device: ptr udev_device): ptr udev_list_entry
proc udev_device_get_current_tags_list_entry*(udev_device: ptr udev_device): ptr udev_list_entry
proc udev_device_get_sysattr_list_entry*(udev_device: ptr udev_device): ptr udev_list_entry
proc udev_device_get_property_value*(udev_device: ptr udev_device, key: cstring): cstring
proc udev_device_get_driver*(udev_device: ptr udev_device): cstring
proc udev_device_get_devnum*(udev_device: ptr udev_device): dev_t
proc udev_device_get_action*(udev_device: ptr udev_device): cstring
proc udev_device_get_seqnum*(udev_device: ptr udev_device): culong
proc udev_device_get_usec_since_initialized*(udev_device: ptr udev_device): culong
proc udev_device_get_sysattr_value*(udev_device: ptr udev_device, sysattr: cstring): cstring
proc udev_device_set_sysattr_value*(udev_device: ptr udev_device, sysattr: cstring, value: cstring): cint
proc udev_device_has_tag*(udev_device: ptr udev_device, tag: cstring): cint
proc udev_device_has_current_tag*(udev_device: ptr udev_device, tag: cstring): cint

proc udev_monitor_ref*(udev_monitor: ptr udev_monitor): ptr udev_monitor
proc udev_monitor_unref*(udev_monitor: ptr udev_monitor): ptr udev_monitor
proc udev_monitor_get_udev*(udev_monitor: ptr udev_monitor): ptr udev
proc udev_monitor_new_from_netlink*(udev: ptr udev, name: cstring): ptr udev_monitor
proc udev_monitor_enable_receiving*(udev_monitor: ptr udev_monitor): cint
proc udev_monitor_set_receive_buffer_size*(udev_monitor: ptr udev_monitor, size: cint): cint
proc udev_monitor_get_fd*(udev_monitor: ptr udev_monitor): cint
proc udev_monitor_receive_device*(udev_monitor: ptr udev_monitor): ptr udev_device
proc udev_monitor_filter_add_match_subsystem_devtype*(udev_monitor: ptr udev_monitor, subsystem: cstring, devtype: cstring): cint
proc udev_monitor_filter_add_match_tag*(udev_monitor: ptr udev_monitor, tag: cstring): cint
proc udev_monitor_filter_update*(udev_monitor: ptr udev_monitor): cint
proc udev_monitor_filter_remove*(udev_monitor: ptr udev_monitor): cint

proc udev_enumerate_ref*(udev_enumerate: ptr udev_enumerate): ptr udev_enumerate
proc udev_enumerate_unref*(udev_enumerate: ptr udev_enumerate): ptr udev_enumerate
proc udev_enumerate_get_udev*(udev_enumerate: ptr udev_enumerate): ptr udev
proc udev_enumerate_new*(udev: ptr udev): ptr udev_enumerate
proc udev_enumerate_add_match_subsystem*(udev_enumerate: ptr udev_enumerate, subsystem: cstring): cint
proc udev_enumerate_add_match_sysname*(udev_enumerate: ptr udev_enumerate, sysname: cstring): cint
proc udev_enumerate_add_match_property*(udev_enumerate: ptr udev_enumerate, property: cstring, value: cstring): cint
proc udev_enumerate_add_match_tag*(udev_enumerate: ptr udev_enumerate, tag: cstring): cint
proc udev_enumerate_add_match_parent*(udev_enumerate: ptr udev_enumerate, parent: ptr udev_device): cint
proc udev_enumerate_add_match_is_initialized*(udev_enumerate: ptr udev_enumerate): cint
proc udev_enumerate_add_syspath*(udev_enumerate: ptr udev_enumerate, syspath: cstring): cint
proc udev_enumerate_scan_devices*(udev_enumerate: ptr udev_enumerate): cint
proc udev_enumerate_scan_subsystems*(udev_enumerate: ptr udev_enumerate): cint
proc udev_enumerate_get_list_entry*(udev_enumerate: ptr udev_enumerate): ptr udev_list_entry

# <sys/time.h>
type
  timeval* = object
    tv_sec*: clong
    tv_usec*: clong

# <linux/input.h>
type
  input_event* = object
    time*: timeval
    `type`*: uint16
    code*: uint16
    value*: int32
  input_absinfo* = object
    value*: int32
    minimum*: int32
    maximum*: int32
    fuzz*: int32
    flat*: int32
    resolution*: int32

# <linux/input-event-codes.h>
const
  EV_SYN* = 0
  EV_KEY* = 1
  EV_ABS* = 3

  SYN_DROPPED* = 3

  BTN_A* = 0x130
  BTN_B* = 0x131
  BTN_C* = 0x132
  BTN_X* = 0x133
  BTN_Y* = 0x134
  BTN_Z* = 0x135
  BTN_TL* = 0x136
  BTN_TR* = 0x137
  BTN_TL2* = 0x138
  BTN_TR2* = 0x139
  BTN_SELECT* = 0x13a
  BTN_START* = 0x13b
  BTN_MODE* = 0x13c
  BTN_THUMBL* = 0x13d
  BTN_THUMBR* = 0x13e

  ABS_X* = 0x00
  ABS_Y* = 0x01
  ABS_Z* = 0x02
  ABS_RX* = 0x03
  ABS_RY* = 0x04
  ABS_RZ* = 0x05
  ABS_THROTTLE* = 0x06
  ABS_RUDDER* = 0x07
  ABS_WHEEL* = 0x08
  ABS_GAS* = 0x09
  ABS_BRAKE* = 0x0a
  ABS_HAT0X* = 0x10
  ABS_HAT0Y* = 0x11
  ABS_HAT1X* = 0x12
  ABS_HAT1Y* = 0x13
  ABS_HAT2X* = 0x14
  ABS_HAT2Y* = 0x15
  ABS_HAT3X* = 0x16
  ABS_HAT3Y* = 0x17
  ABS_PRESSURE* = 0x18
  ABS_DISTANCE* = 0x19
  ABS_TILT_X* = 0x1a
  ABS_TILT_Y* = 0x1b
  ABS_TOOL_WIDTH* = 0x1c

  ABS_VOLUME* = 0x20
  ABS_PROFILE* = 0x21

  ABS_MISC* = 0x28

# <libevdev-1.0/libevdev/libevdev.h>
type
  libevdev* = object

const
  LIBEVDEV_READ_FLAG_SYNC* = 1
  LIBEVDEV_READ_FLAG_NORMAL* = 2
  LIBEVDEV_READ_STATUS_SYNC* = -1

proc libevdev_new_from_fd*(fd: cint, dev: ptr ptr libevdev): cint
proc libevdev_free*(dev: ptr libevdev)
proc libevdev_get_fd*(dev: ptr libevdev): cint
proc libevdev_get_name*(dev: ptr libevdev): cstring
proc libevdev_get_phys*(dev: ptr libevdev): cstring
proc libevdev_get_uniq*(dev: ptr libevdev): cstring
proc libevdev_get_id_product*(dev: ptr libevdev): cint
proc libevdev_get_id_vendor*(dev: ptr libevdev): cint
proc libevdev_get_id_bustype*(dev: ptr libevdev): cint
proc libevdev_get_id_version*(dev: ptr libevdev): cint
proc libevdev_has_event_code*(dev: ptr libevdev, `type`: uint16, code: uint16): bool
proc libevdev_get_abs_info*(dev: ptr libevdev, code: uint16): ptr input_absinfo
proc libevdev_next_event*(dev: ptr libevdev, flags: cint, event: ptr input_event): cint

{.pop.}
