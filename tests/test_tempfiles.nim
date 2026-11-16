when defined(macosx):
  import
    std/[json, os, tempfiles],
    windy

  if getEnv("WINDY_TEMPFILE_RECORD") != "":
    writeFile(getEnv("WINDY_TEMPFILE_RECORD"), $(%commandLineParams()))
    quit(0)

  proc testTempFiles() =
    ## Checks that filenames reach TextEdit without shell interpretation.
    let
      tempDir = createTempDir("windy-tempfiles-", "")
      originalDir = getCurrentDir()
      originalPath = getEnv("PATH")
      recordPath = tempDir / "args.json"
      opener = tempDir / "open"
      titles = [
        "ordinary.txt",
        "two words.txt",
        "quotes'\".txt",
        "$(touch windy-injected)",
        "`touch windy-injected`",
        "title; touch windy-injected",
        "title\ntouch windy-injected",
        "日本語.txt"
      ]
    defer:
      setCurrentDir(originalDir)
      putEnv("PATH", originalPath)
      delEnv("WINDY_TEMPFILE_RECORD")
      removeDir(tempDir)
    copyFile(getAppFilename(), opener)
    setFilePermissions(opener, {fpUserRead, fpUserWrite, fpUserExec})
    setCurrentDir(tempDir)
    putEnv("PATH", tempDir & ":" & originalPath)
    putEnv("WINDY_TEMPFILE_RECORD", recordPath)
    for title in titles:
      openTempTextFile(title, "Text contents.")
      doAssert parseFile(recordPath) == %[
        "-a", "TextEdit", "--", "tmp" / title
      ]
      doAssert readFile("tmp" / title) == "Text contents."
      doAssert not fileExists("windy-injected")

  testTempFiles()
  echo "Windy temporary file regression test passed"
else:
  echo "Windy temporary file regression test skipped"
