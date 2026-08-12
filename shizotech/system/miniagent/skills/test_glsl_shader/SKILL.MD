# Test GLSL shader files

This skill adds the 'compile_glsl_file' tool.
Use this tool to check glsl files for compilation errors.

# Returns

The 'compile_glsl_file' returns the full GLSL code (+ shadertoy headers and the bootstrap code) with line numbers,
aswell as all error messages.

Fix the shader until it compiles without error messages.

