## UI Automation providers implemented directly in Nim.
## COM objects contain only unmanaged data. Calls that use text or application
## callbacks are sent synchronously to the window thread; COM worker threads
## never enter Nim's allocator or access a managed string, sequence or table.
import std/[atomics, tables, unicode, algorithm]
import windefs, uiadefs, utils

const
  WM_WINDY_TEXT* = WM_APP + 2
  WM_WINDY_FOCUS* = WM_APP + 3

type
  NativeTextEdit* = proc(context: pointer, kind, first, last: cint,
    text: ptr WCHAR): cint {.cdecl.}

  NodeKind = enum
    RootNode, EditorNode, RangeNode

  Interface = object
    vtable: pointer
    owner: ptr Node

  Node = object
    simple, fragment, fragmentRoot, value, text, range: Interface
    refs: Atomic[int32]
    kind: NodeKind
    parent, root: ptr Node # Strong parent reference; root is an alias.
    hwnd: Atomic[int] # Only the root stores the HWND.
    child: ptr Node # Weak; accessed only on the window thread.
    serial, first, last: int32

  Snapshot = object
    id: string
    text: seq[WCHAR]
    first, last, visibleFirst, visibleLast: int32
    bounds: UiaRect
    editable, focused, published: bool

  Operation = enum
    ProviderOptions, PatternProvider, PropertyValue, HostProvider,
    Navigate, RuntimeId, BoundingRectangle, EmbeddedRoots, SetFocus, FragmentRoot,
    FromPoint, GetFocus, SetValue, GetValue, IsReadOnly, Selection, VisibleRanges,
    RangeFromChild, RangeFromPoint, DocumentRange, SupportedSelection,
    Clone, Compare, CompareEndpoints, Expand, FindAttribute, FindText,
    AttributeValue, Rectangles, EnclosingElement, GetText, Move,
    MoveEndpointByUnit, MoveEndpointByRange, SelectRange, AddToSelection,
    RemoveFromSelection, ScrollIntoView, Children

  Request = object
    node: ptr Node
    operation: Operation
    output, other: pointer
    a, b, c: cint
    wide: ptr WCHAR
    point: UiaPoint
    attribute: Variant
    status: HRESULT

var
  simpleVtbl: SimpleVtbl
  fragmentVtbl: FragmentVtbl
  fragmentRootVtbl: FragmentRootVtbl
  valueVtbl: ValueVtbl
  textVtbl: TextVtbl
  rangeVtbl: RangeVtbl
  snapshots: Table[ptr Node, Snapshot] # Window thread only.
  nextSerial: int32

# These entry points can execute on foreign threads. Keep them allocation-free,
# including in debug builds. No exceptions may cross the COM ABI.
{.push stackTrace: off, checks: off, raises: [], gcsafe.}

proc nodeFor(self: pointer): ptr Node {.inline.} =
  cast[ptr Interface](self).owner

proc retain(node: ptr Node): uint32 =
  uint32(node.refs.fetchAdd(1, moRelaxed) + 1)

proc releaseNode(node: ptr Node): uint32 =
  result = uint32(node.refs.fetchSub(1, moAcquireRelease) - 1)
  if result == 0:
    let parent = node.parent
    discard HeapFree(GetProcessHeap(), 0, node)
    if parent != nil:
      discard releaseNode(parent)

proc queryInterface(self: pointer, iid: ptr UiaGuid, value: ptr pointer): HRESULT {.stdcall.} =
  if value == nil:
    return uiaPointer
  value[] = nil
  if iid == nil:
    return uiaPointer
  let node = nodeFor(self)
  if node.kind == RangeNode:
    if iid[] == iidUnknown or iid[] == iidRange:
      value[] = addr node.range
  elif iid[] == iidUnknown or iid[] == iidSimple:
    value[] = addr node.simple
  elif iid[] == iidFragment:
    value[] = addr node.fragment
  elif node.kind == RootNode and iid[] == iidRoot:
    value[] = addr node.fragmentRoot
  elif node.kind == EditorNode:
    if iid[] == iidValue:
      value[] = addr node.value
    elif iid[] == iidText:
      value[] = addr node.text
  if value[] == nil:
    return uiaNoInterface
  discard retain(node)
  uiaOk

