--path:"../src"

when defined(emscripten):
  include "../examples/config.nims"

import std/os
if projectName() in ["manual_drm_gpu", "manual_drm_pixelpair"] and not defined(debug):
  # Measure the same shipped settings as the graphical applications.
  switch("define", "release")
  switch("define", "danger")
let testBackends = getEnv("WINDY_TEST_BACKENDS")
if projectName() == "test_x11_pixels":
  switch("define", "useCpu")
  switch("define", "windyBackends=" & (if testBackends.len > 0: testBackends else: "x11"))
if projectName() == "test_drm_pixelpair" and testBackends.len == 0:
  switch("define", "useCpu")
  switch("define", "windyBackends=drm")
if testBackends.len > 0:
  switch("define", "useCpu")
  switch("define", "windyBackends=" & testBackends)

if getEnv("WINDY_TEST_TARGET") == "arm":
  switch("cpu", "arm")
elif getEnv("WINDY_TEST_TARGET") == "arm64":
  switch("cpu", "arm64")
  switch("gcc.exe", getEnv("MONO_RETRO_CC", "aarch64-unknown-linux-gnu-gcc"))
  switch("gcc.linkerexe", getEnv("MONO_RETRO_CC", "aarch64-unknown-linux-gnu-gcc"))
  switch("passL", "-Wl,--dynamic-linker=/lib/ld-linux-aarch64.so.1")
