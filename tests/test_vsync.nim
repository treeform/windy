## Run with a native graphics session. -d:vsyncTiming prints swap timings.
import windy

when defined(useCpu) or defined(useMetal4) or defined(useDirectX) or defined(useVulkan):
  let window = newWindow("VSync ownership", ivec2(160), visible = false)
  let before = window.vsync
  var rejected = false
  try: window.vsync = not before
  except WindyError: rejected = true
  doAssert rejected and window.vsync == before
  window.close()
  echo "Application-owned presentation rejected the VSync change"
elif defined(emscripten):
  let window = newWindow("Browser VSync", ivec2(160))
  for enabled in [false, true, false]:
    window.vsync = enabled
    doAssert window.vsync
else:
  import std/[importutils, monotimes, times]
  import opengl
  privateAccess(Window)
  when defined(macosx):
    import windy/platforms/macos/macdefs
    {.passL: "-framework OpenGL".}
    proc currentContext(): pointer {.importc: "CGLGetCurrentContext",
      header: "<OpenGL/OpenGL.h>".}
    proc readInterval(window: Window): int =
      var value: int32
      window.inner.contentView.NSOpenGLView.openGLContext.getValues(
        value.addr, NSOpenGLContextParameterSwapInterval)
      value.int
  elif defined(windows):
    import windy/platforms/win32/windefs
    proc currentContext(): pointer {.stdcall, importc: "wglGetCurrentContext",
      dynlib: "opengl32.dll".}
    proc address(name: cstring): pointer {.stdcall, importc: "wglGetProcAddress",
      dynlib: "opengl32.dll".}
    proc readInterval(window: Window): int =
      discard window
      let getInterval = cast[proc(): int32 {.stdcall.}](address("wglGetSwapIntervalEXT"))
      doAssert getInterval != nil
      getInterval().int
  else:
    import std/strutils
    import windy/platforms/linux/x11/[glx, xlib]
    proc currentContext(): pointer = glXGetCurrentContext()
    proc readInterval(window: Window): int =
      let display = glXGetCurrentDisplay()
      let extensions = strutils.splitWhitespace($display.glXQueryExtensionsString(display.defaultScreen))
      if "GLX_EXT_swap_control" in extensions:
        var value: cuint
        display.glXQueryDrawable(window.handle, 0x20F1, value.addr)
        value.int
      elif "GLX_MESA_swap_control" in extensions:
        glXGetSwapIntervalMESA().int
      else: -1 # SGI and servers without swap control cannot read back.

  let window = newWindow("VSync runtime test", ivec2(320, 200), vsync = false)
  let peer = newWindow("VSync peer", ivec2(160), vsync = false)
  for i in 0 ..< 60: pollEvents()
  window.makeContextCurrent()
  loadExtensions()
  for enabled in [false, true, false]:
    peer.makeContextCurrent()
    let previous = currentContext()
    try:
      window.vsync = enabled
    except WindyError:
      doAssert currentContext() == previous
      when defined(linux):
        doAssert enabled or window.vsync, "initial disabled state must work"
        echo "Driver cannot change VSync to ", enabled
        continue
      else: raise
    doAssert currentContext() == previous, "VSync must preserve the peer context"
    window.makeContextCurrent()
    let interval = window.readInterval()
    if interval >= 0:
      doAssert (interval != 0) == enabled
    doAssert window.vsync == enabled
    let start = getMonoTime()
    for frame in 0 ..< 30:
      glClearColor(if enabled: 0.0 else: 0.6, 0.3, 0.5, 1)
      glClear(GL_COLOR_BUFFER_BIT)
      window.swapBuffers()
      pollEvents()
    when defined(vsyncTiming):
      echo "vsync=", enabled, " driverInterval=", interval,
        " swaps=30 elapsedMs=", (getMonoTime() - start).inMilliseconds
    doAssert glGetError() == GL_NO_ERROR
  peer.close()
  window.close()
  echo "VSync context, supported intervals, and unsupported-change checks passed"
