## Patches: `apply` applies a unified diff to the text it was made from.

import "unified";

## Applies the unified diff `patch` to `text` and returns the new text.
##
## Each hunk must match `text` exactly where its `@@` header says: every
## unchanged and removed line, line ending included. A hunk that does not
## is an error; `apply` never shifts a hunk or matches it fuzzily. Lines
## before the first `@@` (`diff --git`, `index`, `---`, `+++`) are skipped,
## and hunks must come in order without overlapping, as `unified` and `git
## diff` write them. A patch with no hunks gives `text` unchanged.
##
## @param text the old text
## @param patch the diff, as `unified` writes it
## @returns the new text, or an error naming the line of the patch and of
##   `text` where they disagree
## @example
##     var patch = diff.unified("one\ntwo\n", "one\n2\n");
##     diff.apply("one\ntwo\n", patch).value();   # "one\n2\n"
##     diff.apply("one\nthree\n", patch).error().message;
##     # "patch line 3: hunk does not match line 2 of the text"
export apply(text: String, patch: String): Result<String> {
    var lines = split_lines(text);
    var patch_lines = split_lines(patch);
    var out = StringBuilder();
    # The next line of `text` not yet copied to `out`.
    var position = 0 as ulong;
    var index = 0 as ulong;
    while (index < patch_lines.count) {
        if (!patch_lines[index].starts_with("@@ ")) {
            index += 1;
            continue;
        }
        var header = index;
        var ranges = _hunk_header(patch_lines[header]);
        if (ranges.is_empty()) {
            return Result<String>.err($"patch line {header + 1}: malformed hunk header");
        }
        var (old_start, old_count, new_count) = ranges.value();
        index += 1;

        var old_side = Array<String>();
        var new_side = Array<String>();
        var last_kind = " ";
        while (index < patch_lines.count) {
            var line = patch_lines[index];
            if (line.starts_with("\\")) {
                # `\ No newline at end of file`: the line before has no newline.
                if (index == header + 1) {
                    return Result<String>.err($"patch line {index + 1}: '\\' before any line of the hunk");
                }
                if (last_kind != "+") {
                    old_side.append(_without_newline(old_side.pop()));
                }
                if (last_kind != "-") {
                    new_side.append(_without_newline(new_side.pop()));
                }
                index += 1;
                continue;
            }
            if (old_side.count == old_count && new_side.count == new_count) {
                break;
            }
            last_kind = line.substr_bytes(0, 1);
            if (last_kind != " " && last_kind != "-" && last_kind != "+") {
                return Result<String>.err($"patch line {index + 1}: expected a line starting with ' ', '-' or '+'");
            }
            var content = line.substr_bytes(1, line.size - 1);
            # A patch cut off after its last line still ends that line.
            if (!content.ends_with("\n")) {
                content = $"{content}\n";
            }
            if (last_kind == " " || last_kind == "-") {
                old_side.append(content);
            }
            if (last_kind == " " || last_kind == "+") {
                new_side.append(content);
            }
            if (old_side.count > old_count || new_side.count > new_count) {
                return Result<String>.err(
                    $"patch line {index + 1}: more lines than the hunk header at line {header + 1} counts"
                );
            }
            index += 1;
        }
        if (old_side.count != old_count || new_side.count != new_count) {
            return Result<String>.err($"patch line {header + 1}: the hunk has fewer lines than its header counts");
        }
        if (index < patch_lines.count && _is_body_line(patch_lines[index])) {
            return Result<String>.err(
                $"patch line {index + 1}: more lines than the hunk header at line {header + 1} counts"
            );
        }

        # A hunk that removes nothing names the line it goes after.
        var start = old_start;
        if (old_count > 0) {
            if (old_start == 0) {
                return Result<String>.err($"patch line {header + 1}: malformed hunk header");
            }
            start = old_start - 1;
        }
        if (start < position) {
            return Result<String>.err($"patch line {header + 1}: the hunk overlaps or comes before the one above it");
        }
        if (start + old_count > lines.count) {
            return Result<String>.err(
                $"patch line {header + 1}: the hunk runs past the end of the text, which has {lines.count} lines"
            );
        }
        for (var k in 0..old_count) {
            if (old_side[k] != lines[start + k]) {
                return Result<String>.err(
                    $"patch line {header + 1}: hunk does not match line {start + k + 1} of the text"
                );
            }
        }
        for (var i in position..start) {
            out.append(lines[i]);
        }
        for (var line in new_side) {
            out.append(line);
        }
        position = start + old_count;
    }
    for (var i in position..lines.count) {
        out.append(lines[i]);
    }
    return Result<String>.ok(out.to_string());
}

# The old start, old count and new count of `@@ -a,b +c,d @@`, or none when
# the line is not a hunk header.
_hunk_header(line: String): (ulong, ulong, ulong)? {
    var parts = line.split(" ");
    if (parts.count < 4 || !parts[1].starts_with("-") || !parts[2].starts_with("+") || !parts[3].starts_with("@@")) {
        return Optional<(ulong, ulong, ulong)>.Empty;
    }
    var old_range = _range_of(parts[1]);
    var new_range = _range_of(parts[2]);
    if (old_range.is_empty() || new_range.is_empty()) {
        return Optional<(ulong, ulong, ulong)>.Empty;
    }
    var (old_start, old_count) = old_range.value();
    var (new_start, new_count) = new_range.value();
    # The new start is not checked: the old side places the hunk.
    return Optional<(ulong, ulong, ulong)>.Value((old_start, old_count, new_count));
}

# The start and count of `-start,count` or `+start` (count 1).
_range_of(text: String): (ulong, ulong)? {
    var body = text.substr_bytes(1, text.size - 1);
    var count_text = "1";
    var split = body.split_once(",");
    if (!split.is_empty()) {
        var (start_text, rest) = split.value();
        body = start_text;
        count_text = rest;
    }
    var start = ulong.parse(body);
    var count = ulong.parse(count_text);
    if (start.is_empty() || count.is_empty()) {
        return Optional<(ulong, ulong)>.Empty;
    }
    return Optional<(ulong, ulong)>.Value((start.value(), count.value()));
}

# Whether `line` reads as a line of a hunk rather than the header of the
# next file's diff.
_is_body_line(line: String): bool {
    if (line.starts_with("--- ") || line.starts_with("+++ ")) {
        return false;
    }
    return line.starts_with(" ") || line.starts_with("-") || line.starts_with("+");
}

_without_newline(line: String): String {
    if (line.ends_with("\n")) {
        return line.substr_bytes(0, line.size - 1);
    }
    return line;
}
