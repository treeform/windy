import
  std/[exitprocs, posix],
  ../../../common

var wakePipe = [-1.cint, -1.cint]

proc closeWakePipe() {.noconv.} =
  ## Releases the process-wide wake descriptors at shutdown.
  for descriptor in wakePipe:
    if descriptor >= 0:
      discard posix.close(descriptor)

proc initEventWait*() =
  ## Initializes native waking on the window thread before workers can post.
  if wakePipe[0] >= 0:
    return
  if posix.pipe(wakePipe) != 0:
    raise newException(WindyError, "Cannot create the native event wake pipe.")
  for descriptor in wakePipe:
    if fcntl(descriptor, F_SETFL, O_NONBLOCK) != 0 or
      fcntl(descriptor, F_SETFD, FD_CLOEXEC) != 0:
        closeWakePipe()
        wakePipe = [-1.cint, -1.cint]
        raise newException(WindyError, "Cannot configure native event waking.")
  addExitProc(closeWakePipe)

proc wakeNativeEvents*() {.raises: [], gcsafe.} =
  ## Wakes a native wait from any thread after a window has been created.
  if wakePipe[1] >= 0:
    var marker: byte
    discard posix.write(wakePipe[1], addr marker, 1)

proc waitNativeEvents*(timeoutMs: int, descriptors: openArray[cint]) =
  ## Waits for input or an explicit wake without allocating file contents.
  var inputs = @[TPollfd(fd: wakePipe[0], events: POLLIN)]
  for descriptor in descriptors:
    if descriptor >= 0:
      inputs.add(TPollfd(fd: descriptor, events: POLLIN))
  if timeoutMs > 0:
    discard posix.poll(
      addr inputs[0],
      Tnfds(inputs.len),
      min(timeoutMs, int32.high.int).cint
    )
  if wakePipe[0] >= 0:
    var bytes: array[64, byte]
    while posix.read(wakePipe[0], addr bytes[0], bytes.len) > 0:
      discard
