// A single HWND-backed UIA editor, matching the focused-editor API on macOS.
// No Nim-managed objects are touched on COM worker threads. Read snapshots are
// protected by a lock; mutations are sent synchronously to the window thread.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <oleauto.h>
#include <algorithm>
#include <string>
#include <vector>
#include <cwctype>
#include <new>
#include <cstring>
#include "accessibility_bridge.h"

namespace {
// Stable UIA COM ABI declarations. Older MinGW SDKs shipped with Nim omit the
// text-provider interfaces; using the ABI keeps those toolchains supported.
struct Simple : IUnknown {
  virtual HRESULT STDMETHODCALLTYPE get_ProviderOptions(int *) = 0;
  virtual HRESULT STDMETHODCALLTYPE GetPatternProvider(int, IUnknown **) = 0;
  virtual HRESULT STDMETHODCALLTYPE GetPropertyValue(int, VARIANT *) = 0;
  virtual HRESULT STDMETHODCALLTYPE get_HostRawElementProvider(Simple **) = 0;
};
struct Value : IUnknown {
  virtual HRESULT STDMETHODCALLTYPE SetValue(LPCWSTR) = 0;
  virtual HRESULT STDMETHODCALLTYPE get_Value(BSTR *) = 0;
  virtual HRESULT STDMETHODCALLTYPE get_IsReadOnly(BOOL *) = 0;
};
struct Range;
// UIA's point uses doubles (unlike the Win32 POINT).
struct UiaPoint {
  double x, y;
};
struct UiaRect {
  double left, top, width, height;
};
struct FragmentRoot;
struct Fragment : IUnknown {
  virtual HRESULT STDMETHODCALLTYPE Navigate(int, Fragment **) = 0;
  virtual HRESULT STDMETHODCALLTYPE GetRuntimeId(SAFEARRAY **) = 0;
  virtual HRESULT STDMETHODCALLTYPE get_BoundingRectangle(UiaRect *) = 0;
  virtual HRESULT STDMETHODCALLTYPE GetEmbeddedFragmentRoots(SAFEARRAY **) = 0;
  virtual HRESULT STDMETHODCALLTYPE SetFocus() = 0;
  virtual HRESULT STDMETHODCALLTYPE get_FragmentRoot(FragmentRoot **) = 0;
};
struct FragmentRoot : Fragment {
  virtual HRESULT STDMETHODCALLTYPE ElementProviderFromPoint(double, double, Fragment **) = 0;
  virtual HRESULT STDMETHODCALLTYPE GetFocus(Fragment **) = 0;
};
struct TextProvider : IUnknown {
  virtual HRESULT STDMETHODCALLTYPE GetSelection(SAFEARRAY **) = 0;
  virtual HRESULT STDMETHODCALLTYPE GetVisibleRanges(SAFEARRAY **) = 0;
  virtual HRESULT STDMETHODCALLTYPE RangeFromChild(Simple *, Range **) = 0;
  virtual HRESULT STDMETHODCALLTYPE RangeFromPoint(UiaPoint, Range **) = 0;
  virtual HRESULT STDMETHODCALLTYPE get_DocumentRange(Range **) = 0;
  virtual HRESULT STDMETHODCALLTYPE get_SupportedTextSelection(int *) = 0;
};
struct Range : IUnknown {
  virtual HRESULT STDMETHODCALLTYPE Clone(Range **) = 0;
  virtual HRESULT STDMETHODCALLTYPE Compare(Range *, BOOL *) = 0;
  virtual HRESULT STDMETHODCALLTYPE CompareEndpoints(int, Range *, int, int *) = 0;
  virtual HRESULT STDMETHODCALLTYPE ExpandToEnclosingUnit(int) = 0;
  virtual HRESULT STDMETHODCALLTYPE FindAttribute(int, VARIANT, BOOL, Range **) = 0;
  virtual HRESULT STDMETHODCALLTYPE FindText(BSTR, BOOL, BOOL, Range **) = 0;
  virtual HRESULT STDMETHODCALLTYPE GetAttributeValue(int, VARIANT *) = 0;
  virtual HRESULT STDMETHODCALLTYPE GetBoundingRectangles(SAFEARRAY **) = 0;
  virtual HRESULT STDMETHODCALLTYPE GetEnclosingElement(Simple **) = 0;
  virtual HRESULT STDMETHODCALLTYPE GetText(int, BSTR *) = 0;
  virtual HRESULT STDMETHODCALLTYPE Move(int, int, int *) = 0;
  virtual HRESULT STDMETHODCALLTYPE MoveEndpointByUnit(int, int, int, int *) = 0;
  virtual HRESULT STDMETHODCALLTYPE MoveEndpointByRange(int, Range *, int) = 0;
  virtual HRESULT STDMETHODCALLTYPE Select() = 0;
  virtual HRESULT STDMETHODCALLTYPE AddToSelection() = 0;
  virtual HRESULT STDMETHODCALLTYPE RemoveFromSelection() = 0;
  virtual HRESULT STDMETHODCALLTYPE ScrollIntoView(BOOL) = 0;
  virtual HRESULT STDMETHODCALLTYPE GetChildren(SAFEARRAY **) = 0;
};
const IID simpleId = {0xd6dd68d1, 0x86fd, 0x4332, {0x86, 0x66, 0x9a, 0xbe, 0xde, 0xa2, 0xd2, 0x4c}};
const IID valueId = {0xc7935180, 0x6fb3, 0x4201, {0xb1, 0x74, 0x7d, 0xf7, 0x3a, 0xdb, 0xf6, 0x4a}};
const IID textId = {0x3589c92c, 0x63f3, 0x4367, {0x99, 0xbb, 0xad, 0xa6, 0x53, 0xb7, 0x7c, 0xf2}};
const IID rangeId = {0x5347ad7b, 0xc355, 0x46f8, {0xaf, 0xf5, 0x90, 0x90, 0x33, 0x58, 0x2f, 0x63}};
const IID fragmentId = {
    0xf7063da8, 0x8359, 0x439c, {0x92, 0x97, 0xbb, 0xc5, 0x29, 0x9a, 0x7d, 0x87}};
const IID rootId = {0x620ce2a5, 0xab8f, 0x40a9, {0x86, 0xcb, 0xde, 0x3c, 0x75, 0x59, 0x9b, 0x58}};
const IID unknownId = {0, 0, 0, {0xc0, 0, 0, 0, 0, 0, 0, 0x46}};
constexpr HRESULT unavailable = static_cast<HRESULT>(0x80040201);
constexpr HRESULT invalidOperation = static_cast<HRESULT>(0x80131509);
constexpr UINT editMessage = WM_APP + 2;

template <class T> void loadFunction(HMODULE module, const char *name, T &target) {
  FARPROC address = GetProcAddress(module, name);
  static_assert(sizeof(address) == sizeof(target), "Windows function pointer ABI");
  std::memcpy(&target, &address, sizeof(target));
}
struct Api {
  LRESULT(WINAPI *returnProvider)(HWND, WPARAM, LPARAM, Simple *) = nullptr;
  HRESULT(WINAPI *hostProvider)(HWND, Simple **) = nullptr;
  HRESULT(WINAPI *raiseEvent)(Simple *, int) = nullptr;
  HRESULT(WINAPI *raiseProperty)(Simple *, int, VARIANT, VARIANT) = nullptr;
  HRESULT(WINAPI *raiseStructure)(Simple *, int, int *, int) = nullptr;
  HRESULT(WINAPI *notSupported)(IUnknown **) = nullptr;
  HRESULT(WINAPI *disconnect)(Simple *) = nullptr;
  BOOL(WINAPI *clientsListening)() = nullptr;
  Api() {
    HMODULE module = LoadLibraryExW(L"UIAutomationCore.dll", nullptr, 0x800);
    if (!module)
      return;
#define LOAD(member, name) loadFunction(module, name, member)
    LOAD(returnProvider, "UiaReturnRawElementProvider");
    LOAD(hostProvider, "UiaHostProviderFromHwnd");
    LOAD(raiseEvent, "UiaRaiseAutomationEvent");
    LOAD(raiseProperty, "UiaRaiseAutomationPropertyChangedEvent");
    LOAD(raiseStructure, "UiaRaiseStructureChangedEvent");
    LOAD(notSupported, "UiaGetReservedNotSupportedValue");
    LOAD(disconnect, "UiaDisconnectProvider");
    LOAD(clientsListening, "UiaClientsAreListening");
#undef LOAD
  }
};
Api &api() {
  static Api value;
  return value;
}

struct Snapshot {
  HWND hwnd = nullptr;
  std::wstring id, text;
  int first = 0, last = 0, visibleFirst = 0, visibleLast = 0;
  double x = 0, y = 0, width = 0, height = 0;
  bool editable = false, focused = false;
};
struct EditRequest {
  int kind, first, last;
  const wchar_t *text;
  HRESULT result = unavailable;
  EditRequest(int kind, int first, int last, const wchar_t *text)
      : kind(kind), first(first), last(last), text(text) {}
};
struct Lock {
  CRITICAL_SECTION &value;
  Lock(CRITICAL_SECTION &value) : value(value) { EnterCriticalSection(&value); }
  ~Lock() { LeaveCriticalSection(&value); }
};
int bound(int value, int maximum) { return std::max(0, std::min(value, maximum)); }
bool high(wchar_t c) { return c >= 0xd800 && c <= 0xdbff; }
bool low(wchar_t c) { return c >= 0xdc00 && c <= 0xdfff; }
int boundary(const std::wstring &text, int index, bool up = false) {
  index = bound(index, static_cast<int>(text.size()));
  if (index > 0 && index < static_cast<int>(text.size()) && high(text[index - 1]) &&
      low(text[index]))
    index += up ? 1 : -1;
  return index;
}
SAFEARRAY *doubles(const std::vector<double> &values) {
  SAFEARRAY *result = SafeArrayCreateVector(VT_R8, 0, static_cast<ULONG>(values.size()));
  if (result)
    for (LONG i = 0; i < static_cast<LONG>(values.size()); ++i)
      SafeArrayPutElement(result, &i, const_cast<double *>(&values[i]));
  return result;
}
class TextRange;
class Editor;
class Root final : public Simple, public FragmentRoot {
  LONG refs = 1;
  CRITICAL_SECTION mutex;
  HWND hwnd;
  Editor *child = nullptr; // Weak; cleared on the UI thread before owner Release.
public:
  Root(HWND hwnd) : hwnd(hwnd) { InitializeCriticalSection(&mutex); }
  ~Root() { DeleteCriticalSection(&mutex); }
  HWND handle() {
    Lock lock(mutex);
    return hwnd;
  }
  void disconnect() {
    Lock lock(mutex);
    hwnd = nullptr;
    child = nullptr;
  }
  void attach(Editor *value) {
    Lock lock(mutex);
    child = value;
  }
  void changed() {
    if (api().raiseStructure && api().clientsListening && api().clientsListening())
      api().raiseStructure(this, 2, nullptr, 0); // ChildrenInvalidated
  }
  Editor *getChild();
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID id, void **out) override {
    if (!out)
      return E_POINTER;
    *out = nullptr;
    if (IsEqualIID(id, unknownId) || IsEqualIID(id, simpleId))
      *out = static_cast<Simple *>(this);
    else if (IsEqualIID(id, fragmentId) || IsEqualIID(id, rootId))
      *out = static_cast<FragmentRoot *>(this);
    else
      return E_NOINTERFACE;
    AddRef();
    return S_OK;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return InterlockedIncrement(&refs); }
  ULONG STDMETHODCALLTYPE Release() override {
    ULONG n = InterlockedDecrement(&refs);
    if (!n)
      delete this;
    return n;
  }
  HRESULT STDMETHODCALLTYPE get_ProviderOptions(int *out) override {
    if (!out)
      return E_POINTER;
    *out = 2;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE GetPatternProvider(int, IUnknown **out) override {
    if (!out)
      return E_POINTER;
    *out = nullptr;
    return handle() ? S_OK : unavailable;
  }
  HRESULT STDMETHODCALLTYPE GetPropertyValue(int, VARIANT *out) override {
    if (!out)
      return E_POINTER;
    VariantInit(out);
    return handle() ? S_OK : unavailable;
  }
  HRESULT STDMETHODCALLTYPE get_HostRawElementProvider(Simple **out) override {
    if (!out)
      return E_POINTER;
    *out = nullptr;
    HWND h = handle();
    return h ? api().hostProvider(h, out) : unavailable;
  }
  HRESULT STDMETHODCALLTYPE Navigate(int direction, Fragment **out) override;
  HRESULT STDMETHODCALLTYPE GetRuntimeId(SAFEARRAY **out) override {
    if (!out)
      return E_POINTER;
    *out = nullptr;
    return handle() ? S_OK : unavailable;
  }
  HRESULT STDMETHODCALLTYPE get_BoundingRectangle(UiaRect *out) override {
    if (!out)
      return E_POINTER;
    *out = UiaRect{};
    HWND h = handle();
    if (!h)
      return unavailable;
    RECT r{};
    GetWindowRect(h, &r);
    *out =
        UiaRect{double(r.left), double(r.top), double(r.right - r.left), double(r.bottom - r.top)};
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE GetEmbeddedFragmentRoots(SAFEARRAY **out) override {
    if (!out)
      return E_POINTER;
    *out = nullptr;
    return handle() ? S_OK : unavailable;
  }
  HRESULT STDMETHODCALLTYPE SetFocus() override {
    HWND h = handle();
    if (!h)
      return unavailable;
    return SendMessageW(h, WM_APP + 3, 0, 0) ? S_OK : invalidOperation;
  }
  HRESULT STDMETHODCALLTYPE get_FragmentRoot(FragmentRoot **out) override {
    if (!out)
      return E_POINTER;
    *out = nullptr;
    if (!handle())
      return unavailable;
    *out = this;
    AddRef();
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE ElementProviderFromPoint(double x, double y, Fragment **out) override;
  HRESULT STDMETHODCALLTYPE GetFocus(Fragment **out) override;
};
LONG nextEditorId = 0;
class Editor final : public Simple, public Value, public TextProvider, public Fragment {
  LONG refs = 1;
  CRITICAL_SECTION mutex;
  Snapshot state;
  bool published = false;

public:
  Root *root;
  LONG runtimeId;
  Editor(Root *root, const wchar_t *id)
      : root(root), runtimeId(InterlockedIncrement(&nextEditorId)) {
    InitializeCriticalSection(&mutex);
    root->AddRef();
    state.hwnd = root->handle();
    state.id = id;
  }
  ~Editor() {
    root->Release();
    DeleteCriticalSection(&mutex);
  }
  bool snapshot(Snapshot &out) {
    Lock lock(mutex);
    out = state;
    return state.hwnd != nullptr;
  }
  HWND handle() {
    Lock lock(mutex);
    return state.hwnd;
  }
  void disconnect() {
    Lock lock(mutex);
    state = Snapshot();
  }
  void publish(const wchar_t *, int, int, int, int, double, double, double, double, bool, bool);
  HRESULT edit(int kind, int first, int last, const wchar_t *text = nullptr) {
    HWND hwnd = handle();
    if (!hwnd)
      return unavailable;
    EditRequest request{kind, first, last, text};
    // Never hold the snapshot lock while dispatching to Windy's UI thread.
    SendMessageW(hwnd, editMessage, reinterpret_cast<WPARAM>(this),
                 reinterpret_cast<LPARAM>(&request));
    return request.result;
  }
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID id, void **out) override {
    if (!out)
      return E_POINTER;
    *out = nullptr;
    if (IsEqualIID(id, unknownId) || IsEqualIID(id, simpleId))
      *out = static_cast<Simple *>(this);
    else if (IsEqualIID(id, valueId))
      *out = static_cast<Value *>(this);
    else if (IsEqualIID(id, textId))
      *out = static_cast<TextProvider *>(this);
    else if (IsEqualIID(id, fragmentId))
      *out = static_cast<Fragment *>(this);
    else
      return E_NOINTERFACE;
    AddRef();
    return S_OK;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return InterlockedIncrement(&refs); }
  ULONG STDMETHODCALLTYPE Release() override {
    ULONG count = InterlockedDecrement(&refs);
    if (!count)
      delete this;
    return count;
  }
  HRESULT STDMETHODCALLTYPE get_ProviderOptions(int *out) override {
    if (!out)
      return E_POINTER;
    *out = 2;
    return S_OK; // ServerSideProvider
  }
  HRESULT STDMETHODCALLTYPE GetPatternProvider(int id, IUnknown **out) override {
    if (!out)
      return E_POINTER;
    *out = nullptr;
    if (!handle())
      return unavailable;
    if (id == 10002)
      *out = static_cast<Value *>(this);
    if (id == 10014)
      *out = static_cast<TextProvider *>(this);
    if (*out)
      AddRef();
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE GetPropertyValue(int id, VARIANT *out) override {
    if (!out)
      return E_POINTER;
    VariantInit(out);
    Snapshot s;
    if (!snapshot(s))
      return unavailable;
    switch (id) {
    case 30003:
      out->vt = VT_I4;
      out->lVal = 50004;
      break; // Edit
    case 30005:
      out->vt = VT_BSTR;
      out->bstrVal = SysAllocString(L"Text input");
      break;
    case 30011:
      out->vt = VT_BSTR;
      out->bstrVal = SysAllocString(s.id.c_str());
      break;
    case 30024:
      out->vt = VT_BSTR;
      out->bstrVal = SysAllocString(L"Windy");
      break;
    case 30008:
      out->vt = VT_BOOL;
      out->boolVal = s.focused ? VARIANT_TRUE : VARIANT_FALSE;
      break;
    case 30009:
    case 30010:
    case 30016:
    case 30017:
    case 30043:
    case 30040:
      out->vt = VT_BOOL;
      out->boolVal = VARIANT_TRUE;
      break;
    case 30019:
      out->vt = VT_BOOL;
      out->boolVal = VARIANT_FALSE;
      break;
    case 30022:
      out->vt = VT_BOOL;
      out->boolVal = (s.width <= 0 || s.height <= 0) ? VARIANT_TRUE : VARIANT_FALSE;
      break;
    case 30045:
      out->vt = VT_BSTR;
      out->bstrVal = SysAllocStringLen(s.text.data(), static_cast<UINT>(s.text.size()));
      break;
    case 30046:
      out->vt = VT_BOOL;
      out->boolVal = s.editable ? VARIANT_FALSE : VARIANT_TRUE;
      break;
    case 30001:
      out->vt = VT_ARRAY | VT_R8;
      out->parray = doubles({s.x, s.y, s.width, s.height});
      break;
    }
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE get_HostRawElementProvider(Simple **out) override {
    if (!out)
      return E_POINTER;
    *out = nullptr;
    return handle() ? S_OK : unavailable; // Only the root has an HWND.
  }
  HRESULT STDMETHODCALLTYPE Navigate(int direction, Fragment **out) override {
    if (!out)
      return E_POINTER;
    *out = nullptr;
    if (!handle())
      return unavailable;
    if (direction == 0) {
      *out = static_cast<FragmentRoot *>(root);
      root->AddRef();
    }
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE GetRuntimeId(SAFEARRAY **out) override {
    if (!out)
      return E_POINTER;
    *out = nullptr;
    if (!handle())
      return unavailable;
    *out = SafeArrayCreateVector(VT_I4, 0, 2);
    if (!*out)
      return E_OUTOFMEMORY;
    LONG index = 0, value = 3;
    SafeArrayPutElement(*out, &index, &value);
    index = 1;
    value = runtimeId;
    SafeArrayPutElement(*out, &index, &value);
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE get_BoundingRectangle(UiaRect *out) override {
    if (!out)
      return E_POINTER;
    *out = UiaRect{};
    Snapshot s;
    if (!snapshot(s))
      return unavailable;
    *out = UiaRect{s.x, s.y, s.width, s.height};
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE GetEmbeddedFragmentRoots(SAFEARRAY **out) override {
    if (!out)
      return E_POINTER;
    *out = nullptr;
    return handle() ? S_OK : unavailable;
  }
  HRESULT STDMETHODCALLTYPE SetFocus() override {
    return handle() ? root->SetFocus() : unavailable;
  }
  HRESULT STDMETHODCALLTYPE get_FragmentRoot(FragmentRoot **out) override {
    if (!out)
      return E_POINTER;
    *out = nullptr;
    if (!handle())
      return unavailable;
    *out = root;
    root->AddRef();
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE SetValue(LPCWSTR value) override {
    if (!value)
      return E_INVALIDARG;
    return edit(0, 0, -1, value);
  }
  HRESULT STDMETHODCALLTYPE get_Value(BSTR *out) override {
    if (!out)
      return E_POINTER;
    *out = nullptr;
    Snapshot s;
    if (!snapshot(s))
      return unavailable;
    *out = SysAllocStringLen(s.text.data(), static_cast<UINT>(s.text.size()));
    return *out ? S_OK : E_OUTOFMEMORY;
  }
  HRESULT STDMETHODCALLTYPE get_IsReadOnly(BOOL *out) override {
    if (!out)
      return E_POINTER;
    Snapshot s;
    if (!snapshot(s))
      return unavailable;
    *out = !s.editable;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE GetSelection(SAFEARRAY **) override;
  HRESULT STDMETHODCALLTYPE GetVisibleRanges(SAFEARRAY **) override;
  HRESULT STDMETHODCALLTYPE get_DocumentRange(Range **) override;
  HRESULT STDMETHODCALLTYPE RangeFromChild(Simple *, Range **out) override {
    if (!out)
      return E_POINTER;
    *out = nullptr;
    return E_INVALIDARG;
  }
  HRESULT STDMETHODCALLTYPE RangeFromPoint(UiaPoint, Range **out) override {
    // TextInputState has field bounds, but no per-character hit-test geometry.
    if (!out)
      return E_POINTER;
    *out = nullptr;
    return E_NOTIMPL;
  }
  HRESULT STDMETHODCALLTYPE get_SupportedTextSelection(int *out) override {
    if (!out)
      return E_POINTER;
    *out = 1;
    return handle() ? S_OK : unavailable;
  }
};

Editor *Root::getChild() {
  Lock lock(mutex);
  if (child)
    child->AddRef();
  return child;
}
HRESULT Root::Navigate(int direction, Fragment **out) {
  if (!out)
    return E_POINTER;
  *out = nullptr;
  if (!handle())
    return unavailable;
  if (direction == 3 || direction == 4)
    *out = getChild();
  return S_OK;
}
HRESULT Root::GetFocus(Fragment **out) {
  if (!out)
    return E_POINTER;
  *out = nullptr;
  if (!handle())
    return unavailable;
  auto editor = getChild();
  if (editor) {
    Snapshot s;
    if (editor->snapshot(s) && s.focused)
      *out = editor;
    else
      editor->Release();
  }
  return S_OK;
}
HRESULT Root::ElementProviderFromPoint(double x, double y, Fragment **out) {
  if (!out)
    return E_POINTER;
  *out = nullptr;
  if (!handle())
    return unavailable;
  auto editor = getChild();
  if (editor) {
    Snapshot s;
    if (editor->snapshot(s) && x >= s.x && y >= s.y && x < s.x + s.width && y < s.y + s.height)
      *out = editor;
    else
      editor->Release();
  }
  if (!*out) {
    *out = this;
    AddRef();
  }
  return S_OK;
}

// Unit boundaries use UTF-16 indices, but never split a surrogate pair.
std::vector<int> units(const std::wstring &text, int unit) {
  if (unit == 1)
    unit = 2; // Plain text has no format runs; use the next unit.
  std::vector<int> result{0};
  int size = static_cast<int>(text.size());
  for (int i = 1; i < size; ++i) {
    if (high(text[i - 1]) && low(text[i]))
      continue;
    if ((unit == 0) || (unit == 2 && iswspace(text[i - 1]) && !iswspace(text[i])) ||
        ((unit == 3 || unit == 4) && text[i - 1] == L'\n'))
      result.push_back(i);
  }
  if (size)
    result.push_back(size);
  return result;
}
class TextRange final : public Range {
  LONG refs = 1;
  CRITICAL_SECTION mutex;
  struct PairLock {
    CRITICAL_SECTION *a, *b;
    PairLock(TextRange *left, TextRange *right) {
      // One total order prevents opposite Compare/Move calls deadlocking.
      if (reinterpret_cast<uintptr_t>(left) < reinterpret_cast<uintptr_t>(right)) {
        a = &left->mutex;
        b = &right->mutex;
      } else {
        a = &right->mutex;
        b = &left->mutex;
      }
      EnterCriticalSection(a);
      EnterCriticalSection(b);
    }
    ~PairLock() {
      LeaveCriticalSection(b);
      LeaveCriticalSection(a);
    }
  };

public:
  Editor *editor;
  int first, last;
  TextRange(Editor *editor, int first, int last) : editor(editor), first(first), last(last) {
    InitializeCriticalSection(&mutex);
    editor->AddRef();
  }
  ~TextRange() {
    editor->Release();
    DeleteCriticalSection(&mutex);
  }
  bool read(Snapshot &s) {
    if (!editor->snapshot(s))
      return false;
    first = boundary(s.text, first);
    last = std::max(first, boundary(s.text, last, last > first));
    return true;
  }
  TextRange *peer(Range *other) {
    // All ranges exchanged by this implementation share our vtable.
    if (!other ||
        *reinterpret_cast<void **>(other) != *reinterpret_cast<void **>(static_cast<Range *>(this)))
      return nullptr;
    auto value = static_cast<TextRange *>(other);
    return value->editor == editor ? value : nullptr;
  }
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID id, void **out) override {
    if (!out)
      return E_POINTER;
    *out = nullptr;
    if (!IsEqualIID(id, unknownId) && !IsEqualIID(id, rangeId))
      return E_NOINTERFACE;
    *out = static_cast<Range *>(this);
    AddRef();
    return S_OK;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return InterlockedIncrement(&refs); }
  ULONG STDMETHODCALLTYPE Release() override {
    ULONG n = InterlockedDecrement(&refs);
    if (!n)
      delete this;
    return n;
  }
  HRESULT STDMETHODCALLTYPE Clone(Range **out) override {
    Lock lock(mutex);
    if (!out)
      return E_POINTER;
    *out = nullptr;
    Snapshot s;
    if (!read(s))
      return unavailable;
    *out = new (std::nothrow) TextRange(editor, first, last);
    return *out ? S_OK : E_OUTOFMEMORY;
  }
  HRESULT STDMETHODCALLTYPE Compare(Range *other, BOOL *out) override {
    if (!out)
      return E_POINTER;
    *out = FALSE;
    auto p = peer(other);
    if (!p)
      return E_INVALIDARG;
    PairLock lock(this, p);
    Snapshot s;
    if (!read(s) || !p->read(s))
      return unavailable;
    *out = first == p->first && last == p->last;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE CompareEndpoints(int endpoint, Range *other, int target,
                                             int *out) override {
    if (!out)
      return E_POINTER;
    *out = 0;
    auto p = peer(other);
    if (!p || endpoint < 0 || endpoint > 1 || target < 0 || target > 1)
      return E_INVALIDARG;
    PairLock lock(this, p);
    Snapshot s;
    if (!read(s) || !p->read(s))
      return unavailable;
    *out = (endpoint ? last : first) - (target ? p->last : p->first);
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE ExpandToEnclosingUnit(int unit) override {
    Lock lock(mutex);
    if (unit < 0 || unit > 6)
      return E_INVALIDARG;
    Snapshot s;
    if (!read(s))
      return unavailable;
    auto b = units(s.text, unit);
    if (b.size() == 1) {
      first = last = 0;
      return S_OK;
    }
    auto next = std::upper_bound(b.begin(), b.end(), first);
    if (next == b.end())
      --next;
    last = *next;
    first = *(next - 1);
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE FindAttribute(int, VARIANT, BOOL, Range **out) override {
    if (!out)
      return E_POINTER;
    *out = nullptr;
    return E_NOTIMPL;
  }
  HRESULT STDMETHODCALLTYPE FindText(BSTR text, BOOL backward, BOOL ignoreCase,
                                     Range **out) override {
    Lock lock(mutex);
    if (!out)
      return E_POINTER;
    *out = nullptr;
    if (!text || !SysStringLen(text))
      return E_INVALIDARG;
    Snapshot s;
    if (!read(s))
      return unavailable;
    std::wstring needle(text, SysStringLen(text)), haystack = s.text.substr(first, last - first);
    if (ignoreCase) {
      std::transform(needle.begin(), needle.end(), needle.begin(), towlower);
      std::transform(haystack.begin(), haystack.end(), haystack.begin(), towlower);
    }
    auto at = backward ? haystack.rfind(needle) : haystack.find(needle);
    if (at != std::wstring::npos)
      *out = new (std::nothrow) TextRange(editor, first + static_cast<int>(at),
                                          first + static_cast<int>(at + needle.size()));
    return at != std::wstring::npos && !*out ? E_OUTOFMEMORY : S_OK;
  }
  HRESULT STDMETHODCALLTYPE GetAttributeValue(int attribute, VARIANT *out) override {
    Lock lock(mutex);
    if (!out)
      return E_POINTER;
    VariantInit(out);
    Snapshot s;
    if (!read(s))
      return unavailable;
    if (attribute == 40015) {
      out->vt = VT_BOOL;
      out->boolVal = s.editable ? VARIANT_FALSE : VARIANT_TRUE;
      return S_OK;
    }
    out->vt = VT_UNKNOWN;
    return api().notSupported ? api().notSupported(&out->punkVal) : E_NOTIMPL;
  }
  HRESULT STDMETHODCALLTYPE GetBoundingRectangles(SAFEARRAY **out) override {
    Lock lock(mutex);
    if (!out)
      return E_POINTER;
    *out = nullptr;
    Snapshot s;
    if (!read(s))
      return unavailable;
    // Only whole-field geometry is published. Do not invent character bounds.
    *out = doubles(first <= s.visibleFirst && last >= s.visibleLast && first != last
                       ? std::vector<double>{s.x, s.y, s.width, s.height}
                       : std::vector<double>{});
    return *out ? S_OK : E_OUTOFMEMORY;
  }
  HRESULT STDMETHODCALLTYPE GetEnclosingElement(Simple **out) override {
    if (!out)
      return E_POINTER;
    *out = nullptr;
    if (!editor->handle())
      return unavailable;
    *out = static_cast<Simple *>(editor);
    editor->AddRef();
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE GetText(int maximum, BSTR *out) override {
    Lock lock(mutex);
    if (!out)
      return E_POINTER;
    *out = nullptr;
    if (maximum < -1)
      return E_INVALIDARG;
    Snapshot s;
    if (!read(s))
      return unavailable;
    int end = maximum < 0 ? last : first + std::min(last - first, maximum);
    end = boundary(s.text, end);
    *out = SysAllocStringLen(s.text.data() + first, end - first);
    return *out ? S_OK : E_OUTOFMEMORY;
  }
  HRESULT STDMETHODCALLTYPE Move(int unit, int count, int *out) override {
    Lock lock(mutex);
    if (!out)
      return E_POINTER;
    *out = 0;
    if (unit < 0 || unit > 6)
      return E_INVALIDARG;
    Snapshot s;
    if (!read(s))
      return unavailable;
    if (!count)
      return S_OK;
    bool collapsed = first == last;
    auto b = units(s.text, unit);
    if (b.size() == 1)
      return S_OK;
    int index = static_cast<int>(std::upper_bound(b.begin(), b.end(), first) - b.begin()) - 1;
    int maximum = static_cast<int>(b.size()) - (collapsed ? 1 : 2);
    index = std::min(index, maximum);
    int next = static_cast<int>(std::max(
        0LL, std::min(static_cast<long long>(maximum), static_cast<long long>(index) + count)));
    *out = next - index;
    first = b[next];
    last = collapsed ? first : b[next + 1];
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE MoveEndpointByUnit(int endpoint, int unit, int count,
                                               int *out) override {
    Lock lock(mutex);
    if (!out)
      return E_POINTER;
    *out = 0;
    if (endpoint < 0 || endpoint > 1 || unit < 0 || unit > 6)
      return E_INVALIDARG;
    Snapshot s;
    if (!read(s))
      return unavailable;
    if (!count)
      return S_OK;
    auto b = units(s.text, unit);
    int position = endpoint ? last : first;
    auto at = count > 0 ? std::upper_bound(b.begin(), b.end(), position)
                        : std::lower_bound(b.begin(), b.end(), position);
    int index = static_cast<int>(at - b.begin()) - (count > 0 ? 1 : 0);
    int next = static_cast<int>(std::max(0LL, std::min(static_cast<long long>(b.size() - 1),
                                                       static_cast<long long>(index) + count)));
    *out = next - index;
    if (endpoint) {
      last = b[next];
      first = std::min(first, last);
    } else {
      first = b[next];
      last = std::max(first, last);
    }
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE MoveEndpointByRange(int endpoint, Range *other, int target) override {
    auto p = peer(other);
    if (!p || endpoint < 0 || endpoint > 1 || target < 0 || target > 1)
      return E_INVALIDARG;
    PairLock lock(this, p);
    Snapshot s;
    if (!read(s) || !p->read(s))
      return unavailable;
    int position = target ? p->last : p->first;
    if (endpoint) {
      last = position;
      first = std::min(first, last);
    } else {
      first = position;
      last = std::max(first, last);
    }
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE Select() override {
    int start, end;
    {
      Lock lock(mutex);
      Snapshot s;
      if (!read(s))
        return unavailable;
      start = first;
      end = last;
    }
    return editor->edit(1, start, end);
  }
  HRESULT STDMETHODCALLTYPE AddToSelection() override { return invalidOperation; }
  HRESULT STDMETHODCALLTYPE RemoveFromSelection() override { return invalidOperation; }
  HRESULT STDMETHODCALLTYPE ScrollIntoView(BOOL) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE GetChildren(SAFEARRAY **out) override {
    if (!out)
      return E_POINTER;
    *out = nullptr;
    if (!editor->handle())
      return unavailable;
    *out = SafeArrayCreateVector(VT_UNKNOWN, 0, 0);
    return *out ? S_OK : E_OUTOFMEMORY;
  }
};
HRESULT rangeArray(Editor *editor, int first, int last, SAFEARRAY **out) {
  if (!out)
    return E_POINTER;
  *out = SafeArrayCreateVector(VT_UNKNOWN, 0, 1);
  if (!*out)
    return E_OUTOFMEMORY;
  auto range = new (std::nothrow) TextRange(editor, first, last);
  if (!range) {
    SafeArrayDestroy(*out);
    *out = nullptr;
    return E_OUTOFMEMORY;
  }
  LONG index = 0;
  HRESULT result = SafeArrayPutElement(*out, &index, static_cast<Range *>(range));
  range->Release();
  return result;
}
HRESULT Editor::GetSelection(SAFEARRAY **out) {
  if (!out)
    return E_POINTER;
  *out = nullptr;
  Snapshot s;
  if (!snapshot(s))
    return unavailable;
  return rangeArray(this, s.first, s.last, out);
}
HRESULT Editor::GetVisibleRanges(SAFEARRAY **out) {
  if (!out)
    return E_POINTER;
  *out = nullptr;
  Snapshot s;
  if (!snapshot(s))
    return unavailable;
  return rangeArray(this, s.visibleFirst, s.visibleLast, out);
}
HRESULT Editor::get_DocumentRange(Range **out) {
  if (!out)
    return E_POINTER;
  *out = nullptr;
  Snapshot s;
  if (!snapshot(s))
    return unavailable;
  *out = new (std::nothrow) TextRange(this, 0, static_cast<int>(s.text.size()));
  return *out ? S_OK : E_OUTOFMEMORY;
}
void Editor::publish(const wchar_t *text, int first, int last, int visibleFirst, int visibleLast,
                     double x, double y, double width, double height, bool editable, bool focused) {
  bool changed, selection, focus, moved, created;
  VARIANT before, after;
  VariantInit(&before);
  VariantInit(&after);
  bool listening = api().clientsListening && api().clientsListening();
  {
    Lock lock(mutex);
    created = !published;
    published = true;
    changed = state.text != text;
    selection = changed || first != state.first || last != state.last;
    focus = focused && !state.focused;
    moved = x != state.x || y != state.y || width != state.width || height != state.height;
    if (changed && listening) {
      before.vt = after.vt = VT_BSTR;
      before.bstrVal = SysAllocString(state.text.c_str());
      after.bstrVal = SysAllocString(text);
    }
    state.text = text;
    state.first = first;
    state.last = last;
    state.visibleFirst = visibleFirst;
    state.visibleLast = visibleLast;
    state.x = x;
    state.y = y;
    state.width = width;
    state.height = height;
    state.editable = editable;
    state.focused = focused;
  }
  // UIA may reenter while notifying. Never hold the lock across API calls.
  AddRef();
  if (created)
    root->changed();
  if (listening && api().raiseEvent) {
    if (focus)
      api().raiseEvent(this, 20005);
    if (changed)
      api().raiseEvent(this, 20015);
    if (selection)
      api().raiseEvent(this, 20014);
  }
  if (changed && listening && api().raiseProperty)
    api().raiseProperty(this, 30045, before, after);
  if (moved && listening && api().raiseProperty) {
    VARIANT empty, bounds;
    VariantInit(&empty);
    VariantInit(&bounds);
    GetPropertyValue(30001, &bounds);
    api().raiseProperty(this, 30001, empty, bounds);
    VariantClear(&bounds);
  }
  VariantClear(&before);
  VariantClear(&after);
  Release();
}
} // namespace

extern "C" void *windyTextRootCreate(intptr_t hwnd) {
  if (!api().returnProvider || !api().hostProvider)
    return nullptr;
  return new (std::nothrow) Root(reinterpret_cast<HWND>(hwnd));
}
extern "C" void windyTextRootDestroy(void *provider) {
  auto root = static_cast<Root *>(provider);
  if (!root)
    return;
  HWND hwnd = root->handle();
  root->disconnect();
  if (api().disconnect)
    api().disconnect(root);
  api().returnProvider(hwnd, 0, 0, nullptr);
  root->Release();
}
extern "C" void *windyTextCreate(void *provider, const uint16_t *id) {
  auto root = static_cast<Root *>(provider);
  if (!root)
    return nullptr;
  auto editor = new (std::nothrow) Editor(root, reinterpret_cast<const wchar_t *>(id));
  root->attach(editor);
  return editor;
}
extern "C" void windyTextDestroy(void *provider) {
  auto editor = static_cast<Editor *>(provider);
  if (!editor)
    return;
  editor->root->attach(nullptr);
  editor->disconnect();
  if (api().disconnect)
    api().disconnect(editor);
  editor->root->changed();
  editor->Release();
}
extern "C" void windyTextPublish(void *provider, const uint16_t *text, int first, int last,
                                 int visibleFirst, int visibleLast, double x, double y,
                                 double width, double height, int editable, int focused) {
  auto editor = static_cast<Editor *>(provider);
  if (!editor)
    return;
  POINT origin{0, 0};
  ClientToScreen(editor->handle(), &origin);
  editor->publish(reinterpret_cast<const wchar_t *>(text), first, last, visibleFirst, visibleLast,
                  origin.x + x, origin.y + y, width, height, editable != 0, focused != 0);
}
extern "C" intptr_t windyTextObject(void *provider, intptr_t wparam, intptr_t lparam) {
  auto root = static_cast<Root *>(provider);
  if (!root || static_cast<LONG>(lparam) != -25 || !root->handle())
    return 0;
  return api().returnProvider(root->handle(), wparam, lparam, root);
}
extern "C" intptr_t windyTextRequest(void *provider, intptr_t request, WindyTextEdit edit,
                                     void *context) {
  auto editor = static_cast<Editor *>(provider);
  auto operation = reinterpret_cast<EditRequest *>(request);
  if (!editor || !operation)
    return 0;
  Snapshot s;
  if (!editor->snapshot(s))
    return 0;
  if (!s.editable) {
    operation->result = invalidOperation;
    return 0;
  }
  // The UI thread owns and validates the active field before entering here.
  editor->AddRef();
  operation->result = edit(context, operation->kind, operation->first, operation->last,
                           reinterpret_cast<const uint16_t *>(operation->text))
                          ? S_OK
                          : invalidOperation;
  editor->Release();
  return 1;
}
