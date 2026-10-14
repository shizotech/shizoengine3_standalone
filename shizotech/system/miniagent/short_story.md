# The Last Off-By-One

The bug had a name, and the name was `i <= n`.

Mira found it at 2:47 in the morning, the hour at which every programmer is convinced that the
machine is personally against them. She had been chasing it for two days: a crash in the packet
serializer that only appeared on Tuesdays, only with full loads, and only for the one customer
whose logs nobody at the company was allowed to read.

She had done everything right. She had bisected the history. She had written the failing case as
a test, watched the test go red, and felt the small cold comfort of a problem that at least
existed reproducibly. She had added logging, removed the logging, added better logging. She had
explained the bug out loud to a rubber duck that she had bought as a joke in 2019 and had kept
because the jokes that survive long enough become tools.

And there it was, on line 412, in a loop she had written herself, in a commit she had made
herself, six months ago, at a speed she now found embarrassing.

```
for (i = 0; i <= n; i++)
    write(packet, buf[i]);
```

One extra iteration. One read past the end of a buffer that the allocator had, out of pure
politeness, padded with zeros for five hundred thousand runs. Then a reallocation moved the
buffer, the padding became somebody else's data, and the serializer began writing a stranger's
memory into a customer's packet. Not a crash. A leak. The kind of bug that does not announce
itself; it just quietly widens the door.

She fixed it. `i < n`. One character, deleted. The test went green, and the green was so quiet
after two days of noise that she sat there waiting for the rest of it, the part where the fix
turns out to be the symptom of something deeper. It did not come. That is the thing nobody tells
you about the worst bugs: they end with one keystroke and a full stop.

She committed it with the message `fix: off-by-one in serializer (never trust padding)`, and then
she did what she always did after a long hunt, which was to sit very still and remember that the
code had been correct in every way she had been checking. It compiled. It passed every test she
had written. It had run in production for six months, faithfully, honestly, doing exactly what
she had told it to do. The machine had never lied. She had simply asked it to count to the wrong
number, and it had obeyed with total sincerity, and the extra iteration had cost a stranger's
privacy.

That is the part of coding that never makes it into the tutorials. Not the syntax, not the
algorithms, not the clever trick with the bit masks. It is the moment you understand that the
program is not a description of what you meant. It is a description of what you said. Every
program is a transcript of a conversation, and the compiler has perfect memory and zero
imagination.

Mira wrote the postmortem at nine in the morning, in the flat language of the genre: what
happened, what was exposed, what we are changing. She added a bounds assertion to the writer, and
a test for the exact boundary, and a rule that no buffer is ever read past its declared length
under any allocation. Then she read her own commit from six months ago, the one with the loop,
and she noticed that it had a comment above it: `// fast path, n is always in range`.

She had believed it. That was the whole story of the bug, in eleven words. Not malice, not
stupidity — a sentence she had written on a good day and never read again.

She deleted the comment. She kept the assertion.

The duck watched from the monitor's edge, as it always did, saying nothing, which is the most
expensive form of code review there is.
