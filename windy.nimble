version     = "0.0.0"
author      = "Andre von Houck and Ryan Oldenburg"
description = "Windy"
license     = "MIT"

srcDir = "src"

requires "nim >= 1.4.8"
requires "vmath >= 1.1.0"
requires "bitty >= 0.1.2"

task bindings, "Generate bindings":

  proc compile(libName: string, flags = "") =
    exec "nim c -f " & flags & " -d:release --app:lib --gc:arc --tlsEmulation:off --out:" & libName & " --outdir:bindings/generated bindings/bindings.nim"

  when defined(windows):
    compile "windy.dll"

  elif defined(macosx):
    compile "libwindy.dylib.arm", "-l:'-target arm64-apple-macos11' -t:'-target arm64-apple-macos11'"
    compile "libwindy.dylib.x64", "-l:'-target x86_64-apple-macos10.12' -t:'-target x86_64-apple-macos10.12'"
    exec "lipo bindings/generated/libwindy.dylib.arm bindings/generated/libwindy.dylib.x64 -output bindings/generated/libwindy.dylib -create"

  else:
    compile "libwindy.so"