proc addRef(self: pointer): uint32 {.stdcall.} = retain(nodeFor(self))
proc release(self: pointer): uint32 {.stdcall.} = releaseNode(nodeFor(self))

proc forward(self: pointer, operation: Operation, output: pointer = nil,
    a = 0.cint, b = 0.cint, c = 0.cint, other: pointer = nil,
    wide: ptr WCHAR = nil, point = UiaPoint(), attribute = Variant(),
    outputSize = sizeof(pointer)): HRESULT =
  if operation notin {SetFocus, SetValue, Expand, MoveEndpointByRange,
      SelectRange, AddToSelection, RemoveFromSelection, ScrollIntoView}:
    if output == nil:
      return uiaPointer
    zeroMem(output, outputSize)
  let node = nodeFor(self)
  let hwnd = node.root.hwnd.load(moAcquire)
  if hwnd == 0:
    return uiaUnavailable
  var request = Request(node: node, operation: operation, output: output,
    a: a, b: b, c: c, other: other, wide: wide, point: point,
    attribute: attribute, status: uiaUnavailable)
  discard SendMessageW(hwnd, WM_WINDY_TEXT, cast[WPARAM](node.root),
    cast[LPARAM](addr request))
  request.status

proc providerOptions(self: pointer, value: ptr cint): HRESULT {.stdcall.} =
  if value == nil: return uiaPointer
  value[] = 2 # ProviderOptions_ServerSideProvider
  uiaOk
proc patternProvider(self: pointer, id: cint, value: ptr pointer): HRESULT {.stdcall.} =
  forward(self, PatternProvider, value, a = id)
proc propertyValue(self: pointer, id: cint, value: ptr Variant): HRESULT {.stdcall.} =
  forward(self, PropertyValue, value, a = id, outputSize = sizeof(Variant))
proc hostProvider(self: pointer, value: ptr pointer): HRESULT {.stdcall.} =
  forward(self, HostProvider, value)
proc navigate(self: pointer, direction: cint, value: ptr pointer): HRESULT {.stdcall.} =
  forward(self, Navigate, value, a = direction)
proc runtimeId(self: pointer, value: ptr ptr SafeArray): HRESULT {.stdcall.} =
  forward(self, RuntimeId, value)
proc boundingRectangle(self: pointer, value: ptr UiaRect): HRESULT {.stdcall.} =
  forward(self, BoundingRectangle, value, outputSize = sizeof(UiaRect))
proc embeddedRoots(self: pointer, value: ptr ptr SafeArray): HRESULT {.stdcall.} =
  forward(self, EmbeddedRoots, value)
proc setFocus(self: pointer): HRESULT {.stdcall.} = forward(self, SetFocus)
proc fragmentRoot(self: pointer, value: ptr pointer): HRESULT {.stdcall.} =
  forward(self, FragmentRoot, value)
proc fromPoint(self: pointer, x, y: cdouble, value: ptr pointer): HRESULT {.stdcall.} =
  forward(self, FromPoint, value, point = UiaPoint(x: x, y: y))
proc getFocus(self: pointer, value: ptr pointer): HRESULT {.stdcall.} =
  forward(self, GetFocus, value)
proc setValue(self: pointer, value: ptr WCHAR): HRESULT {.stdcall.} =
  if value == nil: return uiaPointer
  forward(self, SetValue, wide = value)
proc getValue(self: pointer, value: ptr ptr WCHAR): HRESULT {.stdcall.} =
  forward(self, GetValue, value)
proc isReadOnly(self: pointer, value: ptr BOOL): HRESULT {.stdcall.} =
  forward(self, IsReadOnly, value, outputSize = sizeof(BOOL))
proc selection(self: pointer, value: ptr ptr SafeArray): HRESULT {.stdcall.} =
  forward(self, Selection, value)
proc visibleRanges(self: pointer, value: ptr ptr SafeArray): HRESULT {.stdcall.} =
  forward(self, VisibleRanges, value)
