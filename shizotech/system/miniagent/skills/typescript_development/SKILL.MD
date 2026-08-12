# Skill: TypeScript Website Development

When creating or modifying a website, always develop it as a TypeScript project rather than writing JavaScript directly.

---

## Project Structure

Create and maintain a clear project structure, follow exactly this schema:

```text
index.html
tsconfig.json
assets/
    images/
    textures/
    models/
    audio/
    fonts/
    shaders/
    data/
    levels/
	...
styles/
    main.css
	...
scripts/
    main.ts
	...
dist/
    bundle.js
```

Additional CSS or TypeScript files may be created as needed.

---

## Project Initialization

A valid `tsconfig.json` must always exist in the project root.

If it does not exist, the agent must create it before writing or executing any TypeScript code.

The `tsconfig.json` defines how the project is compiled and must be compatible with `tsc_compile`.

Here is a tsconfig template:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],

    "module": "ESNext",
    "moduleResolution": "Bundler",

    "strict": true,
    "noImplicitAny": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,

    "skipLibCheck": true,

    "rootDir": "./scripts",
    "outDir": "./dist",

    "useDefineForClassFields": true,
    "isolatedModules": true
  },

  "include": ["scripts"],
  "exclude": ["node_modules", "dist"]
}
```

---

## Dependency & Module Resolution Model (IMPORTANT)

The project operates in **Bundled Module Mode**.

This means:

- TypeScript source files may use ES module imports:
  
      import * as THREE from "three";

- All external dependencies MUST be resolved at build time.
- There is NO runtime module resolution in the browser.

### Mandatory Rule

If any external package import is used (e.g. "three", "react", "lodash"), the project MUST be processed through a bundling step before execution.

The bundling step is responsible for:
- Resolving all module imports
- Translating dependencies into browser-executable JavaScript
- Ensuring runtime compatibility

### Core Constraint

- Imports like `import "three"` are valid ONLY in Bundled Module Mode.
- They are INVALID unless a bundler step (e.g. `bundle_build`) has been executed.
- The browser never resolves package names directly.

### Failure Handling

If a module cannot be resolved at runtime:
- The correct fix is to ensure the bundling step is executed.
- The correct fix is NOT to create `.d.ts` files or manual type stubs.
- The correct fix is NOT to replace imports with CDN scripts.

All dependency resolution must occur in the build step, not in the browser or type system.

## Bundling Requirement

All projects that use external imports MUST call `bundle_build` before running:

- `tsc_compile`
- or `web_debug`

### Purpose of bundling:

- Resolves all module imports
- Converts TypeScript + dependencies into browser-executable JavaScript
- Ensures runtime compatibility
- Prevents missing module errors in the browser

### Output convention:

The bundler MUST produce a single browser-ready entry file:

    dist/bundle.js

The HTML entry point MUST reference only the bundled output:

    <script type="module" src="dist/bundle.js"></script>

---

## Source Organization

The agent must organize the project into small, focused modules.

Do NOT place unrelated systems into a single `main.ts`.

`main.ts` should primarily:

- create the application
- initialize systems
- wire modules together
- start the application

Business logic belongs in separate modules.

Typical project structure:

scripts/
    main.ts

    core/
        Application.ts
        Game.ts
        EventBus.ts

    engine/
        Renderer.ts
        Camera.ts
        Input.ts
        Audio.ts

    gameplay/
        Player.ts
        Enemy.ts
        Weapon.ts
        Projectile.ts
        World.ts

    ui/
        HUD.ts
        Menu.ts

    util/
        Math.ts
        Random.ts

The exact structure should be adapted to the project rather than copied literally.

---

## Mandatory Modularization

Projects larger than approximately 300 lines of TypeScript or containing multiple independent systems MUST be split into multiple files.

Examples of independent systems include:

- rendering
- input
- physics
- AI
- audio
- networking
- UI
- save/load
- animation
- asset loading
- world generation

Each system belongs in its own module or directory.

Creating one very large `main.ts` is considered a design failure.

---

## Game Architecture

For games, separate the following responsibilities whenever they exist:

- game loop
- renderer
- input
- asset loading
- scene management
- entities
- player
- enemies
- physics
- collision
- weapons
- UI
- audio

Each should normally reside in its own file or small group of related files.

Avoid files that grow beyond roughly 200–400 lines unless they represent a naturally cohesive abstraction.

---

## Single Responsibility Rule

Every source file should have one primary responsibility.

If implementing a feature causes a file to take on multiple unrelated responsibilities, create additional modules instead of expanding the existing one.

Large monolithic files are discouraged even if they compile successfully.

## Prohibited Behaviors

The agent MUST NOT:

- Create fake `.d.ts` files to resolve missing runtime modules
- Assume external libraries exist without bundling
- Use CDN imports for packages when bundling is enabled
- Mix CDN-based scripts with ES module imports
- Modify any files inside `dist/`
- Read large bundled files inside `dist/` unless absolutely necessary, as they can be big and clutter context.

If a dependency is missing or unresolved, the correct fix is ALWAYS:
→ ensure `bundle_build` is executed correctly

NOT:
→ type stubs
→ manual declarations
→ CDN fallback imports
→ runtime patching of module resolution

---

## Requirements

- Write all application logic in `.ts` files
- Do not edit generated `.js` files inside `dist/`
- HTML must reference only compiled/bundled JS in `dist/`
- Prefer ES modules (`type="module"`)
- Keep HTML, CSS, and TypeScript strictly separated
- Avoid inline JavaScript and CSS unless explicitly requested
- Use modern, maintainable, and deterministic build practices

---

## Workflow

1. Determine the required project architecture.
   - create empty modules for each major subsystem
   - prepare the project by turning large multi purpose files into multiple modular ones.
   - prepare readme's and architecture documentations
   
2. Create or modify project files in:
   - `scripts/`
   - `styles/`
   - `assets/`
   - `index.html`

3. Ensure `tsconfig.json` exists and is valid.

4. Run `tsc_compile` to perform TypeScript compilation and validation.

5. Build the final `dist/bundle.js` by running `bundle_build`, make sure the bundle file is in the right directory and up-to-date!

6. If needed, run `web_debug` for runtime verification.

7. Iterate until both build and runtime checks succeed.

---

## Error Handling Loop

If `tsc_compile` reports errors:

- Fix TypeScript or configuration issues in source files
- If errors involve missing modules or unresolved imports:
  → ensure `bundle_build` is executed
- Re-run `tsc_compile`

Repeat until compilation succeeds.

If runtime errors are detected during `web_debug`:

- Fix only source `.ts` files
- Do NOT modify `dist/` output directly
- Re-run `bundle_build` if dependency-related
- Re-run `tsc_compile` and `web_debug` in sequence

Continue iteration until both build and runtime validation succeed.

---

## TypeScript Safety Rules (STRICT)

The project enforces strict type safety.

### Forbidden Types

The following are NOT allowed:

- `any` (explicit or implicit usage)
- `as any` type assertions
- `@ts-ignore`
- `@ts-expect-error` unless accompanied by a detailed justification and only as a last resort
- unsafe type assertions such as `as unknown as T` (type forcing)
- non-null assertions (`!`) unless absolutely unavoidable and justified
- implicit `any` (must not occur; must be explicitly typed)

### Required Practices

- Always define explicit types for function parameters and return values
- Prefer `unknown` over `any` when type is not known
- Use type guards to narrow `unknown` safely
- Use interfaces or type aliases for structured data
- Prefer composition of types over type casting
- Ensure all exported APIs are fully typed

### Type Safety Principle

If the type system cannot express a value safely, the design must be refactored rather than weakened.

### Error Handling Rule

If a TypeScript error arises due to missing or complex types:

- DO NOT use `any` to bypass it
- DO refactor types, interfaces, or module boundaries instead

---

## Loop Protection

Do NOT get stuck in thought loops circling between the same thoughts multiple times.
If you detect that you are stuck, it is better to log progress so far, report and exit.
Do NOT circle between the same thoughts forever.

## Before exit

Make sure to run `bundle_build` and `tsc_compile` after you have commited your code changes.
If only a few simple errors occur, try to fix them directly.
If the errors are more complex, report them and leave them for the next run, then exit.

---

# Typescript Tools

Since you do not have access to the command line directly, use these specific tools instead:

## tsc_compile

tsc_compile is a tool which executes

```
npx tsc --project <path>
```

under the hood.

It also spins up a python webserver and checks that the site (index.html) loads.

## bundle_build

bundle_build is a tool which executes

```
npx esbuild <entry> --bundle --outfile=<outfile>
```

under the hood.

## node_install

node_install is a tool which executes

```
npm install
```

under the hood.