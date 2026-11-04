## Run on the two-monitor Xvfb layout configured by the build workflow.
import windy, std/algorithm
var screens = getScreens()
screens.sort(proc(a, b: Screen): int = cmp(a.left, b.left))
doAssert screens.len == 2, "each monitor must be returned separately"
doAssert screens[0].left == 0 and screens[0].right == 800
doAssert screens[1].left == 800 and screens[1].right == 1600
for screen in screens:
  doAssert screen.top == 0 and screen.bottom == 600
echo "Two distinct X11 monitor bounds passed"
