import opengl, windy

proc run() =
  ## Draws only after input or resize while native waiting keeps the app idle.
  let window = newWindow("On demand: press Space", ivec2(800, 600))
  defer:
    window.close()
  window.makeContextCurrent()
  loadExtensions()
  var
    dirty = true
    alternate = false
  window.onResize = proc() =
    ## Schedules a redraw after the native framebuffer changes.
    dirty = true
  window.onButtonPress = proc(button: Button) =
    ## Marks application state dirty when its visible value changes.
    if button == KeySpace:
      alternate = not alternate
      dirty = true
  window.onFrame = proc() =
    ## Gates rendering because waitEvents still invokes every frame callback.
    if not dirty:
      return
    dirty = false
    if alternate:
      glClearColor(0.18, 0.28, 0.4, 1)
    else:
      glClearColor(0.12, 0.12, 0.14, 1)
    glClear(GL_COLOR_BUFFER_BIT)
    window.swapBuffers()
  while not window.closeRequested:
    waitEvents(1000)

run()
