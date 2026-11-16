import
  std/[monotimes, os, sequtils, strutils, tables, times, unicode],
  pixie,
  ../../common,
  ./dbus

type
  NotificationErrorCallback* = proc(message: string)

  NotificationState = enum
    nsPending, nsActive, nsClosing, nsClosed, nsFailed

  NotificationContent = object
    title, body: string
    icon: Image

  Notification* = ref object
    ## A Linux desktop notification. Call pollEvents to send requests and run callbacks.
    state: NotificationState
    content: NotificationContent
    onClick: Callback
    onError: NotificationErrorCallback
    id, serial: uint32
    revision, sentRevision: uint64
    canceled: bool

  RequestKind = enum
    subscribe, capabilities, notify, dismiss

  Request = object
    kind: RequestKind
    notification: Notification
    deadline: MonoTime

const
  Service = "org.freedesktop.Notifications"
  ObjectPath = "/org/freedesktop/Notifications"
  ReplyTimeoutSeconds = 5
  MessageBatchSize = 64

var
  connection: Connection
  owner: string
  serverCapabilities: seq[string]
  ready: bool
  requests: Table[uint32, Request]
  notifications: seq[Notification]
  deliveries: seq[Callback]
  polling: bool

proc notificationWaitTimeout*(timeoutMs: int): int =
  ## Keeps the notification bus responsive while it owns pending callbacks.
  result = timeoutMs
  if connection != nil or requests.len > 0 or deliveries.len > 0:
    result = min(result, 10)
  else:
    for notification in notifications:
      if notification.state notin {nsClosed, nsFailed}:
        return min(result, 10)

proc closed*(notification: Notification): bool =
  ## True after dismissal, expiration, or failure; closing also counts as closed.
  notification == nil or notification.state in {nsClosing, nsClosed, nsFailed}

proc pending*(notification: Notification): bool =
  ## True while sending, updating, or dismissing still needs pollEvents to finish.
  notification != nil and (notification.serial != 0 or
    notification.state in {nsPending, nsClosing} or
    (notification.state == nsActive and notification.revision != notification.sentRevision))

proc content(title, body: string, icon: Image): NotificationContent =
  ## Validates text before libdbus sees it and owns a snapshot of the image.
  for text in [title, body]:
    if '\0' in text or text.validateUtf8() != -1:
      raise newException(WindyError, "Notification text must be UTF-8 without null bytes")
  if icon != nil:
    if icon.width <= 0 or icon.height <= 0 or icon.width > high(int32).int div 4:
      raise newException(WindyError, "A notification image must contain valid pixels")
    result.icon = icon.copy()
  result.title = title
  result.body = body

proc sendNotification*(title, body: string, icon: Image = nil,
    onClick: Callback = nil, onError: NotificationErrorCallback = nil): Notification =
  ## Queues a notification without waiting for the desktop service. Plain text is
  ## used; the optional image is supplied through the standard image-data hint.
  ## Use the thread that calls pollEvents. Invalid input raises immediately.
  ## Click callbacks require desktop action support. Delivery errors call onError,
  ## or raise WindyError from pollEvents when onError is absent.
  ## The desktop controls presentation; acceptance does not guarantee a visible popup.
  ## The application name defaults to the executable name. No tray icon is needed.
  result = Notification(state: nsPending, content: content(title, body, icon), onClick: onClick,
    onError: onError, revision: 1)
  notifications.add result

proc update*(notification: Notification, title, body: string, icon: Image = nil) =
  ## Replaces the content and image while retaining callbacks. Nil clears the image.
  ## Updates before a reply are coalesced. A closed handle cannot be reused.
  if notification.closed:
    raise newException(WindyError, "Cannot update a closed notification")
  notification.content = content(title, body, icon)
  inc notification.revision

proc close*(notification: Notification) =
  ## Queues dismissal, or cancels a request that has not been sent. Safe to repeat.
  if notification == nil: return
  notification.canceled = true
  if notification.closed: return
  if notification.id == 0 and notification.serial == 0:
    notification.state = nsClosed
  else:
    notification.state = nsClosing

proc disconnect() =
  ## Releases this feature's private bus connection without affecting tray icons.
  if connection != nil:
    connectionClose(connection)
    connectionUnref(connection)
    connection = nil
  requests.clear()
  owner = ""
  ready = false
  serverCapabilities = @[]

proc fail(notification: Notification, message: string) =
  ## Queues an error for application-thread dispatch after native messages are freed.
  notification.state = nsFailed
  notification.serial = 0
  notification.id = 0
  let callback = notification.onError
  deliveries.add proc() =
    if callback != nil: callback(message)
    else: raise newException(WindyError, message)

