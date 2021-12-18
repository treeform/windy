include basic
import macros, strformat, sequtils, vmath, options, unicode

proc unshl(x: int): int =
  var x = x
  while (x and 1) == 0:
    inc result
    x = x shr 1

proc toBitfield(x: Option[enum]): int =
  if x.isNone: 0
  else: 1 shl x.get.int
proc fromBitfield(x: int, t: type[Option]): t =
  type T = t.T
  if x == 0: none T
  else: some x.unshl.T

macro protocol(body) =
  proc injectAllParams(x: NimNode): NimNode =
    result = nnkFormalParams.newTree(
      @[x[0]] &
      x[1..^1].mapit(newIdentDefs(nnkPragmaExpr.newTree(it[0], nnkPragma.newTree(ident"inject")), it[1], it[2]))
    )
  
  proc separateParams(x: NimNode): tuple[p, t: seq[NimNode]] =
    (x[1..^1].mapit(it[0..^3]).concat, x[1..^1].mapit(it[^2].repeat(it.len - 2)).concat)
  
  proc applyBitfield(p, t: seq[NimNode], reverse = false): tuple[p, t: seq[NimNode]] =
    zip(p, t).mapit(
      if it[1].kind == nnkCommand and it[1][0] == ident"bitField":
        if reverse: (newCall(ident"fromBitfield", it[0], it[1][1]), ident"int")
        else: (newCall(ident"toBitfield", it[0]), it[1][1])
      else: it
    ).unzip
  
  proc prepareArgs(x: NimNode, reverse = false): tuple[p, t, pc: seq[NimNode]] =
    let (p, t) = x.separateParams
    let (pc, t2) = applyBitfield(p, t, reverse)
    (p, t2, pc)
  
  proc prepareParams(x: NimNode): NimNode =
    let (p, t) = x.separateParams
    let (_, t2) = applyBitfield(p, t)
    nnkFormalParams.newTree(@[x[0]] & zip(p, t2).mapit(newIdentDefs(it[0], it[1])))


  result = newStmtList()
  var types: seq[seq[NimNode]]

  for x in body:
    let t = x[0]
    types.add @[t]
    var unms = nnkCaseStmt.newTree(ident"op")
    var i = 0

    for a in x[1]:
      if a.kind == nnkCommand and a[0] == ident"iface":
        continue #TODO: auto iface require

      let p = a.params

      if p[0] == ident"event":
        p[0] = newEmptyNode()
        types[^1].add nnkIdentDefs.newTree( # field declaration
          nnkPostfix.newTree(ident"*", a.name),
          nnkProcTy.newTree(
            p.prepareParams,
            newEmptyNode()
          ),
          newEmptyNode()
        )
        result.add nnkTemplateDef.newTree( # x.onEvent:... template
          nnkPostfix.newTree(ident"*", ident &"on{($a.name).runeAt(0).toUpper}{($a.name).toRunes[1..^1]}"),
          newEmptyNode(),
          newEmptyNode(),
          nnkFormalParams.newTree(
            newEmptyNode(),
            newIdentDefs(ident"x", t),
            newIdentDefs(ident"body", newEmptyNode())
          ),
          newEmptyNode(),
          newEmptyNode(),
          nnkStmtList.newTree(
            nnkAsgn.newTree(
              nnkDotExpr.newTree(
                ident"x",
                a.name
              ),
              nnkLambda.newTree(
                newEmptyNode(),
                newEmptyNode(),
                newEmptyNode(),
                p.prepareParams.injectAllParams,
                newEmptyNode(),
                newEmptyNode(),
                nnkStmtList.newTree(
                  ident"body"
                )
              )
            )
          )
        )
        unms.add nnkOfBranch.newTree( # unmarshaling
          newLit unms.len - 1,
          nnkIfStmt.newTree(nnkElifBranch.newTree(
            nnkInfix.newTree(ident"!=", nnkDotExpr.newTree(ident"this", a.name), newNilLit()),
            block:
              let (args, types, argvals) = p.prepareArgs(true)
              newStmtList(
                (if args.len > 0: @[nnkLetSection.newTree(nnkVarTuple.newTree(
                  args &
                  @[newEmptyNode()] &
                  @[nnkCall.newTree(ident"deserialize",
                    nnkDotExpr.newTree(ident"this", ident"display"),
                    ident"data",
                    nnkTupleConstr.newTree(types)
                  )]
                ))] else: newSeq[NimNode]()) &
                @[nnkCall.newTree(
                  @[nnkDotExpr.newTree(ident"this", a.name)] &
                  argvals
                )]
              )
          ))
        )
      else: # marshaling
        let (_, _, argvals) = p.prepareArgs
        p.insert 1, newIdentDefs(ident"this", t)
        a[0] = nnkPostfix.newTree(ident"*", a[0])
        a.params = p.prepareParams
        a.body = nnkCall.newTree(
          @[nnkDotExpr.newTree(ident"this", ident"marshal"), newLit i] &
          @[nnkTupleConstr.newTree(
            if p[0].kind == nnkEmpty: argvals
            else: @[nnkDotExpr.newTree(ident"result", ident"id")] & argvals
          )]
        )
        if p[0].kind != nnkEmpty:
          a.body = newStmtList(
            nnkAsgn.newTree(
              ident"result",
              newCall(ident"new",
                @[nnkDotExpr.newTree(ident"this", ident"display")] &
                @[p[0]]
              )
            ),
            a.body
          )
        if $a.name == "destroy":
          a.body = newStmtList(
            a.body,
            newCall(ident"destroy", nnkDotExpr.newTree(ident"this", ident"Proxy"))
          )
        result.add a
        inc i
    
    unms.add nnkElse.newTree(
      nnkDiscardStmt.newTree(newEmptyNode())
    )
    result.add quote do:
      method unmarshal(this {.inject.}: `t`, op {.inject.}: int, data {.inject.}: seq[uint32]) {.locks: "unknown".} =
        `unms`
  
  result.insert 0, nnkTypeSection.newTree( # type declaration
    types.filterit($it[0] != "Display").mapit( # do not redefine Display
      nnkTypeDef.newTree(
        nnkPostfix.newTree(ident"*", it[0]),
        newEmptyNode(),
        nnkRefTy.newTree(nnkObjectTy.newTree(
          newEmptyNode(),
          nnkOfInherit.newTree(ident"Proxy"),
          nnkRecList.newTree(it[1..^1])
        ))
      )
    )
  )


