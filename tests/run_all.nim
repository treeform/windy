## Compiles all examples first, then runs them sequentially.

import std/[osproc, os, strformat]

const Examples = [
  "basic",
  "basic_boxy",
  "basic_textured_quad",
  "basic_triangle",
  "callbacks",
  "clipboard",
  "content_scale",
  "cursor_position_test",
  "custom_cursor",
  "dragdrop",
  "fixedsize",
  "fullscreen",
  "icon",
  "opengl_version",
  "openurl",
  "property_changes",
  "screens",
  "scrollwheel",
  "system_cursors",
  "tray",
  "websocket",
]

proc main() =
  ## Compile all examples, then run all examples in sequence.
  let
    startDir = getCurrentDir()
    rootDir = currentSourcePath().parentDir.parentDir
  defer:
    setCurrentDir(startDir)

  echo "=== Windy Examples Runner ==="
  echo "Compiling all examples first."
  echo "Running all examples after successful compilation."
  echo "Close each window to proceed to the next example.\n"

  for i, name in Examples:
    let nimFile = "examples" / (name & ".nim")
    echo fmt"[{i + 1}/{Examples.len}] Compiling: {name}"

    setCurrentDir(rootDir)
    let exitCode = execCmd(fmt"nim c {nimFile}")
    if exitCode != 0:
      echo fmt"  ERROR: {name} failed to compile with exit code {exitCode}"
      quit(exitCode)
    echo ""

  echo "=== Compilation complete ===\n"

  for i, name in Examples:
    when defined(macosx):
      if name == "opengl_version":
        echo fmt"[{i + 1}/{Examples.len}] Skipping on macOS: {name}"
        echo ""
        continue

    let binaryPath = "examples" / name
    echo fmt"[{i + 1}/{Examples.len}] Running: {name}"

    setCurrentDir(rootDir)
    let exitCode = execCmd(binaryPath)
    if exitCode != 0:
      echo fmt"  ERROR: {name} failed with exit code {exitCode}"
      quit(exitCode)
    echo ""

  echo "=== All examples completed ==="

when isMainModule:
  main()
