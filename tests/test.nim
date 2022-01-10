import unittest
import windy, opengl

import std/monotimes


proc nowMs(): float64 =
  ## Gets current milliseconds.
  getMonoTime().ticks.float64 / 1000000.0


template displayLoop(window: Window, duration: int, body: untyped) =
  block:
    proc loopBody() =
      body

    let start = nowMs()

    while not window.closeRequested:
      loopBody()
      pollEvents()

      let delta = nowMs() - start
      if delta > duration:
        break


test "set and get fullscreen property":

  let window = newWindow("Windy Example", ivec2(1280, 800))

  window.makeContextCurrent()
  loadExtensions()

  proc display() =
    glClear(GL_COLOR_BUFFER_BIT)
    window.swapBuffers()

  window.fullscreen = false
  displayLoop(window, 1000):
     display()
  doAssert not window.fullscreen

  window.fullscreen = true
  displayLoop(window, 1000):
     display()
  doAssert window.fullscreen

  window.fullscreen = false
  displayLoop(window, 1000):
     display()
  doAssert not window.fullscreen


test "set and get maximized property":

  let window = newWindow("Windy Example", ivec2(1280, 800))

  window.makeContextCurrent()
  loadExtensions()

  proc display() =
    glClear(GL_COLOR_BUFFER_BIT)
    window.swapBuffers()

  window.maximized = false
  displayLoop(window, 1000):
     display()
  doAssert not window.maximized

  window.maximized = true
  displayLoop(window, 1000):
     display()
  doAssert window.maximized

  window.maximized = false
  displayLoop(window, 1000):
     display()
  doAssert not window.maximized

