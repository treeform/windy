import
  std/[math, strformat],
  opengl, pixie,
  ../../../windy,
  ./native/pixelpair

export PixelRegion

type
  X11PixelPresenter* = ref object
    window: Window
    texture, program, vertices: GLuint
    textureWidth, textureHeight: int
    closed: bool

const
  VertexSource = """#version 120
attribute vec2 position;
attribute vec2 uv;
varying vec2 tex;
void main(){gl_Position=vec4(position,0.0,1.0);tex=uv;}
"""
  FragmentSource = """#version 120
varying vec2 tex;
uniform sampler2D image;
void main(){gl_FragColor=vec4(texture2D(image,tex).rgb,1.0);}
"""
  MaximumLogBytes = 65536

proc checkGl(operation: string) =
  ## Report driver errors at the operation that owns them.
  let code = glGetError()
  if code != GL_NO_ERROR:
    raise newException(WindyError, &"{operation}: OpenGL error {code.uint32}.")

proc compileShader(kind: GLenum, source: string): GLuint =
  ## Compile a small pixel shader, preserving the driver's diagnostic on failure.
  result = glCreateShader(kind)
  var text = source.cstring
  glShaderSource(result, 1, cast[cstringArray](addr text), nil)
  glCompileShader(result)
  var status: GLint
  glGetShaderiv(result, GL_COMPILE_STATUS, addr status)
  if status == 0:
    var length: GLint
    glGetShaderiv(result, GL_INFO_LOG_LENGTH, addr length)
    var message = newString(clamp(length.int, 1, MaximumLogBytes))
    glGetShaderInfoLog(result, message.len.GLsizei, nil, message.cstring)
    glDeleteShader(result)
    raise newException(WindyError, "Compiling X11 pixel shader: " & message)

proc close*(presenter: X11PixelPresenter) =
  ## Release GPU storage before its window; repeated close is harmless.
  if presenter == nil or presenter.closed: return
  if presenter.window != nil and not presenter.window.closed:
    presenter.window.makeContextCurrent()
    if presenter.texture != 0: glDeleteTextures(1, addr presenter.texture)
    if presenter.vertices != 0: glDeleteBuffers(1, addr presenter.vertices)
    if presenter.program != 0: glDeleteProgram(presenter.program)
  presenter.closed = true
  presenter.window = nil

proc newX11PixelPresenter*(window: Window): X11PixelPresenter =
  ## Claim an opt-in double-buffered X11 GPU pixel window on the creating thread.
  if window == nil or not window.hasGpuPixelContext:
    raise newException(WindyError, "X11 GPU pixels require LinuxWindowOptions(gpuPixels: true).")
  window.makeContextCurrent()
  loadExtensions()
  result = X11PixelPresenter(window: window)
  try:
    let vertex = compileShader(GL_VERTEX_SHADER, VertexSource)
    defer: glDeleteShader(vertex)
    let fragment = compileShader(GL_FRAGMENT_SHADER, FragmentSource)
    defer: glDeleteShader(fragment)
    result.program = glCreateProgram()
    glAttachShader(result.program, vertex)
    glAttachShader(result.program, fragment)
    glBindAttribLocation(result.program, 0, "position")
    glBindAttribLocation(result.program, 1, "uv")
    glLinkProgram(result.program)
    var linked: GLint
    glGetProgramiv(result.program, GL_LINK_STATUS, addr linked)
    if linked == 0:
      var length: GLint
      glGetProgramiv(result.program, GL_INFO_LOG_LENGTH, addr length)
      var message = newString(clamp(length.int, 1, MaximumLogBytes))
      glGetProgramInfoLog(result.program, message.len.GLsizei, nil, message.cstring)
      raise newException(WindyError, "Linking X11 pixel shaders: " & message)
    glGenTextures(1, addr result.texture)
    glGenBuffers(1, addr result.vertices)
    glBindTexture(GL_TEXTURE_2D, result.texture)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST.GLint)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST.GLint)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE.GLint)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE.GLint)
    checkGl("Initializing X11 pixel presenter")
  except:
    result.close()
    raise

