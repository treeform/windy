## Windows UI Automation's COM ABI. These definitions also work with the older
## MinGW headers distributed with Nim, which omit the text provider interfaces.
import windefs

type
  UiaGuid* = object
    a*: uint32
    b*, c*: uint16
    d*: array[8, uint8]

  UiaPoint* = object
    x*, y*: cdouble

  UiaRect* = object
    x*, y*, width*, height*: cdouble

  SafeArray* = object

  VariantData* {.union.} = object
    integer*: int32
    boolean*: int16
    number*: cdouble
    str*: ptr WCHAR
    arrayValue*: ptr SafeArray
    unknown*: pointer
    recordValue*: array[2, pointer]

  Variant* = object
    vt*, reserved1*, reserved2*, reserved3*: uint16
    data*: VariantData

  UnknownVtbl* = object
    queryInterface*: proc(self: pointer, iid: ptr UiaGuid, value: ptr pointer): HRESULT {.stdcall.}
    addRef*, release*: proc(self: pointer): uint32 {.stdcall.}

  SimpleVtbl* = object
    unknown*: UnknownVtbl
    providerOptions*: proc(self: pointer, value: ptr cint): HRESULT {.stdcall.}
    patternProvider*: proc(self: pointer, id: cint, value: ptr pointer): HRESULT {.stdcall.}
    propertyValue*: proc(self: pointer, id: cint, value: ptr Variant): HRESULT {.stdcall.}
    hostProvider*: proc(self: pointer, value: ptr pointer): HRESULT {.stdcall.}

  FragmentVtbl* = object
    unknown*: UnknownVtbl
    navigate*: proc(self: pointer, direction: cint, value: ptr pointer): HRESULT {.stdcall.}
    runtimeId*: proc(self: pointer, value: ptr ptr SafeArray): HRESULT {.stdcall.}
    boundingRectangle*: proc(self: pointer, value: ptr UiaRect): HRESULT {.stdcall.}
    embeddedRoots*: proc(self: pointer, value: ptr ptr SafeArray): HRESULT {.stdcall.}
    setFocus*: proc(self: pointer): HRESULT {.stdcall.}
    fragmentRoot*: proc(self: pointer, value: ptr pointer): HRESULT {.stdcall.}

  FragmentRootVtbl* = object
    unknown*: UnknownVtbl
    fromPoint*: proc(self: pointer, x, y: cdouble, value: ptr pointer): HRESULT {.stdcall.}
    getFocus*: proc(self: pointer, value: ptr pointer): HRESULT {.stdcall.}

  ValueVtbl* = object
    unknown*: UnknownVtbl
    setValue*: proc(self: pointer, value: ptr WCHAR): HRESULT {.stdcall.}
    getValue*: proc(self: pointer, value: ptr ptr WCHAR): HRESULT {.stdcall.}
    isReadOnly*: proc(self: pointer, value: ptr BOOL): HRESULT {.stdcall.}

  TextVtbl* = object
    unknown*: UnknownVtbl
    selection*, visibleRanges*: proc(self: pointer, value: ptr ptr SafeArray): HRESULT {.stdcall.}
    rangeFromChild*: proc(self, child: pointer, value: ptr pointer): HRESULT {.stdcall.}
    rangeFromPoint*: proc(self: pointer, point: UiaPoint, value: ptr pointer): HRESULT {.stdcall.}
    documentRange*: proc(self: pointer, value: ptr pointer): HRESULT {.stdcall.}
    supportedSelection*: proc(self: pointer, value: ptr cint): HRESULT {.stdcall.}

  RangeVtbl* = object
    unknown*: UnknownVtbl
    clone*: proc(self: pointer, value: ptr pointer): HRESULT {.stdcall.}
    compare*: proc(self, other: pointer, value: ptr BOOL): HRESULT {.stdcall.}
    compareEndpoints*: proc(self: pointer, endpoint: cint, other: pointer,
      targetEndpoint: cint, value: ptr cint): HRESULT {.stdcall.}
    expand*: proc(self: pointer, unit: cint): HRESULT {.stdcall.}
    findAttribute*: proc(self: pointer, id: cint, attribute: Variant,
      backward: BOOL, value: ptr pointer): HRESULT {.stdcall.}
    findText*: proc(self: pointer, text: ptr WCHAR, backward, ignoreCase: BOOL,
      value: ptr pointer): HRESULT {.stdcall.}
    attributeValue*: proc(self: pointer, id: cint, value: ptr Variant): HRESULT {.stdcall.}
    rectangles*: proc(self: pointer, value: ptr ptr SafeArray): HRESULT {.stdcall.}
    enclosingElement*: proc(self: pointer, value: ptr pointer): HRESULT {.stdcall.}
    getText*: proc(self: pointer, maximum: cint, value: ptr ptr WCHAR): HRESULT {.stdcall.}
    move*: proc(self: pointer, unit, count: cint, value: ptr cint): HRESULT {.stdcall.}
    moveEndpointByUnit*: proc(self: pointer, endpoint, unit, count: cint,
      value: ptr cint): HRESULT {.stdcall.}
    moveEndpointByRange*: proc(self: pointer, endpoint: cint, other: pointer,
      targetEndpoint: cint): HRESULT {.stdcall.}
    selectRange*, addToSelection*, removeFromSelection*: proc(self: pointer): HRESULT {.stdcall.}
    scrollIntoView*: proc(self: pointer, alignTop: BOOL): HRESULT {.stdcall.}
    children*: proc(self: pointer, value: ptr ptr SafeArray): HRESULT {.stdcall.}

