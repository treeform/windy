import
  std/os,
  opengl, windy

from pixie import rect

# Run with: nim c -r tests/manual_mouse_confinement.nim.
# Add --fullscreen to request fullscreen and confinement before the first poll.

proc main() =
  ## Runs the visible confinement and fullscreen smoke test.
  let window = newWindow("Mouse confinement", ivec2(960, 640))
  defer:
    window.releaseMouseConfinement()
    window.close()
  var
    requested = false
    wholeWindow = false
    region = rect(0, 0, 0, 0)
    previousTitle = ""
    framebufferHeight = window.size.y.int

  if "--fullscreen" in commandLineParams():
    window.fullscreen = true
    window.confineMouse()
    requested = true
    wholeWindow = true

  window.makeContextCurrent()
  loadExtensions()

  proc fillRect(x, y, width, height: int) =
    ## Draws an orange edge in top-left framebuffer pixels.
    glScissor(
      x.GLint,
      (framebufferHeight - y - height).GLint,
      width.GLsizei,
      height.GLsizei
    )
    glClear(GL_COLOR_BUFFER_BIT)

  window.onButtonPress = proc(button: Button) =
    ## Selects visible confinement or toggles borderless fullscreen.
    try:
      case button:
      of KeyF11:
        window.fullscreen = not window.fullscreen
      of KeyF1:
        window.confineMouse()
        requested = true
        wholeWindow = true
      of KeyF2:
        let size = window.size.vec2
        region = rect(size / 4, size / 2)
        window.confineMouse(region)
        requested = true
        wholeWindow = false
      of KeyEscape:
        window.releaseMouseConfinement()
        requested = false
      else:
        discard
    except WindyError as error:
      echo error.msg

  window.onFrame = proc() =
    ## Renders a blue field and the requested confinement boundary.
    let
      size = window.size
      mode =
        if not requested: "FREE"
        elif wholeWindow: "WHOLE WINDOW"
        else: "FIXED PIXEL RECTANGLE"
      active =
        if window.mouseConfined: "ACTIVE"
        elif requested: "SUSPENDED"
        else: "RELEASED"
      title = "F11 Fullscreen | F1 Window | F2 Rectangle | Esc Release | " &
        mode & " / " & active
    if title != previousTitle:
      window.title = title
      previousTitle = title
      echo mode, " / ", active
    framebufferHeight = size.y.int
    glViewport(0, 0, size.x.GLsizei, size.y.GLsizei)
    glDisable(GL_SCISSOR_TEST)
    glClearColor(0.04'f, 0.25'f, 0.72'f, 1.0'f)
    glClear(GL_COLOR_BUFFER_BIT)
    if requested:
      let
        bounds =
          if wholeWindow: rect(vec2(0, 0), size.vec2)
          else: region
        x = bounds.x.int
        y = bounds.y.int
        width = bounds.w.int
        height = bounds.h.int
      glEnable(GL_SCISSOR_TEST)
      glClearColor(1.0'f, 0.75'f, 0.12'f, 1.0'f)
      fillRect(x, y, width, 3)
      fillRect(x, y + height - 3, width, 3)
      fillRect(x, y, 3, height)
      fillRect(x + width - 3, y, 3, height)
      glDisable(GL_SCISSOR_TEST)
    window.swapBuffers()

  echo "F11: Fullscreen. F1: Window. F2: Rectangle. Escape: Release."
  echo "Orange edges show the requested region in framebuffer pixels."
  echo "F1: Try every edge, toggle fullscreen twice, and check the new edges."
  echo "F2: Try every orange edge. This rectangle stays fixed on resize."
  echo "Switch apps: confinement should suspend, then return when focused."
  echo "The normal cursor should stay visible. Close the window to exit."
  echo "Confinement supported: ", window.mouseConfinementSupported
  while not window.closeRequested:
    if window.minimized or not window.visible:
      sleep(10)
    pollEvents()

main()