type
  ShmFormat* {.pure.} = enum
    argb8888 = 0
    xrgb8888 = 1
    c8 = 0x20203843
    
    bgra1010102 = 0x30334142
    rgba1010102 = 0x30334152
    abgr2101010 = 0x30334241
    xbgr2101010 = 0x30334258
    argb2101010 = 0x30335241
    xrgb2101010 = 0x30335258
    bgrx1010102 = 0x30335842
    rgbx1010102 = 0x30335852

    yuv411 = 0x31315559
    yvu411 = 0x31315659

    nv21 = 0x3132564e
    nv61 = 0x3136564e
    
    bgra4444 = 0x32314142
    rgba4444 = 0x32314152
    abgr4444 = 0x32314241
    xbgr4444 = 0x32314258
    argb4444 = 0x32315241
    xrgb4444 = 0x32315258

    yuv420 = 0x32315559
    nv12 = 0x3231564e
    yvu420 = 0x32315659
    
    bgrx4444 = 0x32315842
    rgbx4444 = 0x32315852

    bgra8888 = 0x34324142
    rgba8888 = 0x34324152
    abgr8888 = 0x34324241
    xbgr8888 = 0x34324258
    
    bgr888 = 0x34324742
    rgb888 = 0x34324752
    
    yuv444 = 0x34325559
    yvu444 = 0x34325659

    bgrx8888 = 0x34325842
    rgbx8888 = 0x34325852

    bgra5551 = 0x35314142
    rgba5551 = 0x35314152
    abgr1555 = 0x35314241
    xbgr1555 = 0x35314258
    argb1555 = 0x35315241
    xrgb1555 = 0x35315258
    bgrx5551 = 0x35315842
    rgbx5551 = 0x35315852
    
    bgr565 = 0x36314742
    rgb565 = 0x36314752

    yuv422 = 0x36315559
    nv16 = 0x3631564e
    yvu422 = 0x36315659

    rgb332 = 0x38424752
    bgr233 = 0x38524742
    
    yvu410 = 0x39555659
    yuv410 = 0x39565559
    
    yvyu = 0x55595659
    ayuv = 0x56555941
    yuyv = 0x56595559
    vyuy = 0x59555956
    uyvy = 0x59565955
  
  DndAction* {.pure.} = enum
    copy
    move
    ask
  
  Transform* {.pure.} = enum
    normal
    rotated90
    rotated180
    rotated270
    flipped
    rotated90_and_flipped
    rotated180_and_flipped
    rotated270_and_flipped
  
  Capability* {.pure.} = enum
    cursor
    keyboard
    touch
  
  Axis* {.pure.} = enum
    horizontal
    vertical
  
  AxisSource* {.pure.} = enum
    wheel
    finger
    continuous
    wheelTilt
  
  KeyboardFormat* {.pure.} = enum
    no
    xkb_v1
  
  Subpixel* {.pure.} = enum
    unknown
    none
    horisontalRgb
    horisontalBgr
    verticalRgb
    verticalBgr
  
  ModeFlag* {.pure.} = enum
    current
    prefered
  
  Anchor* {.pure.} = enum
    none
    top
    bottom
    left
    right
    topLeft
    bottomLeft
    topRight
    bottomRight
  
  ConstraintAllignment* {.pure.} = enum
    slideX
    slideY
    flipX
    flipY
    resizeX
    resizeY

  Edge* {.pure.} = enum
    top
    bottom
    left
    right
  
  ShellSurfaceState* {.pure.} = enum
    maximized = 1
    fullscreen
    resizing
    activated
    tiledLeft
    tiledRight
    tiledTop
    tiledBottom