proc failAll(message: string) =
  ## Invalidates IDs after a failed connection or notification-service replacement.
  for notification in notifications:
    if notification.state notin {nsClosed, nsFailed}:
      if notification.canceled:
        notification.state = nsClosed
        notification.serial = 0
        notification.id = 0
      else:
        notification.fail(message)
    notification.serial = 0
    notification.id = 0
  disconnect()

proc request(message: Message, kind: RequestKind, notification: Notification = nil) =
  ## Queues a method call with a deadline; no reply is waited for here.
  let serial = connection.send(message)
  requests[serial] = Request(kind: kind, notification: notification,
    deadline: getMonoTime() + initDuration(seconds = ReplyTimeoutSeconds))
  if notification != nil: notification.serial = serial

proc connect() =
  ## Initializes the private session connection and asynchronously queries capabilities.
  if not loadDbus():
    failAll("Desktop notifications require libdbus-1.so.3")
    return
  connection = busGetPrivate(0, nil)
  if connection == nil:
    failAll("Unable to connect to the session bus for desktop notifications")
    return
  connectionSetExitOnDisconnect(connection, 0)
  for rule in [
    "type='signal',sender='org.freedesktop.DBus',interface='org.freedesktop.DBus',member='NameOwnerChanged',arg0='org.freedesktop.Notifications'",
    "type='signal',sender='org.freedesktop.Notifications',path='/org/freedesktop/Notifications',interface='org.freedesktop.Notifications'"
  ]:
    let message = requireMessage(messageNewMethodCall("org.freedesktop.DBus",
      "/org/freedesktop/DBus", "org.freedesktop.DBus", "AddMatch"))
    var args = message.writer()
    args.addString rule
    request(message, subscribe)
  request(messageNewMethodCall(Service, ObjectPath, Service, "GetCapabilities"), capabilities)

proc imageData(args: var Iter, image: Image) =
  ## Encodes straight-alpha RGBA bytes, including the required stride and format.
  container(args, 'v', "(iiibiiay)", value):
    container(value, 'r', nil, pixels):
      pixels.addInt image.width.int32
      pixels.addInt image.height.int32
      pixels.addInt (image.width * 4).int32
      pixels.addBool true
      pixels.addInt 8
      pixels.addInt 4
      container(pixels, 'a', "y", bytes):
        for pixel in image.data:
          let color = pixel.rgba()
          bytes.addByte color.r
          bytes.addByte color.g
          bytes.addByte color.b
          bytes.addByte color.a

