include basic
import macros, strformat, sequtils, vmath

macro protocol(body) =
  proc injectAllParams(x: NimNode): NimNode =
    result = nnkFormalParams.newTree(
      @[x[0]] &
      x[1..^1].mapit(newIdentDefs(nnkPragmaExpr.newTree(it[0], nnkPragma.newTree(ident"inject")), it[1], it[2]))
    )
  
  proc separateParams(x: NimNode): tuple[p, t: seq[NimNode]] =
    (x[1..^1].mapit(it[0..^3]).concat, x[1..^1].mapit(it[^2].repeat(it.len - 2)).concat)

  result = newStmtList()
  var types: seq[seq[NimNode]]

  for x in body:
    let t = x[0]
    types.add @[t]
    var unms = nnkCaseStmt.newTree(ident"op")
    var i = 0

    for a in x[1]:
      let p = a.params

      if p[0] == ident"event":
        p[0] = newEmptyNode()
        types[^1].add nnkIdentDefs.newTree( # field declaration
          nnkPostfix.newTree(ident"*", a.name),
          nnkProcTy.newTree(
            p,
            newEmptyNode()
          ),
          newEmptyNode()
        )
        result.add nnkTemplateDef.newTree( # x.onEvent:... template
          nnkPostfix.newTree(ident"*", ident &"on{a.name}"),
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
                p.injectAllParams,
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
              let (args, types) = p.separateParams
              newStmtList(
                (if args.len > 0: @[nnkLetSection.newTree(nnkVarTuple.newTree(
                  args &
                  @[newEmptyNode()] &
                  @[nnkCall.newTree(
                    nnkDotExpr.newTree(ident"data", ident"deserialize"),
                    nnkTupleConstr.newTree(types)
                  )]
                ))] else: newSeq[NimNode]()) &
                @[nnkCall.newTree(
                  @[nnkDotExpr.newTree(ident"this", a.name)] &
                  args
                )]
              )
          ))
        )
      else:
        let extern =
          if p[0].kind == nnkCommand and p[0][0].kind == nnkCall and p[0][0][0] == ident"extern":
            p[0][0][1]
          else: nil
        if extern != nil:
          p[0] = p[0][1]
        let (args, _) = p.separateParams
        p.insert 1, newIdentDefs(ident"this", t)
        let name = a.name
        a.name = nnkPostfix.newTree(ident"*", a.name)
        a.params = p
        a.body = nnkCall.newTree(
          @[nnkDotExpr.newTree(ident"this", ident"marshal"), newLit i] &
          @[nnkTupleConstr.newTree(
            if p[0].kind == nnkEmpty: args
            else: @[nnkDotExpr.newTree(ident"result", ident"id")] & args
          )]
        )
        if p[0].kind != nnkEmpty:
          a.body = newStmtList(
            nnkAsgn.newTree(
              ident"result",
              newCall(if extern == nil: ident"new" else: ident"extern",
                @[nnkDotExpr.newTree(ident"this", ident"display")] &
                @[p[0]] &
                (if extern != nil: @[extern] else: @[])
              )
            ),
            a.body
          )
        if $name == "destroy":
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
    types[1..^1].mapit( # do not redefine Display
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
  
  Edge* {.pure.} = enum
    top
    bottom
    left
    right

  TransientFlag* {.pure.} = enum
    inactive
  
  FullscreenMethod* {.pure.} = enum
    default
    scale
    driver
    fill
  
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



expandMacros:
  protocol:
    Display:
      proc sync: Callback
      proc registry: Registry

      proc error(objId: Id, code: int, message: string): event
      proc deleteId(id: Id): event


    Registry:
      proc bindInterface[T](iface: string): T
      
      proc global(name: Id, iface: string, version: int): event
      proc globalRemove(name: Id): event


    Callback:
      proc done(cbData: uint32): event

    
    Compositor:
      proc newSurface: Surface
      proc newRegion: Region


    ShmPool:
      proc newBuffer(offset: int, size: IVec2, stride: int, format: ShmFormat): Buffer
      proc destroy
      proc resize(size: int)
    

    Shm:
      proc newPool(fd: FileDescriptor, size: int): ShmPool

      proc format(format: ShmFormat): event
    

    Buffer:
      proc destroy

      proc release: event


    DataOffer:
      proc accept(serial: int, mime: string)
      proc receive(mime: string, fd: FileDescriptor)
      proc destroy
      proc finish
      proc setActions(actions: set[DndAction], prefered: bitField DndAction|none)

      proc offer(mime: string): event
      proc sourceActions(actions: set[DndAction]): event
      proc action(action: bitField DndAction): event
    

    DataSource:
      proc offer(mime: string)
      proc destroy
      proc `actions=`(actions: set[DndAction])

      proc target(mime: string): event
      proc send(mime: string, fd: FileDescriptor): event
      proc cancelled: event
      proc dndDropPerformed: event
      proc dndFinished: event
      proc action(action: bitField DndAction): event


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
      proc newDataSource: DataSource
      proc dataDevice(seat: Seat): DataDevice

    
    Shell:
      proc shellSurface(surface: Surface): ShellSurface
    

    ShellSurface:
      proc pong(serial: int)
      proc move(seat: Seat, serial: int)
      proc resize(seat: Seat, serial: int, edges: set[Edge])
      proc setToplevel
      proc setTransient(parent: Surface, pos: IVec2, flags: set[TransientFlag])
      proc setFullscreen(m: FullscreenMethod, framerate: int, output: Output)
      proc setPopup(seat: Seat, serial: int, parent: Surface, pos: IVec2, flags: set[TransientFlag])
      proc setMaximized(output: Output)
      proc setTitle(title: string)
      proc setClass(class: string)

      proc ping(serial: int): event
      proc configure(edges: set[Edge], size: IVec2): event
      proc popupDone: event


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
      proc cursor: Cursor
      proc keyboard: Keyboard
      proc touch: Touch
      proc destroy

      proc capabilities(capabilities: set[Capability]): event
      proc name(name: string): event
    

    Cursor:
      proc set(serial: int, surface: Surface, hotspot: IVec2)
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
      proc enter(serial: int, surface: Surface, keys: seq[uint]): event
      proc leave(serial: int, surface: Surface): event
      proc key(serial: int, time: int, key: uint, pressed: bool): event
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
      proc destroy
      proc subsurface(surface: Surface, parent: Surface): Subsurface

    
    Subsurface:
      proc destroy
      proc `pos=`(pos: IVec2)
      proc placeAbove(sibling: Surface)
      proc placeBelow(sibling: Surface)
      proc setSync
      proc setDesync