protocol:
  Display:
    proc syncRequest: Callback
    proc registry: Registry

    proc error(objId: Id, code: int, message: string): event
    proc deleteId(id: Id): event


  Registry:
    # proc bindInterface*(T: type, name: int, iface: string, version: int): T

    proc global(name: int, iface: string, version: int): event
    proc globalRemove(name: int): event


  Callback:
    proc done(cbData: uint32): event


  Compositor:
    iface "wl_compositor"

    proc newSurface: Surface
    proc newRegion: Region


  Shm:
    iface "wl_shm"

    proc newPool(fd: FileDescriptor, size: int): ShmPool

    proc format(format: ShmFormat): event


  ShmPool:
    proc newBuffer(offset: int, size: IVec2, stride: int, format: ShmFormat): Buffer
    proc destroy
    proc resize(size: int)


  Buffer:
    proc destroy

    proc release: event


  DataOffer:
    proc accept(serial: int, mime: string)
    proc receive(mime: string, fd: FileDescriptor)
    proc destroy
    proc finish
    proc setActions(actions: set[DndAction], prefered: bitField Option[DndAction])

    proc offer(mime: string): event
    proc sourceActions(actions: set[DndAction]): event
    proc action(action: bitField Option[DndAction]): event


  DataSource:
    proc offer(mime: string)
    proc destroy
    proc `actions=`(actions: set[DndAction])

    proc target(mime: string): event
    proc send(mime: string, fd: FileDescriptor): event
    proc cancelled: event
    proc dndDropPerformed: event
    proc dndFinished: event
    proc action(action: bitField Option[DndAction]): event


  DataDevice:
    proc startDrag(origin, icon: Surface, serial: int): DataSource
    proc sellect(serial: int): DataSource
    proc destroy

    proc offer(offer: DataOffer): event
    proc enter(serial: int, surface: Surface, pos: Vec2, offer: DataOffer): event
    proc leave: event
    proc motion(time: int, pos: Vec2): event
    proc drop: event
    proc sellected(offer: DataOffer): event


  DataDeviceManager:
    iface "wl_data_device_manager"

    proc newDataSource: DataSource
    proc dataDevice(seat: Seat): DataDevice


  Surface:
    proc destroy
    proc attach(buffer: Buffer, pos: IVec2)
    proc damage(pos: IVec2, size: IVec2)
    proc frame: Callback
    proc setOpaqueRegion(region: Region)
    proc setInputRegion(region: Region)
    proc commit
    proc setBufferTransform(transform: Transform)
    proc setBufferScale(scale: int)
    proc damageBuffer(pos: IVec2, size: IVec2)

    proc enter(output: Output): event
    proc leave(output: Output): event


  Seat:
    iface "wl_seat"

    proc cursor: Cursor
    proc keyboard: Keyboard
    proc touch: Touch
    proc destroy

    proc capabilities(capabilities: set[Capability]): event
    proc name(name: string): event


  Cursor:
    proc setCursor(serial: int, surface: Surface, hotspot: IVec2)
    proc destroy

    proc enter(serial: int, surface: Surface, pos: IVec2): event
    proc leave(serial: int, surface: Surface): event
    proc motion(time: int, pos: IVec2): event
    proc button(serial: int, time: int, button: int, pressed: bool): event
    proc scroll(time: int, axis: Axis, value: float): event
    proc frame: event
    proc axisSource(source: AxisSource): event
    proc scrollStop(time: int, axis: Axis): event
    proc scrollDiscrete(axis: Axis, value: int): event


  Keyboard:
    proc destroy

    proc keymap(format: KeyboardFormat, fd: FileDescriptor, size: int): event
    proc enter(serial: int, surface: Surface, keys: seq[uint32]): event
    proc leave(serial: int, surface: Surface): event
    proc key(serial: int, time: int, key: uint32, pressed: bool): event
    proc modifiers(serial: int, depressed, latched, locked: int, group: int): event
    proc repeatInfo(rate: int, delay: int): event


  Touch:
    proc destroy

    proc down(serial: int, time: int, surface: Surface, id: int, pos: Vec2): event
    proc up(serial: int, time: int, id: int): event
    proc motion(time: int, id: int, pos: Vec2): event
    proc frame: event
    proc cancel: event
    proc shape(id: int, major, minor: float): event
    proc orientation(id: int, orientation: float): event


  Output:
    iface "wl_output"

    proc destroy

    proc geometry(pos: IVec2, sizeInMillimeters: IVec2, subpixel: Subpixel, make: string, model: string, transform: Transform): event
    proc mode(flags: set[ModeFlag], size: IVec2, refresh: int): event
    proc done: event
    proc scale(factor: int): event


  Region:
    proc destroy
    proc add(pos: IVec2, size: IVec2)
    proc substract(pos: IVec2, size: IVec2)


  Subcompositor:
    iface "wl_subcompositor"

    proc destroy
    proc subsurface(surface: Surface, parent: Surface): Subsurface


  Subsurface:
    proc destroy
    proc `pos=`(v: IVec2)
    proc placeAbove(sibling: Surface)
    proc placeBelow(sibling: Surface)
    proc setSync
    proc setDesync
  

  XdgWmBase:
    iface "xdg_wm_base"

    proc destroy
    proc newPositioner: Positioner
    proc shellSurface(surface: Surface): ShellSurface
    proc pong(serial: int)

    proc ping(serial: int): event
  

  Positioner:
    proc destroy
    proc `size=`(v: IVec2)
    proc setAnchorRect(pos: IVec2, size: IVec2)
    proc `anchor=`(v: Anchor)
    proc `gravity=`(v: int)
    proc `constraintAllignment=`(v: set[ConstraintAllignment])
    proc `offset=`(v: IVec2)
    proc setRelative
    proc `parentSize=`(v: IVec2)
    proc setParentConfigure(serial: int)


  ShellSurface:
    proc destroy
    proc toplevel: Toplevel
    proc popup(parent: ShellSurface, positioner: Positioner): Popup
    proc setGeometry(pos: IVec2, size: IVec2)
    proc ackConfigure(serial: int)

    proc configure(serial: int): event
  

  Toplevel:
    proc destroy
    proc `parent=`(v: Toplevel)
    proc `title=`(v: string)
    proc `appId=`(v: string)
    proc showWindowMenu(seat: Seat, serial: int, pos: IVec2)
    proc move(seat: Seat, serial: int)
    proc resize(seat: Seat, serial: int, edges: set[Edge])
    proc `maxSize=`(v: IVec2)
    proc `minSize=`(v: IVec2)
    proc maximize
    proc unmaximize
    proc fullscreen
    proc unfullscreen
    proc minimize

    proc configure(size: IVec2, states: seq[ShellSurfaceState]): event
    proc close: event
  

  Popup:
    proc destroy
    proc grub(seat: Seat, serial: int)
    proc reposition(positioner: Positioner, token: int)

    proc configure(pos: IVec2, size: IVec2): event
    proc done: event
    proc repositioned(token: int): event



proc sync*(this: Display) =
  let cb = this.syncRequest
  var done: bool
  cb.onDone: done = true
  while not done: this.pollNextEvent


proc bindInterface*(this: Registry, T: type, name: int, iface: string, version: int): T =
  result = this.display.new(T)
  this.marshal(0, (name, iface, version, result.id))
