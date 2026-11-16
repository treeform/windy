import
  pixie,
  ../../../common

type
  TrayState* = ref object
    ## One immutable snapshot shared by the selected tray backend.
    icon*: Image
    tooltip*: string
    onClick*: Callback
    menu*: seq[TrayMenuEntry]
    revision*: uint32
    firstMenuId*: int32

proc menuCallback*(state: TrayState, id: int32): Callback =
  ## Returns the action for a valid option ID, ignoring roots and separators.
  if id > 0 and id <= state.menu.len and
      state.menu[id - 1].kind == TrayMenuOption:
    result = state.menu[id - 1].onClick
