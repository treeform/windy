import ../../common, vmath

type
  Window* = ref object
    onCloseRequest*: Callback
    onMove*: Callback
    onResize*: Callback
    onFocusChange*: Callback
    onMouseMove*: Callback
    onScroll*: Callback
    onButtonPress*: ButtonCallback
    onButtonRelease*: ButtonCallback
    onRune*: RuneCallback
    onImeChange*: Callback

proc title*(window: Window): string =
  discard

proc closed*(window: Window): bool =
  discard

proc visible*(window: Window): bool =
  discard

proc decorated*(window: Window): bool =
  discard

proc resizable*(window: Window): bool =
  discard

proc fullscreen*(window: Window): bool =
  discard

proc size*(window: Window): IVec2 =
  discard

proc pos*(window: Window): IVec2 =
  discard

proc minimized*(window: Window): bool =
  discard

proc maximized*(window: Window): bool =
  discard

proc framebufferSize*(window: Window): IVec2 =
  discard

proc contentScale*(window: Window): float32 =
  discard

proc focused*(window: Window): bool =
  discard

proc mousePos*(window: Window): IVec2 =
  discard

proc mousePrevPos*(window: Window): IVec2 =
  discard

proc mouseDelta*(window: Window): IVec2 =
  discard

proc scrollDelta*(window: Window): Vec2 =
  discard

proc closeRequested*(window: Window): bool =
  discard

proc imeCursorIndex*(window: Window): int =
  discard

proc imeCompositionString*(window: Window): string =
  discard

proc runeInputEnabled*(window: Window): bool =
  discard

proc `title=`*(window: Window, title: string) =
  discard

proc `visible=`*(window: Window, visible: bool) =
  discard

proc `decorated=`*(window: Window, decorated: bool) =
  discard

proc `resizable=`*(window: Window, resizable: bool) =
  discard

proc `fullscreen=`*(window: Window, fullscreen: bool) =
  discard

proc `size=`*(window: Window, size: IVec2) =
  discard

proc `pos=`*(window: Window, pos: IVec2) =
  discard

proc `minimized=`*(window: Window, minimized: bool) =
  discard

proc `maximized=`*(window: Window, maximized: bool) =
  discard

proc `closeRequested=`*(window: Window, closeRequested: bool) =
  discard

proc `runeInputEnabled=`*(window: Window, runeInputEnabled: bool) =
  discard

proc init*() =
  discard

proc pollEvents*() =
  discard

proc makeContextCurrent*(window: Window) =
  discard

proc swapBuffers*(window: Window) =
  discard

proc close*(window: Window) =
  discard

proc closeIme*(window: Window) =
  discard

proc newWindow*(
  title: string,
  size: IVec2,
  visible = true,
  vsync = true,
  openglMajorVersion = 4,
  openglMinorVersion = 1,
  msaa = msaaDisabled,
  depthBits = 24,
  stencilBits = 8
): Window =
  discard
  # @levovix0, you noted in the x11 file that window constructor can't set
  # opengl version, msaa and stencilBits and args mustn't set depthBits directly

  # I am curious why this is, and if we can work to make those parameters work?
  # If Discord would be easier, you can add me as guzba#7261

proc buttonDown*(window: Window): ButtonView =
  discard

proc buttonPressed*(window: Window): ButtonView =
  discard

proc buttonReleased*(window: Window): ButtonView =
  discard

proc buttonToggle*(window: Window): ButtonView =
  discard

proc getClipboardString*(): string =
  discard

proc setClipboardString*(value: string) =
  discard
