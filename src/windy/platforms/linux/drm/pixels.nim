import
  ../../../common,
  ../backends

export PixelRegion

type DrmPixelPair* = ref object
  display: GpuDisplay

proc newDrmPixelPair*[T](first, second: T): DrmPixelPair =
  ## Claim two equal native DRM windows for GPU pixels; close them after this pair.
  when T is typeof(nil):
    raise newException(WindyError, "GPU pixel pairs require native DRM windows")
  else:
    if first == nil or second == nil:
      raise newException(WindyError, "GPU pixel pairs require native DRM windows")
    let
      a = first.direct
      b = second.direct
    if a == nil or b == nil:
      raise newException(WindyError, "GPU pixel pairs require native DRM windows")
    if a.closed or b.closed or a.backend != DrmBackend or b.backend != DrmBackend or
        a.drm == nil or b.drm == nil or a.screen == nil or b.screen == nil or a.drm != b.drm:
      raise newException(WindyError, "GPU pixel pairs require open windows on one DRM device")
    result = DrmPixelPair(display: newGpuDisplay(a.drm, [a.screen, b.screen]))

proc presentPixels*(pair: DrmPixelPair, image: Image, regions: array[2, PixelRegion]) =
  ## Center integer-scaled source crops, using black for an empty crop or nil image.
  if pair == nil: raise newException(WindyError, "GPU pixel pair is nil")
  pair.display.presentGpuPixels(image, regions)

proc close*(pair: DrmPixelPair) =
  ## Restore both outputs and release GPU resources before closing the windows.
  if pair == nil: return
  pair.display.close()