proc drawPixels*(presenter: X11PixelPresenter, image: Image, region: PixelRegion,
    changed = true, scale = 0, fitDown = false) =
  ## Upload opaque native RGBA and draw one integer-scaled crop into the back buffer.
  if presenter == nil or presenter.closed or presenter.window.closed:
    raise newException(WindyError, "X11 pixel presenter is closed.")
  if scale < 0: raise newException(ValueError, "Pixel scale cannot be negative.")
  let
    width = if image == nil: 0 else: image.width
    height = if image == nil: 0 else: image.height
    size = presenter.window.framebufferSize
  validateRegions(width, height, [region, PixelRegion()])
  if size.x <= 0 or size.y <= 0: return
  presenter.window.makeContextCurrent()
  glViewport(0, 0, size.x.GLsizei, size.y.GLsizei)
  glDisable(GL_BLEND)
  glDisable(GL_DEPTH_TEST)
  glDisable(GL_STENCIL_TEST)
  glDisable(GL_SCISSOR_TEST)
  glDisable(GL_DITHER)
  glClearColor(0, 0, 0, 1)
  glClear(GL_COLOR_BUFFER_BIT)
  if region != PixelRegion():
    var viewport = pixelViewport(region, size.x.int, size.y.int)
    if scale > 0:
      if size.x.int div region.width < scale or size.y.int div region.height < scale:
        raise newException(ValueError, "Window is too small for the requested scale.")
      viewport = PixelRegion(width: region.width * scale, height: region.height * scale)
      viewport.x = (size.x.int - viewport.width) div 2
      viewport.y = (size.y.int - viewport.height) div 2
    elif fitDown and (region.width > size.x.int or region.height > size.y.int):
      let factor = min(size.x.float64 / region.width.float64, size.y.float64 / region.height.float64)
      viewport.width = max(1, floor(region.width.float64 * factor).int)
      viewport.height = max(1, floor(region.height.float64 * factor).int)
      viewport.x = (size.x.int - viewport.width) div 2
      viewport.y = (size.y.int - viewport.height) div 2
    glActiveTexture(GL_TEXTURE0)
    glBindTexture(GL_TEXTURE_2D, presenter.texture)
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
    if width != presenter.textureWidth or height != presenter.textureHeight:
      static: doAssert sizeof(ColorRGBX) == 4
      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8.GLint, width.GLsizei, height.GLsizei,
        0, GL_RGBA, GL_UNSIGNED_BYTE, unsafeAddr image.data[0])
      presenter.textureWidth = width
      presenter.textureHeight = height
    elif changed:
      glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width.GLsizei, height.GLsizei,
        GL_RGBA, GL_UNSIGNED_BYTE, unsafeAddr image.data[0])
    var data = pixelVertices(width, height, [region, PixelRegion()])
    glUseProgram(presenter.program)
    glUniform1i(glGetUniformLocation(presenter.program, "image"), 0)
    glBindBuffer(GL_ARRAY_BUFFER, presenter.vertices)
    glBufferData(GL_ARRAY_BUFFER, 24 * sizeof(cfloat), addr data[0], GL_STREAM_DRAW)
    glVertexAttribPointer(0, 2, cGL_FLOAT, GL_FALSE, (4 * sizeof(cfloat)).GLsizei, nil)
    glVertexAttribPointer(1, 2, cGL_FLOAT, GL_FALSE, (4 * sizeof(cfloat)).GLsizei,
      cast[pointer](2 * sizeof(cfloat)))
    glEnableVertexAttribArray(0)
    glEnableVertexAttribArray(1)
    glViewport(viewport.x.GLint, (size.y.int - viewport.y - viewport.height).GLint,
      viewport.width.GLsizei, viewport.height.GLsizei)
    glDrawArrays(GL_TRIANGLES, 0, 6)
    glDisableVertexAttribArray(0)
    glDisableVertexAttribArray(1)
    glUseProgram(0)
    glBindBuffer(GL_ARRAY_BUFFER, 0)
  glFlush()
  checkGl("Drawing X11 pixels")

proc swap*(presenter: X11PixelPresenter) =
  ## Swap a completed back buffer after all windows in the frame have been drawn.
  if presenter == nil or presenter.closed or presenter.window.closed:
    raise newException(WindyError, "X11 pixel presenter is closed.")
  presenter.window.makeContextCurrent()
  presenter.window.swapBuffers()
