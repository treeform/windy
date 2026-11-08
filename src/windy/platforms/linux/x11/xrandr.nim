import x, xlib

type
  XRRMonitorInfo* {.bycopy.} = object
    name*: Atom
    primary*, automatic*, noutput*: cint
    x*, y*, width*, height*, mwidth*, mheight*: cint
    outputs*: ptr culong

{.push cdecl, dynlib: "libXrandr.so.2", importc.}
proc XRRQueryVersion*(display: Display, major, minor: ptr cint): cint
proc XRRGetMonitors*(display: Display, window: Window, active: cint,
    count: ptr cint): ptr UncheckedArray[XRRMonitorInfo]
proc XRRFreeMonitors*(monitors: ptr UncheckedArray[XRRMonitorInfo])
{.pop.}
