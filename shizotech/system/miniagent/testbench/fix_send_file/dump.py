import sys, pathlib
src = pathlib.Path(sys.argv[1])
dst = pathlib.Path(sys.argv[2])
ranges = sys.argv[3:]
lines = src.read_text(encoding="utf-8", errors="replace").splitlines()
out = []
for r in ranges:
    a, b = r.split("-")
    a, b = int(a), int(b)
    out.append(f"===== {src.name} {a}-{b} =====")
    for i in range(a, min(b, len(lines)) + 1):
        out.append(f"{i}: {lines[i-1]}")
dst.write_text("\n".join(out), encoding="utf-8")
print("wrote", dst, len(out))