proc rangeFromChild(self, child: pointer, value: ptr pointer): HRESULT {.stdcall.} =
  forward(self, RangeFromChild, value, other = child)
proc rangeFromPoint(self: pointer, point: UiaPoint, value: ptr pointer): HRESULT {.stdcall.} =
  forward(self, RangeFromPoint, value, point = point)
proc documentRange(self: pointer, value: ptr pointer): HRESULT {.stdcall.} =
  forward(self, DocumentRange, value)
proc supportedSelection(self: pointer, value: ptr cint): HRESULT {.stdcall.} =
  forward(self, SupportedSelection, value, outputSize = sizeof(cint))
proc clone(self: pointer, value: ptr pointer): HRESULT {.stdcall.} =
  forward(self, Clone, value)
proc compare(self, other: pointer, value: ptr BOOL): HRESULT {.stdcall.} =
  forward(self, Compare, value, other = other, outputSize = sizeof(BOOL))
proc compareEndpoints(self: pointer, endpoint: cint, other: pointer,
    targetEndpoint: cint, value: ptr cint): HRESULT {.stdcall.} =
  forward(self, CompareEndpoints, value, a = endpoint, b = targetEndpoint,
    other = other, outputSize = sizeof(cint))
proc expand(self: pointer, unit: cint): HRESULT {.stdcall.} =
  forward(self, Expand, a = unit)
proc findAttribute(self: pointer, id: cint, attribute: Variant, backward: BOOL,
    value: ptr pointer): HRESULT {.stdcall.} =
  forward(self, FindAttribute, value, a = id, b = backward, attribute = attribute)
proc findText(self: pointer, text: ptr WCHAR, backward, ignoreCase: BOOL,
    value: ptr pointer): HRESULT {.stdcall.} =
  if text == nil: return uiaPointer
  forward(self, FindText, value, a = backward, b = ignoreCase, wide = text)
proc attributeValue(self: pointer, id: cint, value: ptr Variant): HRESULT {.stdcall.} =
  forward(self, AttributeValue, value, a = id, outputSize = sizeof(Variant))
proc rectangles(self: pointer, value: ptr ptr SafeArray): HRESULT {.stdcall.} =
  forward(self, Rectangles, value)
proc enclosingElement(self: pointer, value: ptr pointer): HRESULT {.stdcall.} =
  forward(self, EnclosingElement, value)
proc getText(self: pointer, maximum: cint, value: ptr ptr WCHAR): HRESULT {.stdcall.} =
  forward(self, GetText, value, a = maximum)
proc move(self: pointer, unit, count: cint, value: ptr cint): HRESULT {.stdcall.} =
  forward(self, Move, value, a = unit, b = count, outputSize = sizeof(cint))
proc moveEndpointByUnit(self: pointer, endpoint, unit, count: cint,
    value: ptr cint): HRESULT {.stdcall.} =
  forward(self, MoveEndpointByUnit, value, a = endpoint, b = unit, c = count,
    outputSize = sizeof(cint))
proc moveEndpointByRange(self: pointer, endpoint: cint, other: pointer,
    targetEndpoint: cint): HRESULT {.stdcall.} =
  forward(self, MoveEndpointByRange, a = endpoint, b = targetEndpoint, other = other)
proc selectRange(self: pointer): HRESULT {.stdcall.} = forward(self, SelectRange)
proc addToSelection(self: pointer): HRESULT {.stdcall.} = forward(self, AddToSelection)
proc removeFromSelection(self: pointer): HRESULT {.stdcall.} = forward(self, RemoveFromSelection)
proc scrollIntoView(self: pointer, alignTop: BOOL): HRESULT {.stdcall.} =
  forward(self, ScrollIntoView, a = alignTop)
proc children(self: pointer, value: ptr ptr SafeArray): HRESULT {.stdcall.} =
  forward(self, Children, value)

{.pop.}

let unknownVtbl = UnknownVtbl(queryInterface: queryInterface, addRef: addRef, release: release)
simpleVtbl = SimpleVtbl(unknown: unknownVtbl, providerOptions: providerOptions,
  patternProvider: patternProvider, propertyValue: propertyValue, hostProvider: hostProvider)
