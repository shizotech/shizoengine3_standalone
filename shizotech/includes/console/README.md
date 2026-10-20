# console — eye candy for console programs

Colours, boxes, tables, progress bars, spinners, titles and trees for programs that run in a terminal. Plain ANSI
escape sequences, no module.

```
#include "console/console"

console.title("My tool", "Version 1.0");
console.success("Connected");
console.box("Line one\nLine two", [title = "Info", color = "cyan"]);
console.table([[name = "Wash 1", universe = 1], [name = "LED bar", universe = 2]]);

bar = console.progress("Loading", 100);
for (i = 0; i <= 100; i++) {
	bar.update(i);
	std.sleep(10);
}
bar.done();
```

`console_demo.shio` shows everything (`shz console_demo.shio`, `--plain` without colours, `--ascii` without unicode
frames). `console_selftest.shio` is the test.

## Settings

| Call | |
|---|---|
| `console.colors(false)` | No escape sequences at all: for log files, pipes, consoles that do not understand them |
| `console.unicode(false)` | ASCII frames and symbols (`+-+`, `|`, `#`) instead of `╭─╮`, `✓`, `█` |
| `console.width(100)` | Width of `rule()`, `title()` (default 80) |

Without an argument each one returns the current value; with one it returns `console`, so they chain.

## Styles

`console.style(text, spec)` returns the text with the style and a reset at the end. A spec is a list of words:

- colours: `black red green yellow blue magenta cyan white gray`, `bright_red` ... `bright_white`, or `#rrggbb` / `#rgb`
  (24 bit)
- background: the same with `on_` (`on_blue`, `on_#202030`)
- attributes: `bold dim italic underline blink reverse strike`

```
console.print(console.style("ALERT", "bold white on_red") + " " + console.style("details", "gray"));
```

Shortcuts: `bold dim italic underline red green yellow blue magenta cyan gray`, `rgb(text, r, g, b)`,
`gradient(text, from = "#ff0080", to = "#00c0ff")` (each character a colour between the two, `"#rrggbb"` or `[r, g, b]`),
`rainbow(text)`.

## Output

| Call | |
|---|---|
| `print(text)` / `write(text)` | With / without a line end (`std.cout`, flushed at once) |
| `newline(n = 1)` | Empty lines |
| `success(t)` `info(t)` `warn(t)` `error(t)` | A line with a coloured `✓ i ▲ ✗` (symbols without an emoji form, so every terminal shows them one column wide in the colour) |
| `bullet(t)` | `  • t` |
| `step(i, n, t)` | `[2/5] t` |
| `rule(title = "", color = "gray")` | A line over the whole width, the title in the middle |
| `title(text, subtitle = "", opts)` | The text as a gradient in a double frame over the whole width. opts: `from`, `to`, `style`, `color` |
| `box(text, opts)` | A frame around text (several lines with `\n`). opts: `title`, `style` (`round` default, `single`, `double`, `heavy`, `ascii`), `color` (frame, default `gray`), `title_color`, `padding` (default 1), `width` (inner width, longer lines are cut), `align` (`left`, `center`, `right`) |
| `table(rows, opts)` | rows: a list of objects (the keys of the first one are the columns) or a list of lists. opts: `header` (list of titles), `style`, `color`, `header_style` (default `bold cyan`), `align` (list per column; numbers are right aligned by default), `max_width` (per column, default 40, longer cells are cut with `…`) |
| `kv(object, key_style = "cyan")` | `key  value` lines, keys aligned |
| `tree(data, root = "")` | A JSON value as a tree (`├──`, `└──`) |
| `clear()` `cursor_hide()` `cursor_show()` `move_to(col, row)` `up(n)` | Screen and cursor (nothing without colours) |

Every block has a `..._lines()` variant that returns the lines instead of printing them (`box_lines`, `table_lines`,
`kv_lines`, `tree_lines`), to combine or log them.

Text helpers: `strip(text)` (the text without escape sequences), `visible_length(text)` (characters as they show, a
UTF-8 character counts once), `pad(text, width, align)`, `truncate(text, width)`, `repeat(s, n)`, `duration(seconds)`
(`"2m 05s"`).

## Progress bars and spinners

```
bar = console.progress("Files", files.size(), [width = 30, color = "cyan"]);
for (i, f : files) {
	copy(f);
	bar.update(i + 1);       // or bar.step()
}
bar.done();                  // or bar.done("Copied " + files.size() + " files")

sp = console.spinner("Connecting");
for (!connected()) {
	sp.tick();               // next frame; sp.tick("new text") changes the text
	std.sleep(80);
}
sp.done("Connected");        // ✓ Connected; sp.fail("No answer") prints ✗
```

`sp.start()` animates the spinner in a task of its own. Tasks take turns: it only moves while the task that started it
waits (`std.sleep`, a network call, `join()` ...). In a long loop that does not wait, call `tick()` instead.

The bar and the spinner redraw their line with `\r`: print nothing else until `done()`. They hide the cursor while
they run, `done()` shows it again.

## Notes

- The include defines the global `console` and the classes `shz_console`, `shz_console_progress` and
  `shz_console_spinner`. Its local variables are declared with `var`, so globals of the script with the same names
  are left alone.
- Windows: shz switches the console to UTF-8 and ANSI escape sequences when it starts (since the change for issue
  #489 of shizoscript3_source). With an older shz use Windows Terminal (or `chcp 65001`), or `console.unicode(false)`
  and `console.colors(false)`.
- Output into a file or a pipe keeps the escape sequences: call `console.colors(false)` there.
