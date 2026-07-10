when defined(useCpu) and (defined(windows) or defined(macosx)):
  import pixie, windy

  let window = newWindow(
    "Windy CPU pixels smoke test",
    ivec2(32, 32),
    visible = false,
    vsync = false
  )
  let image = newImage(32, 32)
  image.fill(color(0.2, 0.4, 0.8, 1.0))
  window.presentPixels(image)
  window.close()

  echo "Windy CPU pixels smoke test passed"
else:
  echo "Windy CPU pixels smoke test skipped"
