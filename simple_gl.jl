module UI
 
import GLFW
using ModernGL

include("gltools.jl")

GLFW.Init()
 
# OS X-specific GLFW hints to initialize the correct version of OpenGL
@osx_only begin
    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 2)
    GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE)
    GLFW.WindowHint(GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE)
end
 
# Create a windowed mode window and its OpenGL context
window = GLFW.CreateWindow(600, 600, "OpenGL Example")
 
# Make the window's context current
GLFW.MakeContextCurrent(window)
 
# The data for our triangle
data = GLfloat[
    0.0, 0.5,
    0.5, -0.5,
    -0.5,-0.5
]

# Generate a vertex array and array buffer for our data 
vao = glGenVertexArray()
glBindVertexArray(vao)
 
vbo = glGenBuffer()
glBindBuffer(GL_ARRAY_BUFFER, vbo)
glBufferData(GL_ARRAY_BUFFER, sizeof(data), data, GL_STATIC_DRAW)

# Create and initialize shaders
const vsh = """
    #version 330
    in vec2 position;
 
    void main() {
        gl_Position = vec4(position, 0.0, 1.0);
    }
"""
 
const fsh = """
    #version 330
    out vec4 outColor;
 
    void main() {
        outColor = vec4(1.0, 1.0, 1.0, 1.0);
    }
"""

vertexShader = createShader(vsh, GL_VERTEX_SHADER)
fragmentShader = createShader(fsh, GL_FRAGMENT_SHADER)
program = createShaderProgram(vertexShader, fragmentShader)
glUseProgram(program)

positionAttribute = glGetAttribLocation(program, "position");
 
glEnableVertexAttribArray(positionAttribute)
glVertexAttribPointer(positionAttribute, 2, GL_FLOAT, false, 0, 0)
 
t = 0
 
# Loop until the user closes the window
while !GLFW.WindowShouldClose(window)   
    # Pulse the background blue
    t += 1
    glClearColor(0.0, 0.0, 0.5 * (1 + sin(t * 0.02)), 1.0)
    glClear(GL_COLOR_BUFFER_BIT)
    # Draw our triangle
    glDrawArrays(GL_TRIANGLES, 0, 3)
 
    # Swap front and back buffers
    GLFW.SwapBuffers(window)
 
    # Poll for and process events
    GLFW.PollEvents()
end
 
GLFW.Terminate()
 
end