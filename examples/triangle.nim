import opengl, windy

## This example shows how to get a plain openGL triangle working with windy.

let window = newWindow("Windy Triangle", ivec2(1280, 800))

window.makeContextCurrent()
loadExtensions()

let vertexShaderText = """
#version 410
in vec3 aPos;
out vec3 pos;
void main()
{
  pos = aPos;
  gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
}
"""

let fragmentShaderText = """
#version 410
in vec3 pos;
out vec4 fragColor;
void main()
{
  fragColor = vec4(1.0f, 0.5f, pos.x, 1.0f);
}
"""

proc checkError*(shader: GLuint) =
  var code: GLint
  glGetShaderiv(shader, GL_COMPILE_STATUS, addr code)
  if code.GLboolean == GL_FALSE:
    var length: GLint = 0
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, addr length)
    var log = newString(length.int)
    glGetShaderInfoLog(shader, length, nil, log.cstring)
    echo log

proc checkLinkError*(program: GLuint) =
  var code: GLint
  glGetProgramiv(program, GL_LINK_STATUS, addr code)
  if code.GLboolean == GL_FALSE:
    var length: GLint = 0
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, addr length)
    var log = newString(length.int)
    glGetProgramInfoLog(program, length, nil, log.cstring)
    echo log

var vertexShader = glCreateShader(GL_VERTEX_SHADER)
var vertexShaderTextArr = allocCStringArray([vertexShaderText])
glShaderSource(vertexShader, 1.GLsizei, vertexShaderTextArr, nil)
glCompileShader(vertex_shader)
checkError(vertexShader)

var fragmentShader = glCreateShader(GL_FRAGMENT_SHADER)
var fragmentShaderTextArr = allocCStringArray([fragmentShaderText])
glShaderSource(fragmentShader, 1.GLsizei, fragmentShaderTextArr, nil)
glCompileShader(fragmentShader)
checkError(fragmentShader)

var program = glCreateProgram()
glAttachShader(program, vertexShader)
glAttachShader(program, fragmentShader)
glLinkProgram(program)
checkLinkError(program)

var vboData = @[
  vec3(-0.5f, -0.5f, 0.0f),
  vec3(0.5f, -0.5f, 0.0f),
  vec3(0.0f,  0.5f, 0.0f)
]

var vbo: uint32
glGenBuffers(1, vbo.addr)

var vao: uint32
glGenVertexArrays(1, vao.addr);

glBindVertexArray(vao);

glBindBuffer(GL_ARRAY_BUFFER, vbo)
glBufferData(GL_ARRAY_BUFFER, vboData.len*4*3, vboData[0].addr, GL_STATIC_DRAW)

glVertexAttribPointer(0, 3, cGL_FLOAT, GL_FALSE, 3*4, nil)
glEnableVertexAttribArray(0)

proc display() =

  glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);

  glViewport(0, 0, window.size.x, window.size.y)

  glUseProgram(program)
  glBindVertexArray(vao)
  glDrawArrays(GL_TRIANGLES, 0, 3)

  # Your OpenGL display code here
  window.swapBuffers()

while not window.closeRequested:
  display()
  pollEvents()
