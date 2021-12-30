import memfiles, os
import vmath
import protocol

type SharedBuffer* = ref object
  ## memmaped file that can be shared between processes
  shm: Shm
  buffer: Buffer
  file: MemFile
  filename: string

proc dataAddr*(buffer: SharedBuffer): pointer =
  buffer.file.mem

proc fileDescriptor*(buffer: SharedBuffer): FileDescriptor =
  buffer.file.handle.FileDescriptor

proc buffer*(buffer: SharedBuffer): Buffer =
  buffer.buffer

proc create*(shm: Shm, size: IVec2, format: PixelFormat): SharedBuffer =
  new result, proc(buffer: SharedBuffer) =
    close buffer.file
  
  result.shm = shm
  
  let filebase = getEnv("XDG_RUNTIME_DIR") / "windy-"
  for i in 0..int.high:
    if not fileExists(filebase & $i):
      result.filename = filebase & $i
      result.file = memfiles.open(result.filename, mode=fmReadWrite, allowRemap=true, newFileSize = size.x * size.y * 4)
      break
  
  let pool = shm.newPool(result.fileDescriptor, size.x * size.y * 4)
  result.buffer = pool.newBuffer(0, size, size.x * 4, format)
  destroy pool
