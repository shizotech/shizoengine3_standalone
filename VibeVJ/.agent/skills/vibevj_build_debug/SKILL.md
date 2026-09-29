
# BUILDING A NEW ASSET

1. Load the `shizoscript` and the `shizoscript_nanogui` skill to be able to debug shizoscript code.

2. Read `assets/ASSET_GUIDE.md` to understand how to implement new assets and check out `assets\Generators\ExampleBasics`.

3. Implement the new generator and make sure the shizoscript source file compile by using the shizoscript syntax checker.

4. Use the live tools and `vibevj_get_testarea` to test the generator inside the live enviroment that you are currently in:
  - Use `vibevj_query` to add the new asset to the test area
  - Inspect the new asset with `vibevj_capture` to make sure the UI and controls show and work correctly
  - Potentially fix runtime bugs and UI fails


# BUILDING A NEW SHADER

1. Read `assets/Shaders/SHADER_GUIDE.md` to understand how to implement new shaders.

2. Implement the new shader and make sure the shader source files compile by using the `test_glsl_file` tool.

3. Use the live tools and `vibevj_get_testarea` to test the shader inside the live enviroment that you are currently in:
  - Use `vibevj_query` to add the new shader to the test area
  - Inspect the new shader with `vibevj_capture` to make sure it looks right
  - Potentially fix shader code and visual appearance
  