fragmentVtbl = FragmentVtbl(unknown: unknownVtbl,
  navigate: navigate, runtimeId: runtimeId, boundingRectangle: boundingRectangle,
  embeddedRoots: embeddedRoots, setFocus: setFocus, fragmentRoot: fragmentRoot)
fragmentRootVtbl = FragmentRootVtbl(unknown: unknownVtbl,
  fromPoint: fromPoint, getFocus: getFocus)
valueVtbl = ValueVtbl(unknown: unknownVtbl, setValue: setValue, getValue: getValue,
  isReadOnly: isReadOnly)
textVtbl = TextVtbl(unknown: unknownVtbl, selection: selection, visibleRanges: visibleRanges,
  rangeFromChild: rangeFromChild, rangeFromPoint: rangeFromPoint,
  documentRange: documentRange, supportedSelection: supportedSelection)
rangeVtbl = RangeVtbl(unknown: unknownVtbl, clone: clone, compare: compare,
  compareEndpoints: compareEndpoints, expand: expand, findAttribute: findAttribute,
  findText: findText, attributeValue: attributeValue, rectangles: rectangles,
  enclosingElement: enclosingElement, getText: getText, move: move,
  moveEndpointByUnit: moveEndpointByUnit, moveEndpointByRange: moveEndpointByRange,
  selectRange: selectRange, addToSelection: addToSelection,
  removeFromSelection: removeFromSelection, scrollIntoView: scrollIntoView, children: children)

proc newNode(kind: NodeKind, parent: ptr Node = nil): ptr Node =
  result = cast[ptr Node](HeapAlloc(GetProcessHeap(), 8, csize_t(sizeof(Node))))
  if result == nil:
    return
  result.kind = kind
  result.refs.store(1, moRelaxed)
  result.parent = parent
  result.root = if parent == nil: result else: parent.root
  if parent != nil:
    discard retain(parent)
  result.simple = Interface(vtable: addr simpleVtbl, owner: result)
  result.fragment = Interface(vtable: addr fragmentVtbl, owner: result)
  result.fragmentRoot = Interface(vtable: addr fragmentRootVtbl, owner: result)
  result.value = Interface(vtable: addr valueVtbl, owner: result)
  result.text = Interface(vtable: addr textVtbl, owner: result)
  result.range = Interface(vtable: addr rangeVtbl, owner: result)

proc copyWide(text: ptr WCHAR, length = -1): seq[WCHAR] =
  if text == nil:
    return
  let data = cast[ptr UncheckedArray[WCHAR]](text)
  var count = length
  if count < 0:
    count = 0
    while data[count] != 0:
      inc count
  result = newSeq[WCHAR](count)
  if count > 0:
    copyMem(addr result[0], text, count * sizeof(WCHAR))

proc boundary(text: seq[WCHAR], index: int, up = false): int32 =
  result = int32(clamp(index, 0, text.len))
  if result > 0 and result < text.len and text[result - 1] in 0xd800'u16..0xdbff'u16 and
      text[result] in 0xdc00'u16..0xdfff'u16:
    result += (if up: 1 else: -1)

proc bstr(text: seq[WCHAR], first = 0, last = -1): ptr WCHAR =
  let finish = if last < 0: text.len else: last
  let data = if finish > first: unsafeAddr text[first] else: nil
  SysAllocStringLen(data, uint32(finish - first))

proc stringVariant(text: seq[WCHAR]): Variant =
  Variant(vt: vtBstr, data: VariantData(str: bstr(text)))

proc stringVariant(text: string): Variant =
  let wide = text.wstr()
  Variant(vt: vtBstr, data: VariantData(
    str: SysAllocStringLen(cast[ptr WCHAR](unsafeAddr wide[0]), uint32((wide.len - 1) div 2))))

proc boolVariant(value: bool): Variant =
  Variant(vt: vtBool, data: VariantData(boolean: (if value: -1'i16 else: 0'i16)))