static:
  doAssert sizeof(UiaGuid) == 16
  doAssert sizeof(Variant) == (if sizeof(pointer) == 8: 24 else: 16)
  doAssert offsetOf(Variant, data) == 8
  doAssert sizeof(FragmentVtbl) == 9 * sizeof(pointer)
  doAssert sizeof(FragmentRootVtbl) == 5 * sizeof(pointer)
  doAssert sizeof(RangeVtbl) == 21 * sizeof(pointer)

const
  iidUnknown* = UiaGuid(d: [0xc0'u8, 0, 0, 0, 0, 0, 0, 0x46])
  iidSimple* = UiaGuid(a: 0xd6dd68d1'u32, b: 0x86fd, c: 0x4332,
    d: [0x86'u8, 0x66, 0x9a, 0xbe, 0xde, 0xa2, 0xd2, 0x4c])
  iidFragment* = UiaGuid(a: 0xf7063da8'u32, b: 0x8359, c: 0x439c,
    d: [0x92'u8, 0x97, 0xbb, 0xc5, 0x29, 0x9a, 0x7d, 0x87])
  iidRoot* = UiaGuid(a: 0x620ce2a5'u32, b: 0xab8f, c: 0x40a9,
    d: [0x86'u8, 0xcb, 0xde, 0x3c, 0x75, 0x59, 0x9b, 0x58])
  iidValue* = UiaGuid(a: 0xc7935180'u32, b: 0x6fb3, c: 0x4201,
    d: [0xb1'u8, 0x74, 0x7d, 0xf7, 0x3a, 0xdb, 0xf6, 0x4a])
  iidText* = UiaGuid(a: 0x3589c92c'u32, b: 0x63f3, c: 0x4367,
    d: [0x99'u8, 0xbb, 0xad, 0xa6, 0x53, 0xb7, 0x7c, 0xf2])
  iidRange* = UiaGuid(a: 0x5347ad7b'u32, b: 0xc355, c: 0x46f8,
    d: [0xaf'u8, 0xf5, 0x90, 0x90, 0x33, 0x58, 0x2f, 0x63])

  uiaOk* = 0'i32
  uiaNoInterface* = cast[HRESULT](0x80004002'u32)
  uiaPointer* = cast[HRESULT](0x80004003'u32)
  uiaNotImplemented* = cast[HRESULT](0x80004001'u32)
  uiaOutOfMemory* = cast[HRESULT](0x8007000e'u32)
  uiaInvalidArg* = cast[HRESULT](0x80070057'u32)
  uiaUnavailable* = cast[HRESULT](0x80040201'u32)
  uiaInvalidOperation* = cast[HRESULT](0x80131509'u32)

  vtI4* = 3'u16
  vtR8* = 5'u16
  vtBstr* = 8'u16
  vtBool* = 11'u16
  vtUnknown* = 13'u16
  vtArray* = 0x2000'u16

{.push stdcall, importc, dynlib: "oleaut32.dll".}
proc SysAllocStringLen*(text: ptr WCHAR, length: uint32): ptr WCHAR
proc SysStringLen*(text: ptr WCHAR): uint32
proc VariantClear*(value: ptr Variant): HRESULT
proc SafeArrayCreateVector*(kind: uint16, lower: int32, length: uint32): ptr SafeArray
proc SafeArrayPutElement*(arrayValue: ptr SafeArray, index: ptr int32, value: pointer): HRESULT
proc SafeArrayDestroy*(value: ptr SafeArray): HRESULT
{.pop.}

{.push stdcall, importc, dynlib: "UIAutomationCore.dll".}
proc UiaReturnRawElementProvider*(hwnd: HWND, wparam: WPARAM, lparam: LPARAM,
  provider: pointer): LRESULT
proc UiaHostProviderFromHwnd*(hwnd: HWND, provider: ptr pointer): HRESULT
proc UiaRaiseAutomationEvent*(provider: pointer, id: cint): HRESULT
proc UiaRaiseAutomationPropertyChangedEvent*(provider: pointer, id: cint,
  before, after: Variant): HRESULT
proc UiaRaiseStructureChangedEvent*(provider: pointer, kind: cint,
  runtimeId: ptr cint, length: cint): HRESULT
proc UiaGetReservedNotSupportedValue*(value: ptr pointer): HRESULT
proc UiaDisconnectProvider*(provider: pointer): HRESULT
proc UiaClientsAreListening*(): BOOL
{.pop.}

{.push stdcall, importc, dynlib: "kernel32.dll".}
proc GetProcessHeap*(): HANDLE
proc HeapAlloc*(heap: HANDLE, flags: uint32, size: csize_t): pointer
proc HeapFree*(heap: HANDLE, flags: uint32, memory: pointer): BOOL
{.pop.}
