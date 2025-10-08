import os, strformat, strutils

--path:"../src"

when defined(emscripten):
  --nimcache:tmp
  --os:linux
  --cpu:wasm32
  --cc:clang
  when defined(windows):
    --clang.exe:emcc.bat
    --clang.linkerexe:emcc.bat
    --clang.cpp.exe:emcc.bat
    --clang.cpp.linkerexe:emcc.bat
  else:
    --clang.exe:emcc
    --clang.linkerexe:emcc
    --clang.cpp.exe:emcc
    --clang.cpp.linkerexe:emcc
  --listCmd

  --gc:arc
  --exceptions:goto
  --define:noSignalHandler
  --debugger:native
  --define:noAutoGLerrorCheck

  # Pass this to Emscripten linker to generate html file scaffold for us.
  switch(
    "passL",
    (&"""
    -o examples/emscripten/{projectName()}.html
    --preload-file examples/data
    --shell-file examples/emscripten/emscripten.html
    -s ASYNCIFY
    -s USE_WEBGL2=1
    -s MAX_WEBGL_VERSION=2
    -s MIN_WEBGL_VERSION=1
    -s FULL_ES3=1
    -s GL_ENABLE_GET_PROC_ADDRESS=1
    -s ALLOW_MEMORY_GROWTH
    --profiling
    """).replace("\n", " ")
  )

  # Prevent accidental running of emscripten.
  if paramStr(1) == "run" or paramStr(1) == "r":
    setCommand("c")
    echo "To run emscripten, use:"
    echo "emrun examples/" & projectName() & ".html"

when not defined(debug):
  --define:noAutoGLerrorCheck
  --define:release
  --define:ssl