proc drive(notification: Notification) =
  ## Sends the latest desired state once the previous request has completed.
  if not ready or notification.serial != 0: return
  if notification.state == nsClosing:
    if notification.id == 0:
      notification.state = nsClosed
    else:
      let message = requireMessage(messageNewMethodCall(owner.cstring, ObjectPath,
        Service, "CloseNotification"))
      var args = message.writer()
      args.addUint notification.id
      request(message, dismiss, notification)
  elif notification.state in {nsPending, nsActive} and
      notification.revision != notification.sentRevision:
    let message = requireMessage(messageNewMethodCall(owner.cstring, ObjectPath, Service, "Notify"))
    try:
      var args = message.writer()
      let appName = getAppFilename().extractFilename()
      args.addString(if appName.validateUtf8() == -1: appName else: "Windy")
      args.addUint notification.id
      args.addString ""
      args.addString notification.content.title
      let body = notification.content.body
      args.addString(if "body-markup" in serverCapabilities:
        body.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;") else: body)
      container(args, 'a', "s", actions):
        if notification.onClick != nil and "actions" in serverCapabilities:
          actions.addString "default"
          actions.addString "Open"
      container(args, 'a', "{sv}", hints):
        if notification.content.icon != nil:
          container(hints, 'e', nil, entry):
            entry.addString "image-data"
            entry.imageData(notification.content.icon)
      args.addInt -1
      # request() owns the message after successful construction.
    except:
      messageUnref(message)
      raise
    notification.sentRevision = notification.revision
    request(message, notify, notification)

proc methodReply(message: Message, req: Request) =
  ## Validates replies before accepting server IDs or capability data.
  let notification = req.notification
  if notification != nil: notification.serial = 0
  var args = message.reader()
  if messageGetType(message) == 3:
    if req.kind == dismiss and notification.state == nsClosed: return
    let detail = args.stringValue()
    let error = "Desktop notification request failed" &
      (if detail.len > 0: ": " & detail else: "")
    if req.kind in {subscribe, capabilities}: failAll(error)
    else: notification.fail(error)
    return
  case req.kind
  of subscribe:
    if $messageGetSignature(message) != "":
      failAll("Invalid desktop notification subscription reply")
  of capabilities:
    if $messageGetSignature(message) != "as" or not ($messageGetSender(message)).startsWith(":"):
      failAll("Invalid desktop notification capabilities reply")
      return
    owner = $messageGetSender(message)
    var values = args.recurse()
    while messageIterGetArgType(values.addr) == 's'.cint:
      serverCapabilities.add values.stringValue()
      values.next()
    ready = true
  of notify:
    if $messageGetSignature(message) != "u" or args.uintValue() == 0:
      notification.fail("Invalid desktop notification ID reply")
      return
    if notification.state in {nsClosed, nsFailed}:
      notification.state = nsClosing
    notification.id = args.uintValue()
    if notification.state == nsPending: notification.state = nsActive
  of dismiss:
    if $messageGetSignature(message) != "":
      notification.fail("Invalid desktop notification dismissal reply")
    else:
      notification.state = nsClosed
      notification.id = 0

proc signal(message: Message) =
  ## Accepts lifecycle and action events only from the current service owner.
  let
    iface = $messageGetInterface(message)
    member = $messageGetMember(message)
    sender = $messageGetSender(message)
    signature = $messageGetSignature(message)
  var args = message.reader()
  if iface == "org.freedesktop.DBus" and member == "NameOwnerChanged" and
      sender == "org.freedesktop.DBus" and signature == "sss" and
      args.stringValue() == Service:
    args.next()
    if owner.len > 0 and args.stringValue() == owner:
      failAll("Desktop notification service stopped or restarted")
    return
  if sender != owner or iface != Service or $messageGetPath(message) != ObjectPath:
    return
  if member notin ["ActionInvoked", "NotificationClosed"]: return
  if (member == "ActionInvoked" and signature != "us") or
      (member == "NotificationClosed" and signature != "uu"):
    return
  let id = args.uintValue()
  if id == 0: return
  args.next()
  for notification in notifications:
    if notification.id != id or notification.state in {nsClosed, nsFailed}: continue
    if member == "ActionInvoked" and args.stringValue() == "default" and
        not notification.canceled and notification.onClick != nil:
      let
        target = notification
        callback = notification.onClick
      deliveries.add proc() =
        if not target.canceled: callback()
    elif member == "NotificationClosed":
      if notification.serial != 0 and requests.hasKey(notification.serial) and
          requests[notification.serial].kind == notify:
        # A pending update must not resurrect a notification dismissed by its user.
        notification.state = nsClosing
      else:
        notification.state = nsClosed
        notification.id = 0

proc pollNotificationEvents*() =
  ## Pumps notification requests without waiting for service replies; dispatches callbacks.
  if polling: return
  polling = true
  defer: polling = false
  notifications.keepItIf(it.state notin {nsClosed, nsFailed} or it.serial != 0)
  if connection != nil or notifications.len > 0 or requests.len > 0:
    try:
      if connection == nil: connect()
      if connection != nil:
        if connectionReadWrite(connection, 0) == 0:
          failAll("Desktop notification session bus disconnected")
        else:
          for unused in 0..<MessageBatchSize:
            let message = connectionPopMessage(connection)
            if message == nil: break
            try:
              let serial = messageGetReplySerial(message)
              if messageGetType(message) in [2.cint, 3.cint] and requests.hasKey(serial):
                let req = requests[serial]
                let sender = $messageGetSender(message)
                let expectedSender =
                  if req.kind == subscribe: sender == "org.freedesktop.DBus"
                  elif req.kind == capabilities: true
                  else: sender == owner or
                    (messageGetType(message) == 3 and sender == "org.freedesktop.DBus")
                if expectedSender:
                  requests.del(serial)
                  methodReply(message, req)
              elif messageGetType(message) == 4:
                signal(message)
            finally:
              messageUnref(message)
            if connection == nil: break
          var expired: seq[uint32]
          for serial, req in requests:
            if getMonoTime() >= req.deadline: expired.add serial
          for serial in expired:
            if not requests.hasKey(serial): continue
            let req = requests[serial]
            requests.del(serial)
            if req.kind in {subscribe, capabilities}:
              failAll("Desktop notification capability request timed out")
              break
            else:
              # Do not keep IDs or retry requests after their outcome becomes unknown.
              failAll("Desktop notification request timed out")
              break
          for notification in notifications:
            notification.drive()
    except CatchableError:
      failAll(getCurrentExceptionMsg())
  for unused in 0..<MessageBatchSize:
    if deliveries.len == 0: break
    let callback = deliveries[0]
    deliveries.delete(0)
    callback()