proc arrayOf[T](kind: uint16, values: openArray[T]): ptr SafeArray =
  result = SafeArrayCreateVector(kind, 0, uint32(values.len))
  if result != nil:
    for i in 0 ..< values.len:
      var index = int32(i)
      if SafeArrayPutElement(result, addr index, unsafeAddr values[i]) < 0:
        discard SafeArrayDestroy(result)
        return nil

proc boundsVariant(bounds: UiaRect): Variant =
  Variant(vt: vtArray or vtR8, data: VariantData(arrayValue:
    arrayOf(vtR8, [bounds.x, bounds.y, bounds.width, bounds.height])))

proc returnInterface(value: pointer, slot: ptr Interface): HRESULT =
  if slot != nil:
    discard retain(slot.owner)
  cast[ptr pointer](value)[] = slot
  uiaOk

proc newRange(editor: ptr Node, first, last: int32): ptr Node =
  result = newNode(RangeNode, editor)
  if result != nil:
    result.first = first
    result.last = last

proc returnRange(value: pointer, editor: ptr Node, first, last: int32): HRESULT =
  let node = newRange(editor, first, last)
  if node == nil: return uiaOutOfMemory
  cast[ptr pointer](value)[] = addr node.range
  uiaOk

proc rangeArray(value: pointer, editor: ptr Node, first, last: int32): HRESULT =
  let node = newRange(editor, first, last)
  if node == nil: return uiaOutOfMemory
  defer: discard releaseNode(node)
  let list = SafeArrayCreateVector(vtUnknown, 0, 1)
  if list == nil: return uiaOutOfMemory
  var index = 0'i32
  # For VT_UNKNOWN, SafeArrayPutElement takes the interface itself, not its address.
  result = SafeArrayPutElement(list, addr index, addr node.range)
  if result < 0:
    discard SafeArrayDestroy(list)
  else:
    cast[ptr ptr SafeArray](value)[] = list

proc sameEditor(other: pointer, editor: ptr Node): ptr Node =
  if other != nil:
    let slot = cast[ptr Interface](other)
    let expectedVtable = addr rangeVtbl
    if slot.vtable == expectedVtable and slot.owner.parent == editor:
      result = slot.owner

