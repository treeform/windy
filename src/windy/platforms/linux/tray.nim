import
  std/unicode,
  pixie,
  ../../common,
  ./backends,
  ./tray/[state, sni]

when HasX11:
  import ./tray/xembed

type
  TrayBackend = enum
    noTray, sniTray, xembedTray

var
  requested: TrayState
  busTray: SniTray
  backend: TrayBackend
  revision: uint32
  nextMenuId = 1.int32

when HasX11:
  var plugTray: XembedTray

proc hideTrayIcon*() =
  ## Removes the Linux tray icon and cancels pending registration. Safe to repeat.
  requested = nil
  backend = noTray
  busTray.close()
  when HasX11:
    plugTray.close()
    plugTray = nil
  busTray = nil

proc showTrayIcon*(icon: Image, tooltip: string, onClick: Callback,
    menu: seq[TrayMenuEntry] = @[]) =
  ## Shows or replaces one tray icon. Call pollEvents to process tray interaction.
  ## Waits for a tray host when none is present; prefers SNI, then XEmbed.
  ## Labels are literal UTF-8. SNI hosts determine how activation is presented.
  if icon == nil or icon.width <= 0 or icon.height <= 0:
    raise newException(WindyError, "A tray icon must contain pixels")
  if '\0' in tooltip or tooltip.validateUtf8() != -1:
    raise newException(WindyError, "A tray tooltip must be UTF-8 without null bytes")
  for entry in menu:
    if entry.kind == TrayMenuOption and
        ('\0' in entry.text or entry.text.validateUtf8() != -1):
      raise newException(WindyError, "A tray menu label must be UTF-8 without null bytes")
  if menu.len > (high(int32) - nextMenuId).int:
    raise newException(WindyError, "Tray menu IDs exhausted")
  inc revision
  let state = TrayState(icon: icon.copy(), tooltip: tooltip,
    onClick: onClick, revision: revision, firstMenuId: nextMenuId)
  nextMenuId += menu.len.int32
  # Own the sequence so later application edits cannot change a published menu.
  for entry in menu: state.menu.add entry
  if requested == nil:
    requested = state
    try:
      busTray = newSniTray(state)
      when HasX11:
        plugTray = newXembedTray(state)
    except:
      hideTrayIcon()
      raise
  else:
    requested = state
    busTray.update(state)
    when HasX11:
      plugTray.update(state)

proc pollTrayEvents*() =
  ## Pumps both host monitors and dispatches callbacks for the current snapshot.
  if requested == nil: return
  let snapshot = requested
  var callbacks = busTray.poll()
  when HasX11:
    callbacks.add plugTray.poll()
  if backend == sniTray and not busTray.hostAvailable and not busTray.selecting:
    # Closing the connection unregisters even if the watcher itself still exists.
    let failedOwner = busTray.failedOwner
    busTray.close()
    busTray = newSniTray(requested, failedOwner)
    backend = noTray
  when HasX11:
    if backend == xembedTray and not plugTray.available:
      plugTray.setActive(false)
      backend = noTray
  if backend == noTray:
    if busTray.hostAvailable:
      backend = sniTray
      busTray.setActive(true)
    elif not busTray.selecting:
      when HasX11:
        if plugTray.available:
          backend = xembedTray
          plugTray.setActive(true)
  elif backend == sniTray:
    busTray.setActive(true)
  when HasX11:
    if backend == xembedTray:
      # Redock if the manager retained ownership but recreated the plug.
      plugTray.setActive(true)
  for callback in callbacks:
    if requested != snapshot: break
    callback()
