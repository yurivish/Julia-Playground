# http://www.opengl.org/wiki/Program_Introspection#Uniforms_and_blocks

# immutable ShaderUniform
#     function new(program, name)
#         uniform = glGetUniformLocation(program, name)
#         @assert uniform > -1
#     end
# end

# tex = ShaderUniform("tex")
# set!(tex, 4) # Should assert the value is of the wrong type
# get(tex)

function glGenOne(glGenFn)
    id::Ptr{GLuint} = GLuint[0]
    glGenFn(1, id)
    glCheckError("generating a buffer, array, or texture")
    unsafe_load(id)
end
glGenBuffer() = glGenOne(glGenBuffers)
glGenVertexArray() =  glGenOne(glGenVertexArrays)
glGenTexture() =  glGenOne(glGenTextures)

function getInfoLog(obj::GLuint)
	# Return the info log for obj, whether it be a shader or a program.
	isShader = glIsShader(obj)
	getiv   = isShader == GL_TRUE ? glGetShaderiv      : glGetProgramiv
	getInfo = isShader == GL_TRUE ? glGetShaderInfoLog : glGetProgramInfoLog

	# Get the maximum possible length for the descriptive error message
	int::Ptr{GLint} = GLint[0]
	getiv(obj, GL_INFO_LOG_LENGTH, int)
	maxlength = unsafe_load(int)

	# TODO: Create a macro that turns the following into the above:
	# maxlength = @glPointer getiv(obj, GL_INFO_LOG_LENGTH, GLint)

	# Return the text of the message if there is any
	if maxlength > 0
		buffer = zeros(GLchar, maxlength)
		sizei::Ptr{GLsizei} = GLsizei[0]
		getInfo(obj, maxlength, sizei, buffer)
		length = unsafe_load(sizei)
		bytestring(pointer(buffer), length)
	else
		""
	end
end

function validateShader(shader)
	success::Ptr{GLint} = GLint[0]
	glGetShaderiv(shader, GL_COMPILE_STATUS, success)
	unsafe_load(success) == GL_TRUE
end

function glErrorMessage()
	# Return a string representing the current OpenGL error flag, or the empty string if there's no error.
	err = glGetError()
	err == GL_NO_ERROR ? "" :
	err == GL_INVALID_ENUM ? "GL_INVALID_ENUM: An unacceptable value is specified for an enumerated argument. The offending command is ignored and has no other side effect than to set the error flag." :
	err == GL_INVALID_VALUE ? "GL_INVALID_VALUE: A numeric argument is out of range. The offending command is ignored and has no other side effect than to set the error flag." :
	err == GL_INVALID_OPERATION ? "GL_INVALID_OPERATION: The specified operation is not allowed in the current state. The offending command is ignored and has no other side effect than to set the error flag." :
	err == GL_INVALID_FRAMEBUFFER_OPERATION ? "GL_INVALID_FRAMEBUFFER_OPERATION: The framebuffer object is not complete. The offending command is ignored and has no other side effect than to set the error flag." :
	err == GL_OUT_OF_MEMORY ? "GL_OUT_OF_MEMORY: There is not enough memory left to execute the command. The state of the GL is undefined, except for the state of the error flags, after this error is recorded." : "Unknown OpenGL error with error code $err."
end

function glCheckError(actionName="")
	message = glErrorMessage()
	if length(message) > 0
		if length(actionName) > 0
			error("Error ", actionName, ": ", message)
		else
			error("Error: ", message)
		end
	end
end

function createShader(source, typ)
	# Create the shader
	shader = glCreateShader(typ)::GLuint
	if shader == 0
		error("Error creating shader: ", glErrorMessage())
	end

	# Compile the shader
	glShaderSource(shader, 1, convert(Ptr{Uint8}, pointer([convert(Ptr{GLchar}, pointer(source))])), C_NULL)
	glCompileShader(shader)

	# Check for errors
	!validateShader(shader) && error("Shader creation error: ", getInfoLog(shader))
	shader
end

function createShaderProgram(f, vertexShader, fragmentShader)
	# Create, link then return a shader program for the given shaders.

	# Create the shader program
	prog = glCreateProgram()
	if prog == 0
		error("Error creating shader program: ", glErrorMessage())
	end

	# Attach the vertex shader
	glAttachShader(prog, vertexShader)
	glCheckError("attaching vertex shader")

	# Attach the fragment shader
	glAttachShader(prog, fragmentShader)
	glCheckError("attaching fragment shader")
	
	f(prog)

	# Finally, link the program and check for errors.
	glLinkProgram(prog)
	status::Ptr{GLint} = GLint[0]
	glGetProgramiv(prog, GL_LINK_STATUS, status)
	if unsafe_load(status) == GL_FALSE then
		glDeleteProgram(prog)
		error("Error linking shader: ", glGetInfoLog(prog))
	end

	prog
end
createShaderProgram(vertexShader, fragmentShader) = createShaderProgram(prog->0, vertexShader, fragmentShader)

function printGLInfo()
    println("GLSL version: ",    bytestring(glGetString(GL_SHADING_LANGUAGE_VERSION)))
    println("OpenGL version: ",  bytestring(glGetString(GL_VERSION)))
    println("OpenGL vendor: ",   bytestring(glGetString(GL_VENDOR)))
    println("OpenGL renderer: ", bytestring(glGetString(GL_RENDERER)))
end
