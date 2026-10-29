--path:"../src"

when defined(emscripten):
  include "../examples/config.nims"

import std/os
let testBackends = getEnv("WINDY_TEST_BACKENDS")
if testBackends.len > 0:
  switch("define", "useCpu")
  switch("define", "windyBackends=" & testBackends)

if getEnv("WINDY_TEST_TARGET") == "arm64":
  switch("cpu", "arm64")
  switch("gcc.exe", getEnv("MONO_RETRO_CC", "aarch64-unknown-linux-gnu-gcc"))
  switch("gcc.linkerexe", getEnv("MONO_RETRO_CC", "aarch64-unknown-linux-gnu-gcc"))
  switch("passL", "-Wl,--dynamic-linker=/lib/ld-linux-aarch64.so.1")
