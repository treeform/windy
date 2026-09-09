when defined(emscripten):
  switch("os", "linux")
  switch("cpu", "wasm32")
  switch("cc", "clang")
  switch("clang.exe", "emcc")
  switch("clang.linkerexe", "emcc")
  switch("mm", "arc")
  switch("exceptions", "goto")
  switch("define", "noSignalHandler")
  switch("nimcache", "tmp/browser-inputs")
  switch(
    "passL",
    "-o tests/test_browser_inputs.cjs -s SINGLE_FILE=1 " &
    "-s ENVIRONMENT=node -s EXIT_RUNTIME=1 -s ALLOW_MEMORY_GROWTH " &
    "-s EXPORTED_FUNCTIONS=_main,_malloc,_free"
  )