proc unitBoundaries(text: seq[WCHAR], unit: cint): seq[int32] =
  result = @[0'i32]
  let unit = if unit == 1: 2.cint else: unit # No formatting runs; use words.
  for i in 1 ..< text.len:
    if text.boundary(i) != i:
      continue
    if unit == 0 or
        (unit == 2 and Rune(text[i - 1]).isWhiteSpace and not Rune(text[i]).isWhiteSpace) or
        (unit in [3.cint, 4.cint] and text[i - 1] == 10):
      result.add(int32(i))
  if text.len > 0:
    result.add(int32(text.len))

proc normalize(node: ptr Node, text: seq[WCHAR]) =
  node.first = text.boundary(node.first)
  node.last = max(node.first, text.boundary(node.last, node.last > node.first))

proc dispatch(request: ptr Request, edit: NativeTextEdit, context: pointer): HRESULT =
  let
    node = request.node
    root = node.root
    hwnd = root.hwnd.load(moAcquire)
    op = request.operation
    output = request.output
    a = request.a
    b = request.b
    c = request.c
  if hwnd == 0:
    return uiaUnavailable
  let editor = if node.kind == RangeNode: node.parent else: node
  if node.kind != RootNode and (root.child != editor or not snapshots.hasKey(editor)):
    return uiaUnavailable
  let state = snapshots.getOrDefault(editor)
  if node.kind == RangeNode:
    node.normalize(state.text)
  result = uiaOk
  template integer(value: untyped) = cast[ptr cint](output)[] = cint(value)
  template arrayValue(value: untyped) =
    cast[ptr ptr SafeArray](output)[] = value
    if cast[ptr ptr SafeArray](output)[] == nil: return uiaOutOfMemory
  case op
  of ProviderOptions:
    integer(2)
  of PatternProvider:
    if node.kind == EditorNode:
      if a == 10002: return returnInterface(output, addr node.value)
      if a == 10014: return returnInterface(output, addr node.text)
  of PropertyValue:
    if node.kind == RootNode: return uiaOk # The native HWND supplies host properties.
    let value = cast[ptr Variant](output)
    case a
    of 30001: value[] = boundsVariant(state.bounds)
    of 30003: value[] = Variant(vt: vtI4, data: VariantData(integer: 50004))
    of 30005: value[] = stringVariant("Text input")
    of 30011: value[] = stringVariant(state.id)
    of 30024: value[] = stringVariant("Windy")
    of 30008: value[] = boolVariant(state.focused)
    of 30009, 30010, 30016, 30017, 30040, 30043: value[] = boolVariant(true)
    of 30019: value[] = boolVariant(false)
    of 30022: value[] = boolVariant(state.bounds.width <= 0 or state.bounds.height <= 0)
    of 30045: value[] = stringVariant(state.text)
    of 30046: value[] = boolVariant(not state.editable)
    else: discard
  of HostProvider:
    if node.kind == RootNode:
      return UiaHostProviderFromHwnd(hwnd, cast[ptr pointer](output))
  of Navigate:
    if node.kind == RootNode and a in [3.cint, 4.cint] and root.child != nil:
      return returnInterface(output, addr root.child.fragment)
    if node.kind == EditorNode and a == 0:
      return returnInterface(output, addr root.fragment)
  of RuntimeId:
    if node.kind != RootNode:
      arrayValue(arrayOf(vtI4, [3'i32, node.serial]))
  of BoundingRectangle:
    if node.kind == RootNode:
      var rect: RECT
      discard GetWindowRect(hwnd, addr rect)
      cast[ptr UiaRect](output)[] = UiaRect(x: rect.left.cdouble, y: rect.top.cdouble,
        width: (rect.right - rect.left).cdouble, height: (rect.bottom - rect.top).cdouble)
    else:
      cast[ptr UiaRect](output)[] = state.bounds
  of EmbeddedRoots: discard
  of SetFocus:
    if SendMessageW(hwnd, WM_WINDY_FOCUS, 0, 0) == 0: return uiaInvalidOperation
  of FragmentRoot:
    return returnInterface(output, addr root.fragmentRoot)
  of FromPoint, GetFocus:
    if root.child != nil:
      let childState = snapshots[root.child]
      let bounds = childState.bounds
      if (op == GetFocus and childState.focused) or (op == FromPoint and
          request.point.x >= bounds.x and request.point.y >= bounds.y and
          request.point.x < bounds.x + bounds.width and request.point.y < bounds.y + bounds.height):
        return returnInterface(output, addr root.child.fragment)
    if op == FromPoint: return returnInterface(output, addr root.fragment)
  of SetValue, SelectRange:
    if not state.editable or edit == nil: return uiaInvalidOperation
    let accepted = if op == SetValue: edit(context, 0, 0, -1, request.wide)
      else: edit(context, 1, node.first, node.last, nil)
    if accepted == 0: return uiaInvalidOperation
  of GetValue:
    cast[ptr ptr WCHAR](output)[] = bstr(state.text)
    if cast[ptr ptr WCHAR](output)[] == nil: return uiaOutOfMemory
  of IsReadOnly: integer(not state.editable)
  of Selection:
    return rangeArray(output, editor, state.text.boundary(state.first),
      state.text.boundary(state.last, state.last > state.first))
  of VisibleRanges:
    return rangeArray(output, editor, state.text.boundary(state.visibleFirst),
      state.text.boundary(state.visibleLast, true))
  of RangeFromChild: return uiaInvalidArg
  of RangeFromPoint, ScrollIntoView: return uiaNotImplemented
  of DocumentRange: return returnRange(output, editor, 0, int32(state.text.len))
  of SupportedSelection: integer(1)
  of Clone: return returnRange(output, editor, node.first, node.last)
  of Compare, CompareEndpoints, MoveEndpointByRange:
    let other = sameEditor(request.other, editor)
    if other == nil: return uiaInvalidArg
    other.normalize(state.text)
    if op == Compare:
      integer(node.first == other.first and node.last == other.last)
    else:
      if a notin [0.cint, 1.cint] or b notin [0.cint, 1.cint]: return uiaInvalidArg
      let target = if b == 0: other.first else: other.last
      if op == CompareEndpoints:
        integer((if a == 0: node.first else: node.last) - target)
      elif a == 0:
        node.first = target
        node.last = max(node.last, target)
      else:
        node.last = target
        node.first = min(node.first, target)
  of Expand, Move, MoveEndpointByUnit:
    let unit = if op == MoveEndpointByUnit: b else: a
    if unit < 0 or unit > 6: return uiaInvalidArg
    let boundaries = unitBoundaries(state.text, unit)
    let maximum = boundaries.high
    if op == Expand:
      let index = min(max(0, boundaries.upperBound(node.first) - 1), max(0, maximum - 1))
      node.first = boundaries[index]
      node.last = boundaries[min(index + 1, maximum)]
    elif op == Move:
      if b == 0: return uiaOk
      let collapsed = node.first == node.last
      let limit = if collapsed: maximum else: max(0, maximum - 1)
      let index = min(max(0, boundaries.upperBound(node.first) - 1), limit)
      let target = int(clamp(index.int64 + b.int64, 0, limit.int64))
      node.first = boundaries[target]
      node.last = if collapsed: node.first else: boundaries[min(target + 1, maximum)]
      integer(target - index)
    else:
      if a notin [0.cint, 1.cint]: return uiaInvalidArg
      if c == 0: return uiaOk
      let position = if a == 0: node.first else: node.last
      let index = if c > 0: max(0, boundaries.upperBound(position) - 1)
        else: min(maximum, boundaries.lowerBound(position))
      let target = int(clamp(index.int64 + c.int64, 0, maximum.int64))
      if a == 0:
        node.first = boundaries[target]
        node.last = max(node.first, node.last)
      else:
        node.last = boundaries[target]
        node.first = min(node.first, node.last)
      integer(target - index)
  of FindAttribute:
    if a == 40015 and request.attribute.vt == vtBool and
        (request.attribute.data.boolean != 0) == (not state.editable):
      return returnRange(output, editor, node.first, node.last)
  of FindText:
    let needle = copyWide(request.wide, int(SysStringLen(request.wide)))
    if needle.len == 0: return uiaInvalidArg
    var match = -1
    for start in node.first.int .. node.last.int - needle.len:
      if state.text.boundary(start) != start or
          state.text.boundary(start + needle.len) != start + needle.len: continue
      var equal = true
      for i in 0 ..< needle.len:
        let left = Rune(state.text[start + i])
        let right = Rune(needle[i])
        if (if b != 0: left.toLower != right.toLower else: left != right):
          equal = false
          break
      if equal:
        match = start
        if a == 0: break
    if match >= 0: return returnRange(output, editor, int32(match), int32(match + needle.len))
  of AttributeValue:
    let value = cast[ptr Variant](output)
    if a == 40015:
      value[] = boolVariant(not state.editable)
    else:
      value.vt = vtUnknown
      return UiaGetReservedNotSupportedValue(addr value.data.unknown)
  of Rectangles:
    # We know the editor rectangle, not glyph geometry. Do not invent per-glyph bounds.
    if node.first < node.last and node.first <= state.visibleFirst and node.last >= state.visibleLast:
      let bounds = state.bounds
      arrayValue(arrayOf(vtR8, [bounds.x, bounds.y, bounds.width, bounds.height]))
    else:
      arrayValue(SafeArrayCreateVector(vtR8, 0, 0))
  of EnclosingElement: return returnInterface(output, addr editor.simple)
  of GetText:
    if a < -1: return uiaInvalidArg
    let finish = if a < 0: node.last else:
      state.text.boundary(int(min(node.last.int64, node.first.int64 + a.int64)))
    cast[ptr ptr WCHAR](output)[] = bstr(state.text, node.first, finish)
    if cast[ptr ptr WCHAR](output)[] == nil: return uiaOutOfMemory
  of AddToSelection, RemoveFromSelection: return uiaInvalidOperation
  of Children: arrayValue(SafeArrayCreateVector(vtUnknown, 0, 0))

proc windyTextRequest*(provider: pointer, request: int, edit: NativeTextEdit,
    context: pointer): int =
  let root = cast[ptr Node](provider)
  let operation = cast[ptr Request](request)
  if root == nil or operation == nil or operation.node.root != root:
    return 0
  # A callback may clear the field or close the window while this call is active.
  discard retain(operation.node)
  defer: discard releaseNode(operation.node)
  try:
    operation.status = dispatch(operation, edit, context)
  except CatchableError:
    operation.status = uiaInvalidOperation
  1

proc changed(root: ptr Node) =
  if UiaClientsAreListening() != 0:
    discard UiaRaiseStructureChangedEvent(addr root.simple, 2, nil, 0)

proc windyTextRootCreate*(hwnd: int): pointer =
  let root = newNode(RootNode)
  if root != nil:
    root.hwnd.store(hwnd, moRelease)
  root

proc windyTextRootDestroy*(provider: pointer) =
  let root = cast[ptr Node](provider)
  if root == nil: return
  let hwnd = root.hwnd.exchange(0, moAcquireRelease)
  root.child = nil
  discard UiaDisconnectProvider(addr root.simple)
  discard UiaReturnRawElementProvider(hwnd, 0, 0, nil)
  discard releaseNode(root)

proc windyTextCreate*(provider: pointer, id: ptr WCHAR): pointer =
  let root = cast[ptr Node](provider)
  if root == nil: return nil
  let editor = newNode(EditorNode, root)
  if editor == nil: return nil
  nextSerial = cast[int32](cast[uint32](nextSerial) + 1'u32)
  editor.serial = nextSerial
  snapshots[editor] = Snapshot(id: $id)
  root.child = editor
  editor

proc windyTextDestroy*(provider: pointer) =
  let editor = cast[ptr Node](provider)
  if editor == nil: return
  editor.root.child = nil
  snapshots.del(editor)
  discard UiaDisconnectProvider(addr editor.simple)
  changed(editor.root)
  discard releaseNode(editor)

proc windyTextPublish*(provider: pointer, text: ptr WCHAR,
    first, last, visibleFirst, visibleLast: cint,
    x, y, width, height: cdouble, editable, focused: cint) =
  let editor = cast[ptr Node](provider)
  if editor == nil or not snapshots.hasKey(editor): return
  var origin: POINT
  discard ClientToScreen(editor.root.hwnd.load(moAcquire), addr origin)
  let before = snapshots[editor]
  let after = Snapshot(id: before.id, text: copyWide(text), first: first, last: last,
    visibleFirst: visibleFirst, visibleLast: visibleLast,
    bounds: UiaRect(x: origin.x.cdouble + x, y: origin.y.cdouble + y, width: width, height: height),
    editable: editable != 0, focused: focused != 0, published: true)
  snapshots[editor] = after
  discard retain(editor)
  defer: discard releaseNode(editor)
  if not before.published: changed(editor.root)
  if UiaClientsAreListening() != 0:
    if after.focused and not before.focused:
      discard UiaRaiseAutomationEvent(addr editor.simple, 20005)
    if before.text != after.text:
      discard UiaRaiseAutomationEvent(addr editor.simple, 20015)
      var oldValue = stringVariant(before.text)
      var newValue = stringVariant(after.text)
      discard UiaRaiseAutomationPropertyChangedEvent(addr editor.simple, 30045, oldValue, newValue)
      discard VariantClear(addr oldValue)
      discard VariantClear(addr newValue)
    if before.text != after.text or before.first != first or before.last != last:
      discard UiaRaiseAutomationEvent(addr editor.simple, 20014)
    if before.bounds != after.bounds:
      var oldBounds = boundsVariant(before.bounds)
      var newBounds = boundsVariant(after.bounds)
      discard UiaRaiseAutomationPropertyChangedEvent(addr editor.simple, 30001, oldBounds, newBounds)
      discard VariantClear(addr oldBounds)
      discard VariantClear(addr newBounds)

proc windyTextObject*(provider: pointer, wparam, lparam: int): int =
  let root = cast[ptr Node](provider)
  if root != nil:
    let hwnd = root.hwnd.load(moAcquire)
    if hwnd != 0:
      return UiaReturnRawElementProvider(hwnd, wparam, lparam, addr root.simple)
