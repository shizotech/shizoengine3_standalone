import re, sys, pathlib

pat = sys.argv[1]
roots = sys.argv[2:] or ["."]
out = pathlib.Path("testbench/fix_send_file/out.txt")
exts = (".shio", ".md")
rx = re.compile(pat)
n = 0
with out.open("w", encoding="utf-8") as fh:
    for root in roots:
        p = pathlib.Path(root)
        files = [p] if p.is_file() else [f for f in p.rglob("*") if f.is_file()]
        for f in sorted(files):
            if f.suffix.lower() not in exts:
                continue
            if "testbench" in f.parts:
                continue
            try:
                txt = f.read_text(encoding="utf-8", errors="replace")
            except Exception:
                continue
            for i, line in enumerate(txt.splitlines(), 1):
                if rx.search(line):
                    fh.write(f"{f}:{i}: {line.rstrip()}\n")
                    n += 1
print(f"{n} matches -> {out}")
