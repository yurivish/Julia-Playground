import GLFW
using ModernGL

include("gltools.jl")
include("rgb.jl")

type MouseState
    x::Float64
    y::Float64
    pressed::Bool
end

function display(width, height, f; title="Julia")
    # Width and height are in screen coordinates, not pixels

    GLFW.Init()
     
    @osx_only begin
        # OS X-specific GLFW hints to specify the correct 
        # version of OpenGL at context creation time
        GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
        GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 2)
        GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE)
        GLFW.WindowHint(GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE)
    end

    # Create a window with an OpenGL context
    window = GLFW.CreateWindow(width, height, title)
     
    # Make the window's context current
    GLFW.MakeContextCurrent(window)
     
    # Initialize a vertex array
    vao = glGenVertexArray()
    glBindVertexArray(vao)
    glCheckError("binding vertex array")

    # Initialize a buffer for vertices
    vbo = glGenBuffer()
    glBindBuffer(GL_ARRAY_BUFFER, vbo)
    glCheckError("binding buffer")

    # Bind the data to the VBO
    # Specifies a fullscreen rectangle in standard coordinates.
    # [top left, top right, bottom left, bottom right]
    data = GLfloat[1, -1, 1, 1, -1, -1, -1, 1]
    glBufferData(GL_ARRAY_BUFFER, sizeof(data), data, GL_STATIC_DRAW)
    glCheckError("setting buffer data")

    # Initialize a texture for color data
    tex = glGenTexture()
    glBindTexture(GL_TEXTURE_2D, tex)
    glTexStorage2D(GL_TEXTURE_2D, 1, GL_RGB8, width, height)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)

    glCheckError("initializing texture")


    # Create and initialize shaders
    program = begin
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
            uniform vec2 screenDimsInPixels;
            uniform sampler2D tex;
            uniform float zoom;
            
            void main() {
                vec2 pos = gl_FragCoord.xy / screenDimsInPixels;
                vec2 zeroToCenter = vec2(0.5, 0.5);
                outColor = texture(tex, (pos - zeroToCenter) * zoom + zeroToCenter);
            }
        """

        vertexShader = createShader(vsh, GL_VERTEX_SHADER)
        fragmentShader = createShader(fsh, GL_FRAGMENT_SHADER)
        program = createShaderProgram(vertexShader, fragmentShader) do prog
            glBindFragDataLocation(prog, 0, "outColor")
        end

        glUseProgram(program)

        screenDimsInPixelsUniform = glGetUniformLocation(program, "screenDimsInPixels")
        @assert screenDimsInPixelsUniform > -1
        (pixelwidth::Float64, pixelheight::Float64) = GLFW.GetFramebufferSize(window)
        glUniform2f(screenDimsInPixelsUniform, pixelwidth, pixelheight)

        textureUniform = glGetUniformLocation(program, "tex")
        @assert textureUniform > -1

        zoomUniform = glGetUniformLocation(program, "zoom")
        @assert zoomUniform > -1
        glUniform1f(zoomUniform, 1.0)

        positionAttribute = glGetAttribLocation(program, "position")
        @assert positionAttribute > -1
        glEnableVertexAttribArray(positionAttribute)
        glVertexAttribPointer(positionAttribute, 2, GL_FLOAT, false, 0, 0)

        program
    end

    function drawtexture()
        # Activate and bind the texture
        glActiveTexture(GL_TEXTURE0)
        glBindTexture(GL_TEXTURE_2D, tex)

        # The uniform value for a sampler refers to the texture unit (0 refers to GL_TEXTURE0)
        glUniform1i(textureUniform, 0)

        # Draw the textured rectangle
        glBindVertexArray(vao)
        glBindBuffer(GL_ARRAY_BUFFER, vbo)
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4)
    end

    regenerate(f, args...) = global generator = @task f(zeros(GLPixel, width, height), args...)
    regenerate(f)

    GLFW.SetKeyCallback(window, (key, scancode, action, mods) -> begin
        if action == GLFW.RELEASE
            key = uppercase(convert(Char, key))
            key == 'R' && regenerate(f)
            key == 'Q' && GLFW.SetWindowShouldClose(window, GL_TRUE)
        end
    end)

    # For now, disable garbage collection due to the inefficiency of the pixel-placing code
    gc_disable()

    zoom::GLfloat = 1.0

    # Event loop
    while !GLFW.WindowShouldClose(window)   
        # Clear the screen
        glClearColor(0.0, 0.0, 0.0, 1.0)
        glClear(GL_COLOR_BUFFER_BIT)

        if !istaskdone(generator)
            (mx, my) = GLFW.GetCursorPos(window)
            mx = clamp(mx, 0, width) / width
            my = clamp(my, 0, height) / height
            pressed = GLFW.GetMouseButton(window, GLFW.MOUSE_BUTTON_LEFT) == GLFW.PRESS
            glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width, height, GL_RGB, GL_UNSIGNED_BYTE, consume(generator, MouseState(mx, my, pressed)))
        end

        glUniform1f(zoomUniform, zoom)

        # The pixel dimensions of the window may change here, e.g.
        # if the window is dragged from a high-dpi monitor to a low-dpi one.
        (pixelwidth, pixelheight) = GLFW.GetFramebufferSize(window)
        glUniform2f(screenDimsInPixelsUniform, pixelwidth, pixelheight)

        drawtexture()

        # Swap front and back buffers
        GLFW.SwapBuffers(window)
     
        # Poll for and process events
        GLFW.PollEvents()
    end

    gc_enable()
    gc()

    glDeleteTextures(1, [tex])
    GLFW.Terminate()
end

 
