# Kernels (issue #199)

A **kernel** is a small function in a typed, byte level sub-language that is compiled by its own compiler into
typed register bytecode and runs on its own VM, directly on the bytes of a `std.buffer` (or a string, or any
object that exposes raw memory). A launch runs the kernel once for every index of a domain and spreads the
work over all cores.

```
kernel void gamma(u8* px, const u8* lut)
{
    px[gid] = lut[px[gid]];
}

px = std.buffer();
px.resize(w * h * 4);
...
launch gamma(px, lut) : w * h * 4;      // same as gamma.launch(w * h * 4, px, lut)
```

Everything a kernel works on has a fixed type and a fixed size. There are no `shzvar`s, no reference counts, no
allocations, no strings, no json and no calls back into script code inside a kernel. That is what makes them
fast, and what makes running them on several threads safe.

Files:

| file | content |
|---|---|
| `compiler/shz_kernel_defs.h` | types, bytecode (opcode list), program / unit format, traps |
| `compiler/shz_kernel_ops.h` | exact semantics of every operation (shared by the VM and the constant folding) |
| `compiler/shz_kernel_compiler.{h,cpp}` | lexer, parser, type checker, code generator |
| `compiler/shz_kernel_vm.{h,cpp}`, `shz_kernel_vm_ops.h` | scalar and batch interpreter, launch runtime, disassembler |
| `compiler/shz_kernel_jit.{h,cpp}` | JIT: bytecode to C, compiling with the installed C compiler, cache, loading |
| `compiler/shz_kernel_source.{h,cpp}` | cuts kernel declarations out of `.shio` files, `launch` statement |
| `builtin_types/shz_std_kernel.{h,cpp}` | `std.kernel_compile`, `std.kernel`, `std.kernel_job`, `std.kernel_struct` |
| `_testing/kernels.shio` | tests (compile errors, semantics, all interpreters and thread counts) |
| `_testing/benchmarks/kernels_bench.{shio,cpp}` | the acceptance benchmarks and the C++ reference |

The kernel compiler is a separate module. It shares nothing with `shz_lexer` / `shz_asm_builder` except that the
script lexer hands it the text of the declarations, so it cannot change how normal script code compiles.

---

## 1. Design decisions (the open questions of the issue)

1. **Embedded or separate source?** Both. Kernel declarations are written directly into `.shio` files at the top
   level (also in `#include`d files, the include resolution is the normal one). `std.kernel_compile(source)`
   compiles kernel source from a string at runtime. All declarations of one compilation (a file and its
   includes) form one *kernel unit*: structs, constants and helpers are shared between its kernels.
2. **Index space or `parallel_for`?** Index space: a launch runs the kernel for `gid = 0 .. domain - 1`
   (CUDA-like, `gid` / `gsize`), with 2D domains (`gid_x`, `gid_y`) for images. On a CPU the natural form is
   *one gid per element*. The CUDA grid-stride idiom (`for (i = gid; i < n; i += gsize)`) works and gives the
   same result, but with a small domain neighbouring gids walk the buffer `gsize` bytes apart, which is
   cache-hostile on a CPU (5-6x slower in the LUT benchmark). A kernel that needs a loop over a range of its
   own (histograms per slice) uses a small domain and loops over a contiguous slice.
3. **Pure kernels?** Yes. No calls into script, no I/O, no allocation. Kernel memory is only the memory of the
   pointer arguments and the registers of the lane.
