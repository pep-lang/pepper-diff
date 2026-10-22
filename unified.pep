## Text diffs: `split_lines` cuts text into lines, and `unified` writes the
## difference of two texts as a unified diff, the format of `diff -u` and
## `git diff`.

import "edits";

## Which algorithm `unified` diffs lines with.
export enum Algorithm {
    ## `myers`: a shortest diff. The default, as in `git diff`.
    Myers,
    ## `patience`: anchors on lines that occur once in each text, as
    ## `git diff --patience` does.
    Patience,
}

## Splits `text` into lines, each keeping its `"\n"` (and a `"\r"` before
## it), so joining them gives `text` back. A last line with no `"\n"` is a
## line of its own; `""` has no lines.
##
## @param text the text to split
## @returns the lines, in order
## @example
##     diff.split_lines("a\nb");   # ["a\n", "b"]
export split_lines(text: String): String[] {
    var out = Array<String>();
    if (text.size == 0) {
        return out;
    }
    var parts = text.split("\n");
    var last = parts.pop();
    for (var part in parts) {
        out.append($"{part}\n");
    }
    if (last.size > 0) {
        out.append(last);
    }
    return out;
}

## Returns the unified diff that turns `a` into `b`: a `---` and a `+++`
## line naming the two sides, then one hunk for each group of changes, with
## `context` unchanged lines around it. A hunk starts with
## `@@ -start,count +start,count @@`, and its lines start with `' '`
## (unchanged), `'-'` (only in `a`) or `'+'` (only in `b`). A last line with
## no newline is followed by `\ No newline at end of file`. Changes at most
## `2 * context` lines apart share a hunk, as in `git diff`.
##
## Lines are compared whole, line endings included, so a `"\r\n"` line
## differs from the same line ending in `"\n"`.
##
## @param a the old text
## @param b the new text
## @param context how many unchanged lines to show around each change
## @param from_name what the `---` line names `a` as, such as `a/main.pep`
## @param to_name what the `+++` line names `b` as
## @param algorithm how to match the lines
## @returns the diff, or `""` when the texts are equal
## @example
##     diff.unified("one\ntwo\n", "one\n2\n");
##     # --- a
##     # +++ b
##     # @@ -1,2 +1,2 @@
##     #  one
##     # -two
##     # +2
export unified(
    a: String,
    b: String,
    context: ulong = 3,
    from_name: String = "a",
    to_name: String = "b",
    algorithm: Algorithm = Algorithm.Myers
): String {
    var old_lines = split_lines(a);
    var new_lines = split_lines(b);
    var edits: Edit[];
    if (algorithm == Algorithm.Patience) {
        edits = patience(old_lines, new_lines);
    } else {
        edits = myers(old_lines, new_lines);
    }
    var out = StringBuilder();
    var first = 0 as ulong;
    while (first < edits.count) {
        if (edits[first].kind == EditKind.Equal) {
            first += 1;
            continue;
        }
        # The hunk covers the changes from `first` to `last`, and the
        # unchanged runs between them, each at most 2 * context long
        # (written so that a huge context cannot overflow).
        var last = first;
        while (last + 1 < edits.count) {
            var next = edits[last + 1];
            if (next.kind != EditKind.Equal) {
                last += 1;
            } else if ((next.count + 1) / 2 <= context && last + 2 < edits.count) {
                last += 2;
            } else {
                break;
            }
        }
        var lead = 0 as ulong;
        if (first > 0) {
            lead = _min(context, edits[first - 1].count);
        }
        var trail = 0 as ulong;
        if (last + 1 < edits.count) {
            trail = _min(context, edits[last + 1].count);
        }
        var a_start = edits[first].a_start - lead;
        var b_start = edits[first].b_start - lead;
        var a_end = edits[last].a_start + trail;
        var b_end = edits[last].b_start + trail;
        if (edits[last].kind != EditKind.Insert) {
            a_end += edits[last].count;
        }
        if (edits[last].kind != EditKind.Delete) {
            b_end += edits[last].count;
        }

        if (out.is_empty) {
            out.append($"--- {from_name}\n+++ {to_name}\n");
        }
        out.append($"@@ -{_range(a_start, a_end - a_start)} +{_range(b_start, b_end - b_start)} @@\n");
        for (var i in a_start..a_start + lead) {
            _line(out, " ", old_lines[i]);
        }
        for (var e in first..last + 1) {
            var edit = edits[e];
            for (var k in 0..edit.count) {
                if (edit.kind == EditKind.Equal) {
                    _line(out, " ", old_lines[edit.a_start + k]);
                } else if (edit.kind == EditKind.Delete) {
                    _line(out, "-", old_lines[edit.a_start + k]);
                } else {
                    _line(out, "+", new_lines[edit.b_start + k]);
                }
            }
        }
        for (var i in a_end - trail..a_end) {
            _line(out, " ", old_lines[i]);
        }
        first = last + 1;
    }
    return out.to_string();
}

_min(a: ulong, b: ulong): ulong {
    if (a < b) {
        return a;
    }
    return b;
}

# A hunk header's range: `start,count` with `start` counted from 1, the
# count left out when it is 1, and `start` the line before when it is 0.
_range(start: ulong, count: ulong): String {
    if (count == 1) {
        return $"{start + 1}";
    }
    if (count == 0) {
        return $"{start},0";
    }
    return $"{start + 1},{count}";
}

_line(out: StringBuilder, prefix: String, line: String) {
    out.append(prefix);
    out.append(line);
    if (!line.ends_with("\n")) {
        out.append("\n\\ No newline at end of file\n");
    }
}
