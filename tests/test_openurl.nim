import windy

when defined(windows):
  import windy/platforms/win32/[utils, windefs]

  var openedUrls: seq[string]

  proc recordOpenUrl(
    hwnd: HWND,
    operation, target, parameters, directory: LPCWSTR,
    showCmd: int32
  ): HINSTANCE {.stdcall, exportc: "ShellExecuteW".} =
    # Capture the native API boundary without launching a browser.
    doAssert hwnd == 0
    doAssert $operation == "open"
    doAssert parameters == nil
    doAssert directory == nil
    doAssert showCmd == SW_SHOWNORMAL
    openedUrls.add($target)
    return 33
else:
  import std/[json, os, tempfiles]

  # A copy of this executable stands in for open/xdg-open on PATH.
  if getEnv("WINDY_OPENURL_RECORD") != "":
    writeFile(getEnv("WINDY_OPENURL_RECORD"), $(%commandLineParams()))
    quit(0)

proc main() =
  let urls = [
    "https://example.com/",
    "https://example.com/?first=1&second=2#fragment",
    "https://example.com/a b/\"quoted\"/'single'",
    "https://example.com/$(echo injected > windy-openurl-injected)",
    "https://example.com/`echo injected > windy-openurl-injected`",
    "https://example.com/; echo injected > windy-openurl-injected",
    "https://example.com/| echo injected > windy-openurl-injected",
    "https://example.com/\necho injected > windy-openurl-injected",
    "https://example.com/%PATH%/$HOME/!name!/a\\b",
    "https://example.com/café/日本語/🌍?x=1&y=2"
  ]

  when defined(windows):
    for url in urls:
      openUrl(url)
    doAssert openedUrls == @urls
  else:
    let
      tempDir = createTempDir("windy-openurl-", "")
      originalDir = getCurrentDir()
      originalPath = getEnv("PATH")
      recordPath = tempDir / "args.json"
      opener = tempDir / (when defined(macosx): "open" else: "xdg-open")
    defer:
      setCurrentDir(originalDir)
      putEnv("PATH", originalPath)
      delEnv("WINDY_OPENURL_RECORD")
      removeDir(tempDir)

    copyFile(getAppFilename(), opener)
    setFilePermissions(opener, {fpUserRead, fpUserWrite, fpUserExec})
    setCurrentDir(tempDir)
    putEnv("PATH", tempDir & ":" & originalPath)
    putEnv("WINDY_OPENURL_RECORD", recordPath)

    for url in urls:
      if fileExists(recordPath):
        removeFile(recordPath)
      openUrl(url)
      let expected = when defined(macosx): @["--", url] else: @[url]
      doAssert parseFile(recordPath) == %expected
      doAssert not fileExists("windy-openurl-injected")

  echo "Windy openUrl regression test passed"

main()
