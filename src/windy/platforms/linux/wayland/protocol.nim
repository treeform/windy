include basic
import macros, strformat, sequtils

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
                nnkLetSection.newTree(nnkVarTuple.newTree(
                  args &
                  @[newEmptyNode()] &
                  @[nnkCall.newTree(
                    nnkDotExpr.newTree(ident"data", ident"deserialize"),
                    nnkTupleConstr.newTree(types)
                  )]
                )),
                nnkCall.newTree(
                  @[nnkDotExpr.newTree(ident"this", a.name)] &
                  args
                )
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
        a.name = nnkPostfix.newTree(ident"*", a.name)
        a.params = p
        a.body = nnkCall.newTree(
          @[nnkDotExpr.newTree(ident"this", ident"marshal"), newLit i] & (
            if p[0].kind == nnkEmpty: args
            else: args & @[nnkDotExpr.newTree(ident"result", ident"id")])
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


protocol:
  Display:
    proc sync: Callback
    proc registry: Registry

    proc error(objId: Id, code: DisplayErrorCode, message: string): event
    proc deleteId(id: Id): event


  Callback:
    proc done(cbData: uint32): event


  Registry:
    proc bindInterface[T](name: Id, iface: string, version: int): extern(name) T
    
    proc global(name: Id, iface: string, version: int): event
    proc globalRemove(name: Id): event


when isMainModule:
  let display = connect()
  display.onError:
    echo "Error for ", objId.uint32, ": ", code, ", ", message
  
  let reg = display.registry
  reg.onGlobal:
    echo (id: name.uint32, iface: iface, version: version)
  
  display.pollEvents
