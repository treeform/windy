## This example shows how to load a texture with Pixie into OpenGL 4.

import opengl, pixie, windy

const vertexShaderText = """
#version 410

in vec3 vertexPos;
in vec2 vertexUv;

out vec3 pos;
out vec2 uv;

void main()
{
  pos = vertexPos;
  uv = vertexUv;
  gl_Position = vec4(vertexPos.xyz, 1.0);
}
"""

const fragmentShaderText = """
#version 410

in vec3 pos;
in vec2 uv;
uniform sampler2D testTexture;

out vec4 fragColor;

void main()
{
  fragColor = texture(testTexture, uv);
}
"""

proc checkError*(shader: GLuint) =
  ## Checks the shader for errors.
  var code: GLint
  glGetShaderiv(shader, GL_COMPILE_STATUS, addr code)
  if code.GLboolean == GL_FALSE:
    var length: GLint = 0
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, addr length)
    var log = newString(length.int)
    glGetShaderInfoLog(shader, length, nil, log.cstring)
    echo log

proc checkLinkError*(program: GLuint) =
  ## Checks the shader for errors.
  var code: GLint
  glGetProgramiv(program, GL_LINK_STATUS, addr code)
  if code.GLboolean == GL_FALSE:
    var length: GLint = 0
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, addr length)
    var log = newString(length.int)
    glGetProgramInfoLog(program, length, nil, log.cstring)
    echo log

let window = newWindow("Windy Textured Quad", ivec2(512, 512))
window.makeContextCurrent()
loadExtensions()

let
  vertexShader = glCreateShader(GL_VERTEX_SHADER)
  vertexShaderTextArr = allocCStringArray([vertexShaderText])
glShaderSource(vertexShader, 1.GLsizei, vertexShaderTextArr, nil)
glCompileShader(vertex_shader)
checkError(vertexShader)

let
  fragmentShader = glCreateShader(GL_FRAGMENT_SHADER)
  fragmentShaderTextArr = allocCStringArray([fragmentShaderText])
glShaderSource(fragmentShader, 1.GLsizei, fragmentShaderTextArr, nil)
glCompileShader(fragmentShader)
checkError(fragmentShader)

let program = glCreateProgram()
glAttachShader(program, vertexShader)
glAttachShader(program, fragmentShader)
glLinkProgram(program)
checkLinkError(program)

# Define data to draw the quad:
var posData = @[
  vec3(-0.5f, -0.5f, 0.0f),
  vec3(0.5f, -0.5f, 0.0f),
  vec3(0.5f,  0.5f, 0.0f),

  vec3(0.5f,  0.5f, 0.0f),
  vec3(-0.5f,  0.5f, 0.0f),
  vec3(-0.5f, -0.5f, 0.0f),
]

var uvData = @[
  vec2(0f, 1f),
  vec2(1f, 1f),
  vec2(1f, 0f),

  vec2(1f, 0f),
  vec2(0f, 0f),
  vec2(0f, 1f),
]

var vao: uint32
glGenVertexArrays(1, vao.addr);
glBindVertexArray(vao);

var posBuffer: uint32
glGenBuffers(1, posBuffer.addr)
glBindBuffer(GL_ARRAY_BUFFER, posBuffer)
glBufferData(GL_ARRAY_BUFFER, posData.len*4*3, posData[0].addr, GL_STATIC_DRAW)
glVertexAttribPointer(0, 3, cGL_FLOAT, GL_FALSE, 3*4, nil)
glEnableVertexAttribArray(0)

var uvBuffer: uint32
glGenBuffers(1, uvBuffer.addr)
glBindBuffer(GL_ARRAY_BUFFER, uvBuffer)
glBufferData(GL_ARRAY_BUFFER, uvData.len*4*2, uvData[0].addr, GL_STATIC_DRAW)
glVertexAttribPointer(1, 2, cGL_FLOAT, GL_FALSE, 2*4, nil)
glEnableVertexAttribArray(1)

# Load the png texture from file.
let testTexture = readImage("examples/data/testTexture.png")

var textureId: uint32
glGenTextures(1, textureId.addr)
glBindTexture(GL_TEXTURE_2D, textureId)
glTexImage2D(
  target = GL_TEXTURE_2D,
  level = 0,
  internalFormat = GL_RGBA8.GLint,
  width = testTexture.width.GLsizei,
  height = testTexture.height.GLsizei,
  border = 0,
  format = GL_RGBA,
  `type` = GL_UNSIGNED_BYTE,
  pixels = cast[pointer](testTexture.data[0].addr)
)
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP)
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP)

let textureLoc = glGetUniformLocation(program, "testTexture")
glActiveTexture(GL_TEXTURE0)

proc display() =
  ## Runs every frame.
  glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);

  glViewport(0, 0, window.size.x, window.size.y)

  glUseProgram(program)
  glBindVertexArray(vao)

  glUniform1i(textureLoc, 0)
  glBindTexture(GL_TEXTURE_2D, textureId)

  glDrawArrays(GL_TRIANGLES, 0, 3*2)
  swapBuffers(window)

while not window.closeRequested:
  pollEvents()
  display()