4. **SIMD?** No vector opcodes. The batch interpreter executes every instruction for 64 consecutive gids, the
   per-lane loops are simple enough for the C++ compiler to vectorize. The vector types of the language
   (`f32x4`, ...) are computed component by component (the JIT's C compiler vectorizes where it can).
5. **AOT to C?** At runtime: the JIT (section 6) translates the bytecode of a kernel into C at its first launch,
   compiles it with the C compiler that is installed on the machine and runs the native code from then on. That
   is what reaches "within ~2x of C" per thread (section 8). Without a compiler the VM runs the kernel, with the
   same results.

The `cstruct` keyword that was stubbed in `shz_lexer.cpp` is now the same as `kernel struct`: a packed,
fixed-layout struct that kernels use through pointers and the host reads and writes through
`std.kernel_struct` (one design for both, as the issue asked).

---

## 2. Language

### Declarations

```
kernel struct Vec2 { f32 x; f32 y; }                 // packed, fields in declaration order
cstruct Particle { Vec2 pos; Vec2 vel; u8 tag[3]; u8 alive; }   // same as "kernel struct"
kernel const i32 SCALE = 3;                          // compile time constant
kernel inline f32 lerp(f32 a, f32 b, f32 t) { return a + (b - a) * t; }   // helper, inlined
kernel void move(Particle* p, f32 dt) { ... }        // entry kernel (launchable)
kernel i64 total(const i32* a) reduce(+) { return a[gid]; }   // entry kernel with a reduction
```

- Declarations must be at the top level of a file. Entry kernels and structs become script variables with
  their name at the place of the first declaration of the file, so declare kernels above the functions that use
  them (normal scoping rules). The kernel unit itself is the global `__shz_kernel_unit` (constants:
  `__shz_kernel_unit.SCALE`).
- In `std.kernel_compile()` source the `kernel` prefix is optional.
- Helpers (`kernel inline`) can only be called from kernel code. They are inlined, recursion is a compile error.
  Their arguments are copies (pointers stay bound to the memory of the caller's argument); they take and return
  numbers, pointers, struct and vector values.
- Entry kernels cannot be called from kernels. Their parameters are numbers, bools and pointers (structs only
  behind a pointer).
- **Imports**: `std.kernel_compile(source, file, unit, ...)` (units or lists of units: `std.kernel_compile`
  results or `__shz_kernel_unit`) compiles `source` with the structs, constants and helpers of the imported
  units (also the ones they import). Imported structs and constants become part of the new unit; imported entry
  kernels do not. A name declared twice is a compile error.

### Types

| type | |
|---|---|
| `bool` | `true` / `false`, result of comparisons, the only type allowed as a condition |
| `i8 u8 i16 u16 i32 u32 i64 u64` | integers, two's complement |
| `f32 f64` | IEEE floats |
| `T*`, `const T*` | pointer to a number type, a vector or a kernel struct (`bool*` is not allowed, use `u8*`) |
| kernel structs | in memory (behind a pointer, struct fields) and as values (local variables, helper parameters and results, reduction results) |
| vectors | `<number type>x<2..4>`: `f32x4`, `u8x3`, `i32x2`, ... built-in structs with the fields `x y z w` |
| `T name[N]` | local fixed size arrays of numbers, vectors or structs (N is a constant) |

Local variables are numbers, bools, pointers, struct / vector values and fixed size arrays:

```
Pixel q = p[gid];               // a copy (q.r = 7 does not change p)
q.r = 7;
p[gid] = q;
Vec2 v = { 1.0, 2.0 };          // {...} lists: fields / elements in order, missing ones are 0
u32 counts[16];                 // starts zeroed
u8 lut[4] = { 0, 85, 170, 255 };
counts[x & 15u] += 1u;          // index checked against the array size (unless unchecked)
```

Struct, vector and array variables are zeroed when they are declared (also in every iteration of a loop that
declares them), so the result never depends on what an earlier invocation left behind. They live in a small per
lane memory frame (sizes are fixed at compile time, at most 1 MiB per kernel, a bigger one is a compile error).
Kernels that use the frame run on the scalar interpreter (or the JIT), not the batch interpreter. That includes
temporary values: vector arithmetic (`out[gid] = a[gid] * 2.0` on `f32x4`), helpers that take or return structs,
`return {...}`.

**Vectors** work componentwise: `+ - * / % & | ^ << >>` between two vectors of the same size or a vector and a
number (`v * 2.0`), unary `- ~`, `+= -= ...`, and the builtins `min max clamp abs sqrt floor ceil round trunc sin
cos tan asin acos atan exp log log2 log10 pow atan2` (vector arguments componentwise, number arguments for every
component). The component type follows the rules for numbers: `u8x4 + u8x4` is an `i32x4` (convert back with
`u8x4(...)`). `f32x4(x, y, z, w)` builds a vector, `f32x4(s)` repeats `s`, `f32x4(v)` converts a vector with
4 components (each component like `f32(x)`). `dot(a, b)` (a number), `cross(a, b)` (3 components) and
`length(v)` (float vectors). Vectors cannot be compared (compare the components).

**Conversions are explicit**, the only implicit conversions are the ones that cannot lose anything:

- `i8 u8 i16 u16` are read as `i32` (like C): `p[i] + 1` is an `i32`.
- integer widening that keeps every value (`i32 -> i64`, `u32 -> i64`, `u8 -> u32`, `u32 -> u64`, ...) and `f32 -> f64`.
- integer literals adapt to the other side when they fit (`u8 x = 200`, `f32 f = 1`), float literals become
  `f32` / `f64` (`2.2`, `2.2f` is an `f32`).

Everything else needs a conversion `T(x)`: `u8(x + 1)`, `f32(i)`, `i32(f)`, `u32(n)`, `bool(x)` (`x != 0`).
Mixing `i32` and `u32` in one operation is an error. `i32(f)` truncates toward zero; a float that does not fit
into the target type (or NaN) is a runtime error. Integer to integer conversions wrap (`u8(300) == 44`).

### Operators and statements

- `+ - * / %` (numbers), `& | ^ ~ << >>` (integers; `& | ^` also bools), `== != < <= > >=`, `&& || !` (bools,
  short circuit), `?:`, `sizeof(T)`.
- `+ - *` and `<<` wrap. Integer `/` and `%` round toward zero (`-7 % 3 == -1`); division by zero and
  `INT_MIN / -1` are runtime errors. Shift counts are masked to the operand width (`x << 33` on an `i32` `x`
  is `x << 1`), so every shift is defined. Operations on two literals are computed exactly at compile time
  (`1 << 33` is 8589934592, which does not fit into an `i32`).
- `=` and `+= -= *= /= %= &= |= ^= <<= >>=`, `x++` / `x--` (statements only). The result must fit the target
  type like for `=`: on `i8 u8 i16 u16` targets (`u8 x; x++;`, `p[i] += 1` with `u8* p`) the `i32` result needs
  the explicit form `x = u8(x + 1);`.
- `if` / `else`, `for (init; cond; step)`, `while`, `break`, `continue`, `return`, `{ }` blocks with their own
  scope, `unchecked { ... }` (see bounds checks).
- Builtin functions: `min max clamp abs` (numbers), `sqrt floor ceil round trunc sin cos tan asin acos atan
  exp log log2 log10` and `pow atan2` (`f32` / `f64`), `atomic_add(p[i], v)` (`i32 u32 i64 u64` memory,
  returns the old value).
- Builtin values (`u32`, read only): `gid`, `gsize` (the domain size), and for 2D domains `gid_x`, `gid_y`,
  `gsize_x`, `gsize_y` (`gid = gid_y * gsize_x + gid_x`; a 1D launch has `gid_x = gid`, `gsize_y = 1`).
- Kernel parameters are read only (copy them into a local to change them).

### Pointers and structs

```
p[i]  *p  p->f  p[i].f  p[i].pos.x  p[i].tag[2]  &p[i]  p + n  p - n  q - p  q < p  q++  q += n
```

Pointer variables (`u8* q = p + 2;`) always point into one parameter; assigning a pointer into another
parameter is a compile error. Struct values are copied with `=` (`p[i] = q[j];`, `Pixel c = p[i];`). There are
no pointers to local variables.

Kernel structs are **packed**: no padding, fields in declaration order, so they map byte-exactly onto a
`std.buffer` (add padding fields if a layout needs alignment). Arrays of structs are pointers to structs.

### Bounds checks

Every memory access is checked: one unsigned compare of the element index against the element count of the
argument (and against the size of a fixed size array field or local array; constant indexes are checked when the
kernel compiles). A failed check stops the launch with an error.
`unchecked { ... }` turns the checks off for its body (lexically, not for the helpers it calls): an out of
bounds access there is undefined behaviour, like in C.

In an index of the form `x + c` / `x - c` with a literal `c` (`p[i + 1]`, `p[gid - 3]`) the constant is added
to the index in 64 bit, without 32 bit wraparound: `p[gid - 1]` with `gid == 0` is index -1 (out of bounds),
not 4294967295. Every other expression, also the rest of the index, wraps as described above.

### Reductions

A kernel with a return type needs `reduce(op)` with `op` one of `+ min max & | ^` (`& | ^` for integers and
bools). The launch returns the reduction of all values returned by the invocations (an invocation that does
not return a value contributes nothing; an empty domain returns the identity, e.g. `0` for `+`). The values are
combined in gid order inside a chunk and the chunk results in chunk order; the chunk size only depends on the
domain, so the result does not depend on the number of threads or the interpreter, **also for float sums**.

A kernel can return a struct (or a vector). `reduce(op)` then applies to every number field; with
`reduce(field: op, ...)` every top level field gets its own operation (all fields need one; nested structs and
arrays are reduced element by element). The fields must be `i32 u32 i64 u64 f32 f64`. The launch returns a json
object:

```
kernel struct Stats { f64 sum; f32 lo; f32 hi; u32 n; }
kernel Stats stats(const f32* a) reduce(sum: +, lo: min, hi: max, n: +)
{
    return { f64(a[gid]), a[gid], a[gid], 1u };
}
s = stats.launch(n, data);      // [sum = ..., lo = ..., hi = ..., n = ...]
kernel f32x4 total(const f32x4* v) reduce(+) { return v[gid]; }   // [x = ..., y = ..., z = ..., w = ...]
```

---

## 3. Host API

```
k.launch(domain, args...)          // runs and waits, returns the reduction result (None for void kernels)
launch k(args...) : domain;        // the same (statement or expression); also launch ks[i](...) : n, launch o.k(...) : n
job = k.launch_async(domain, args...)   // starts on the worker threads, returns a std.kernel_job
launch async k(args...) : domain   // the same
job.wait()                         // helps finishing, waits, returns the result, unlocks the buffers
job.done()                         // all lanes finished
k.disasm()  k.params()  k.returns()  k.name()

u = std.kernel_compile(source [, file] [, units...])   // std.kernel_unit; units: imports (section 2)
u.name / u.get(name)               // kernel (std.kernel), struct (std.kernel_struct) or constant
u.kernels()  u.structs()  u.constants()  u.disasm()

std.kernel_threads([n])            // threads per launch including the launching one, 0 = all (default)
std.kernel_mode(["auto" | "scalar" | "batch"])   // interpreter selection for tests / benchmarks
std.kernel_jit(["auto" | "sync" | "off"])        // JIT policy (section 6), returns the current one
std.kernel_jit_compiler()          // the C compiler the JIT uses, "" if there is none
k.jit_status()                     // "off", "none", "compiling", "ready", "aot" or "failed: <compiler output>"
k.jit_source()                     // the C translation of the kernel
std.kernel_aot_source(k | unit | list, ...)   // C file with the native code of kernels (section 6)
std.kernel_aot_load(path)          // loads a shared library built from it, returns the number of kernels
```

`domain` is an int or `[width, height]` (at most 2^32 - 1 invocations).

**Arguments** are checked strictly, wrong types are errors, not conversions:

| parameter | accepted script values |
|---|---|
| `bool` | `true` / `false` (0 / 1) |
| integers | ints that fit into the type (`u8` parameter with 300 is an error) |
| `f32` / `f64` | floats only (`2.0`, not `2`; `std.float(x)` converts) |
| `T*` | `std.buffer` (object or binary value, e.g. from `fileio.read_file`), `bitmap.bitmap`, objects that implement `shz_kernel_memory` |
| `const T*` | the same, and strings (read only) |

The element count of a pointer argument is `size_in_bytes / sizeof(T)` (a partial last element is not
accessible). The same buffer may be passed to several parameters. For kernels declared in the same file the
argument count and literal arguments (`2` for an `f32`, `2.5` for an `i32`, a number for a pointer, a string
for a writable pointer) are compile errors, in `launch k(...) : n` statements and in `k.launch(n, ...)` /
`k.launch_async(n, ...)` calls. This check is skipped for a kernel name that the script also assigns or uses as
a parameter name (it may hold another kernel there) and for kernels reached through a path
(`unit.k.launch(...)`, `launch ks[i](...) : n`, `launch o.k(...) : n`); those launches are checked when they
run.

**Kernel structs on the host** (`Pixel` is a `std.kernel_struct`):

```
Pixel.size()  Pixel.fields()  Pixel.offset("pos.x")  Pixel.count(buf)   // buf: std.buffer or e.g. a bitmap
Pixel.get(buf, i, "pos.x")  Pixel.set(buf, i, "tag[1]", 5)
Pixel.read(buf, i)          // json object (nested structs and arrays as json)
Pixel.write(buf, i, [r = 1, g = 2])   // missing fields are kept
```

**`std.buffer` additions** (prerequisites from #28): `resize(n [, fill])`, `fill(byte)`, `push(bytes...)`,
`append(buffer | string | list)`, `read(type, index)`, `write(type, index, value)` (typed element access,
little endian, the way kernels see the bytes; integers must fit), `string([start, count])` (the bytes as a
string, byte exact including zero bytes; `std.string(buffer)` keeps stopping at the first zero byte so existing
scripts that rely on it do not change).

**Errors** of a launch are runtime errors that `try` / `catch` can handle:

```
kernel 'oob_read' failed at kernels.shio:184 (gid 9): index 10 is out of bounds of 'p' (10 elements)
kernel 'div_zero' failed at kernels.shio:185 (gid 2): integer division by zero
kernel 'bad_float' failed at kernels.shio:186 (gid 1): float value 300 does not fit into u8
```

A failing lane stops the launch, the other lanes stop at their next chunk or loop iteration, the error is
reported once. When several gids would fail, which one is reported depends on the interpreter and the threads:
the scalar interpreter and the JIT report the first failing gid of their chunk, the batch interpreter the first
lane that fails at the earliest failing instruction of a batch. The memory the launch wrote before the error is not
defined. Compile errors are reported when the script is compiled (also by `shz --check`), with the
file, line and column inside the kernel.

---

## 4. Memory and threading model

- **Zero copy.** A pointer argument points straight at the bytes of the `std.buffer` (`shzbuffer`), the string or
  the memory an object exposes through `shz_kernel_memory` (`query_interface(shz_typeid<shz_kernel_memory>())`,
  pin counting with `shz_kernel_pins`). `bitmap.bitmap` implements it: a pointer parameter gets the pixels row
  by row, `bytes_per_pixel()` (3) bytes per pixel in the order **blue, green, red**
  (`kernel struct BGR { u8 b; u8 g; u8 r; }`, `launch k(bmp) : bmp.width() * bmp.height()`), and the bitmap
  methods follow the pinning rules below (drawing, `set_pixel`, `resize`, `load` while a launch uses it,
  `get_pixel` / `save` while a launch writes it are errors). The struct accessors (`Pixel.get(bmp, i, "r")`, ...)
  take such objects too. Test: `_testing/kernels_bitmap.shio` (needs a build with the bitmap module). Async launches copy string arguments (strings are
  copy-on-assign, a later assignment would move their bytes).
- **Pinning.** While a launch uses a buffer it is pinned (script thread, at launch and at `wait()`):
  - read by the launch (`const T*`): the script can read it, writing / resizing / clearing is an error;
  - written by the launch (`T*`): reading it is an error as well (indexing, `read`, `string`, comparing,
    copying it into another variable, writing it to a file);
  - a second launch that writes a buffer another running launch uses is an error.
  Assigning to a variable that holds a binary value which a launch still uses gives the variable new bytes; the
  launch keeps the old ones (no use after free). The job keeps the buffer objects alive until it is finished
  (dropping a job waits for it).
- **No script lock, no script objects in lanes.** Lanes only see raw memory and their registers; reference
  counts are only changed on the script thread (at launch and when the job finishes), so the #37 / #38 class of
  cross-thread refcount bugs cannot happen in kernels. A synchronous launch releases the script lock while it
  waits (other threads that need it are not blocked for the length of the launch, #94).
- **Thread pool.** Lanes are jobs on the existing `shz_thread_pool` of the script (one job per helper thread,
  not one per gid). The domain is split into at most 256 chunks (the chunk size only depends on the domain); lanes take the next chunk from an atomic
  counter, the launching thread works too. A full pool queue only means fewer helpers.
- **Determinism.** Kernels where every gid writes its own elements produce the same bytes for any number of
  threads and either interpreter. Reductions are deterministic (see above). Not deterministic: gids that read
  memory other gids write in the same launch, and the old values returned by `atomic_add` (the final memory of
  `atomic_add` on integers is deterministic).

---

## 5. VM

- **Registers**: one flat file of 64 bit slots per lane, sized at compile time: `gid`, `gsize`, the reduction
  accumulator, the 2D registers, parameters, the launch invariant values, locals / temporaries, then the
  constants. Integers are canonical (signed sign extended, unsigned zero extended to 64 bit), so widening is
  free and one compare serves `i32` and `i64`. Constants and arguments are written into the register image once
  per launch; nothing is allocated while a kernel runs.
- **Optimizer** (`kopt` in the compiler, on the bytecode): every value first gets its own virtual register; pure
  instructions that only depend on arguments and constants (`w * 3`, `h - 1`, the address of the lane frame) move
  into a *prologue* that runs once per lane runner (each thread of a launch, on its own frame), repeated pure instructions in a basic block are removed (`i - row` used three times), repeated
  loads of a block are merged while no store comes in between, bounds checks that an earlier access of the block
  did for the same index are dropped (`p[b] = p[b] + 1` checks once), unused pure instructions are dropped, and a
  liveness based register allocator packs the virtual registers (the LUT
  kernel needs one temporary register, the blur four plus three launch invariant values). Only instructions without side effects and without
  traps are moved or removed (a merged load or a dropped check repeats one that already ran, so the first one
  still traps).
- **Bytecode**: `{u16 op, u16 a, u16 b, u16 c, i64 imm}`, the operand types are part of the opcode
  (`ADD_I32`, `LD_U8`, `JFLT_F32`, ...), comparisons and branches are fused, `x + c` uses `ADDI`, division by a
  constant uses a multiplication (`DIVC`), `p[x + c]` folds `c` into the load. The disassembler (`k.disasm()`)
  prints it with the source line of every instruction.
- **Two interpreters, one set of instruction bodies** (`shz_kernel_vm_ops.h` is included twice):
  - scalar: one gid at a time, computed-goto dispatch (switch on MSVC);
  - batch: every instruction for 64 consecutive gids (column major register file, restrict-qualified lane
    loops that the compiler vectorizes). When the lanes of a batch take different branches, the batch stops at
    that jump and every lane finishes on the scalar interpreter from there. A runner that sees mostly
    divergent batches switches to the scalar interpreter for the rest of the launch.
- **Exactness**: constant folding runs the instruction through the VM, so a folded constant is always what the
  VM computes; reductions combine lanes in gid order, so the batch interpreter gives the same float results as
  the scalar one. `_testing/kernels.shio` runs kernels in every mode with 1 and with all threads and compares.

---

## 6. JIT

The VM is 3-10x slower per thread than a C loop (section 8): every value goes through the register file in
memory. The JIT removes that, with exactly the semantics of the VM:

- **Translation** (`shzk_jit_source`, `k.jit_source()`): the optimized bytecode is translated instruction by
  instruction into one C function. Every VM register becomes a C local, constants become literals, every
  pointer parameter gets its base, element count and stride as locals, jump targets become labels and the
  function loops over the gids of a chunk. Every instruction uses the same expression as `shz_kernel_ops.h`
  (wrapping integer arithmetic, canonical 64 bit registers, the same float to int checks, division by zero and
  bounds checks with the same trap codes and values), so errors read the same as on the VM. The C compiler then
  keeps the registers in CPU registers, removes what is not needed and vectorizes where it can.
- **Compiling**: with `SHZ_KERNEL_CC`, else the first of `cc`, `gcc`, `clang` (`cl`, `clang`, `gcc` on
  Windows) that answers `--version` (`/?`). Flags: `-O2 -shared -fPIC -fno-strict-aliasing -ffp-contract=off
  -fno-math-errno` (`/O2 /fp:precise /LD` for `cl`). `-ffp-contract=off` keeps the compiler from fusing
  `a * b + c` into an FMA, which would round differently from the VM. Math builtins (`sqrt`, `sin`, ...) call
  the C library in both, so they give the same results on the same machine.
- **Cache**: the library is stored as `k_<hash>.so` / `.dll` in `SHZ_KERNEL_CACHE`, else
  `$XDG_CACHE_HOME/shizoscript/kernels`, `~/.cache/shizoscript/kernels` or
  `%LOCALAPPDATA%\shizoscript\kernels`. The hash covers the C source, the compiler command, the flags and the
  JIT version, so a changed kernel or compiler never loads a stale library. It is compiled into a temporary
  name and renamed, so concurrent processes never load a half written file. A kernel takes ~75 ms to compile
  (one time per machine), loading it from the cache takes a few milliseconds. The cache directory is trusted
  like the interpreter itself (its libraries are loaded and run): point `SHZ_KERNEL_CACHE` only at a
  directory that only you can write.
- **Policy** (`std.kernel_jit(...)`, initial value from `SHZ_KERNEL_JIT`):
  - `auto` (default): the first launch of a kernel starts compiling it on the script's thread pool and runs on
    the VM; the launches after the library is loaded run native code (also when it comes from the cache, loading
    it is a background job too). Launches never wait for the compiler; a script that ends while a compile is
    still running exits when it is finished.
  - `sync`: the first launch compiles and waits (benchmarks, tests that compare the JIT with the VM).
  - `off`: VM only.
- **Fallback**: no compiler, a failing compile or a library that does not load leave the kernel on the VM;
  `k.jit_status()` says why (`failed: ...` with the compiler output). The JIT is used in `std.kernel_mode("auto")`
  only, the `scalar` / `batch` modes always run the interpreters.
- **Threads, chunks, reductions and aborts** stay in the launch runtime: the native function runs one chunk
  (the gids `begin .. end - 1`) with the register image of the launch and returns the trap of the first failing
  gid; reductions are combined in chunk order as on the VM. Loops poll the abort flag every 1024 iterations.
- The JIT is not available on microcontrollers and Emscripten (no compiler, no dynamic loading); they run the VM,
  or code compiled ahead of time (below).

`_testing/kernels.shio` runs every comparison with the JIT off, with `auto` and with `sync`, and checks that
the kernels are actually compiled when a compiler exists.

### Ahead of time (no compiler on the target)

`std.kernel_aot_source(kernels...)` (kernels, units or lists of them) returns one C file with the native code of
the kernels. A launch looks up its kernel by a hash of the generated C code (and the JIT version) before the JIT
compiles anything; a kernel whose bytecode changed (other source, other compiler version) does not match and
runs on the JIT / VM as usual. The file is independent of file names and paths. Two ways to use it:

- **Shared library** (a desktop target without a compiler): build it on a machine with one,
  `cc -O2 -shared -fPIC -fno-strict-aliasing -ffp-contract=off -fno-math-errno -DSHZK_AOT_SHARED -o kernels.so kernels.c`
  (`cl /O2 /fp:precise /LD /DSHZK_AOT_SHARED kernels.c` on Windows), ship it with the script and call
  `std.kernel_aot_load("kernels.so")` before the first launch. `k.jit_status()` is `"aot"` for kernels that use it.
- **Built into the interpreter** (microcontrollers, Emscripten, or a fixed set of kernels in a product): add the
  file to the build as a C++ source (`kernels.cpp`, e.g. next to the ESP32 sketch), compiled without fused
  multiply-add (`-ffp-contract=off`, `/fp:precise`). Its kernels register themselves at startup
  (`shzk_aot_register`), no dynamic loading is needed.

The generated code has the exact semantics of the VM (bounds checks, traps, the order of reductions), like the
JIT. `std.kernel_jit("off")` turns ahead of time code off as well.

---

## 7. Portability

- Microcontrollers (`SHZ_FEAT_MICROCONTROLLER`, no thread pool) and Emscripten run kernels on the launching
  thread (`launch_async` runs at once). Same results, same API.
- No compiler specific code is required: computed goto falls back to a switch, `__restrict` and the
  `optimize("O3")` attribute of the batch loop are only used where the compiler has them, 64x64 bit high
  multiplication has a portable fallback.

---

## 8. Benchmarks

`_testing/benchmarks/kernels_bench.shio` (kernels on the VM and with the JIT, and plain ShizoScript) and
`kernels_bench.cpp` (hand written C++ loops, `g++ -O2`, one thread). Linux x64, 4 cores, `g++ 13 -O2` build of
the interpreter, `cc` (gcc 13) for the JIT, best of 3:

| benchmark | plain ShizoScript | VM, 1 thread | VM, 4 threads | JIT, 1 thread | JIT, 4 threads | C++ loop, 1 thread |
|---|---|---|---|---|---|---|
| per byte LUT / gamma, 8 MiB | ~3776 ms | 20.2 ms | 4.9 ms | 4.2 ms | 1.1 ms | 2.5 ms |
| 3x3 box blur, 4096x4096 RGB | ~110592 ms | 787.6 ms | 205.3 ms | 221.2 ms | 64.5 ms | 134.2 ms |
| byte histogram (256 bins), 32 MiB, local bins | ~38400 ms | 376.0 ms | 98.3 ms | 29.4 ms | 7.5 ms | 16.9 ms |
| byte histogram, bins in a buffer | ~38400 ms | 163.0 ms | 52.9 ms | 42.6 ms | 10.9 ms | 16.9 ms |
| int32 dot product, 4 Mi | ~3904 ms | 12.8 ms | 3.5 ms | 4.2 ms | 1.0 ms | 2.6 ms |
| struct-of-Pixel transform, 4 Mi | ~5824 ms | 33.0 ms | 9.6 ms | 11.6 ms | 1.7 ms | 9.6 ms |

| benchmark | VM 1 thread vs C | JIT 1 thread vs C | JIT 4 threads vs C | JIT vs VM | JIT 1 thread vs script |
|---|---|---|---|---|---|
| LUT / gamma | 8.2x | 1.7x | 0.45x | 4.8x | 899x |
| 3x3 box blur | 5.9x | 1.6x | 0.48x | 3.6x | 500x |
| histogram, local bins | 22.3x | 1.7x | 0.45x | 12.8x | 1306x |
| histogram, bins in a buffer | 9.7x | 2.5x | 0.65x | 3.8x | 901x |
| int32 dot product | 4.8x | 1.6x | 0.38x | 3.0x | 930x |
| Pixel struct transform | 3.5x | 1.2x | 0.18x | 2.8x | 502x |

"~": the plain ShizoScript loop ran on 1/16 to 1/256 of the data and was scaled to the full size. The dot product
and the float sums give the same result for 1 and 4 threads, VM and JIT (checked by the benchmark and the
tests). The numbers vary by 10-20 % between runs on this machine (the C++ loops too).

The two histograms:

- *local bins* is what the C++ loop does: every gid counts a slice of 128 KiB into a local `u32 bins[256]` (in the
  lane frame, stays in the L1 cache) and adds them to the shared bins with 256 `atomic_add`s. Kernels with local
  arrays run on the scalar interpreter, so this is the fastest form with the JIT and the slowest on the VM.
- *bins in a buffer* counts 4096 slices into 4096 private bin sets of a 4 MiB buffer and sums them with a second
  kernel. It runs on the batch interpreter: the fastest form on the VM.

Reading the numbers:

- With the JIT one kernel thread is within 1.2-1.7x of the hand written C++ loop (the better histogram). The gap
  is the work the kernel semantics add: bounds checks (`unchecked { }` removes them; the optimizer drops checks
  an earlier access already did), 32 bit wrapping and canonical registers. This is the issue's target "within
  ~2x of a hand-written C loop" per thread. With 4 threads the JIT is 2.1-5.6x faster than the single threaded
  C++ loop.
- The VM alone is 3.5-9.7x slower than C per thread (an interpreter, even a batched one, moves every value
  through its register file in memory); with 4 threads it takes 1.0-3.1x the time of the single threaded C++
  loop.
- Against plain ShizoScript kernels are 140-305x faster on the VM and 500-1300x faster with the JIT, both on one
  thread.
- Scaling over threads is close to linear for the compute heavy kernels (blur 3.4x on 4 cores) and limited by
  memory bandwidth for the streaming ones (LUT, dot product).

---

## 9. Not done yet / next steps

- The JIT and ahead of time libraries on Windows (`cl` / `clang`) and macOS are implemented but not tested yet
  (Linux x64 with gcc is); the build into the interpreter is tested on Linux x64 (g++), not on an ESP32 yet.
- The optimizer merges loads and drops repeated bounds checks inside a basic block only; loads are not moved
  out of loops (a store through any pointer may change them, the same buffer can be passed twice).
- Struct, vector and array variables live in frame memory, not in registers (the JIT's C compiler keeps them
  in registers where it can, the VM loads and stores them).
- A per-lane arena if kernels should ever allocate.
