import pathlib, re, sys

src = pathlib.Path(sys.argv[1])
pat = sys.argv[2]
out = pathlib.Path(sys.argv[3])
rx = re.compile(pat, re.I)
t = src.read_text(encoding="utf-8", errors="replace")
lines = t.splitlines()
res = [f"== {src}: {len(lines)} lines, {len(t)} bytes"]
for i, line in enumerate(lines, 1):
    if rx.search(line):
        res.append(f"{i}: {line.rstrip()}")
out.write_text("\n".join(res), encoding="utf-8")
print(f"{len(res)-1} lines -> {out}")
