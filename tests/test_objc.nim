when not defined(macosx):
  {.error: "This test requires the macOS Objective-C runtime.".}

import windy/platforms/apple/objc

{.passL: "-framework Foundation".}

type KeywordProbe = distinct int

objc:
  proc `type`*(self: KeywordProbe): int
  proc `from`(self: KeywordProbe, x: int, `to`: int): int
  proc release(self: KeywordProbe)

proc probeType(self: ID, selector: SEL): int {.cdecl.} =
  ## Implements a real Objective-C method whose name is a Nim keyword.
  42

proc probeRange(self: ID, selector: SEL, first, last: int): int {.cdecl.} =
  ## Verifies quoted method names and subsequent selector labels.
  last - first

echo "Testing quoted Objective-C selectors against the native runtime"
let probeClass = objc_allocateClassPair(
  objc_getClass("NSObject"), "WindyKeywordProbe", 0
)
doAssert probeClass.int != 0
doAssert class_addMethod(
  probeClass, s"type", cast[IMP](probeType), "q@:"
)
doAssert class_addMethod(
  probeClass, s"from:to:", cast[IMP](probeRange), "q@:qq"
)
objc_registerClassPair(probeClass)
let probe = KeywordProbe(probeClass.new().int)
doAssert probe.`type`() == 42
doAssert probe.`from`(3, 10) == 7
probe.release()
echo "Native Objective-C keyword selector checks passed."
