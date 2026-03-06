## Compiles all Emscripten examples, opens tabs, and serves assets over HTTP.

import
  std/[browsers, os, osproc, strformat, strutils],
  mummy, mummy/routers

when not declared(Thread):
  import std/threads

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
]

const
  ServerHost = "127.0.0.1"
  ServerPortNumber = 8080
  ServerPort = Port(ServerPortNumber)

proc guessContentType(path: string): string =
  ## Returns a basic content type for static files.
  let ext = splitFile(path).ext.toLowerAscii()
  case ext
  of ".html":
    "text/html; charset=utf-8"
  of ".js":
    "text/javascript; charset=utf-8"
  of ".wasm":
    "application/wasm"
  of ".data":
    "application/octet-stream"
  of ".css":
    "text/css; charset=utf-8"
  of ".json":
    "application/json; charset=utf-8"
  of ".png":
    "image/png"
  of ".jpg", ".jpeg":
    "image/jpeg"
  of ".svg":
    "image/svg+xml; charset=utf-8"
  else:
    "application/octet-stream"

proc isSafeRelativePath(relativePath: string): bool =
  ## Returns true when the relative path does not escape the root.
  if relativePath.len == 0:
    return true
  if relativePath.startsWith('/'):
    return false
  if '\0' in relativePath:
    return false
  for part in relativePath.split('/'):
    if part == "..":
      return false
  true

proc openTabs(urls: seq[string]) =
  ## Opens URLs in the default browser.
  for url in urls:
    openDefaultBrowser(url)

proc serveThread(server: Server) =
  ## Runs the server loop in a worker thread.
  {.gcsafe.}:
    server.serve(ServerPort, ServerHost)

proc serveEmscriptenDir(emscriptenDir: string, urls: seq[string]) =
  ## Serves the Emscripten output directory until Ctrl-C.
  var router: Router

  router.get("/", proc(request: Request) {.gcsafe.} =
    var body = "<!doctype html><html><body><h1>Windy Emscripten Examples</h1><ul>"
    for name in Examples:
      body.add("<li><a href=\"/" & name & ".html\">" & name & ".html</a></li>")
    body.add("</ul></body></html>")

    var headers: HttpHeaders
    headers["Content-Type"] = "text/html; charset=utf-8"
    request.respond(200, headers, body)
  )

  router.get("/**", proc(request: Request) {.gcsafe.} =
    var relativePath = request.path
    if relativePath.startsWith('/'):
      relativePath = relativePath[1 .. ^1]

    if not isSafeRelativePath(relativePath):
      request.respond(403, emptyHttpHeaders(), "Forbidden")
      return

    var filePath = emscriptenDir / relativePath
    if dirExists(filePath):
      filePath = filePath / "index.html"

    if not fileExists(filePath):
      request.respond(404, emptyHttpHeaders(), "Not found")
      return

    let body = readFile(filePath)
    var headers: HttpHeaders
    headers["Content-Type"] = guessContentType(filePath)
    request.respond(200, headers, body)
  )

  let server = newServer(router)
  echo fmt"Serving {emscriptenDir} at http://{ServerHost}:{ServerPortNumber}/"
  echo "Press Ctrl-C to stop."

  when compileOption("threads"):
    var serverWorker: Thread[Server]
    createThread(serverWorker, serveThread, server)
    server.waitUntilReady()
    openTabs(urls)
    joinThread(serverWorker)
  else:
    echo "Warning: Build without threads, opening tabs before server starts."
    openTabs(urls)
    server.serve(ServerPort, ServerHost)

proc main() =
  ## Compiles all Emscripten examples, then serves and opens them in tabs.
  let
    startDir = getCurrentDir()
    rootDir = currentSourcePath().parentDir.parentDir
    emscriptenDir = rootDir / "examples" / "emscripten"
  defer:
    setCurrentDir(startDir)

  echo "=== Windy Emscripten Runner ==="
  echo "Compiling all examples first with: nim c -d:emscripten"
  echo "Serving generated files over HTTP after successful compilation.\n"

  for i, name in Examples:
    let nimFile = "examples" / (name & ".nim")

    echo fmt"[{i + 1}/{Examples.len}] Compiling: {name}"
    setCurrentDir(rootDir)

    let exitCode = execCmd(fmt"nim c -d:emscripten {nimFile}")
    if exitCode != 0:
      echo fmt"  ERROR: {name} failed to compile with exit code {exitCode}"
      quit(exitCode)
    echo ""

  echo "=== Compilation complete ===\n"

  var urls: seq[string]
  for i, name in Examples:
    let url = fmt"http://{ServerHost}:{ServerPortNumber}/{name}.html"
    echo fmt"[{i + 1}/{Examples.len}] Queueing tab: {url}"
    urls.add(url)

  echo ""
  serveEmscriptenDir(emscriptenDir, urls)

when isMainModule:
  main()
