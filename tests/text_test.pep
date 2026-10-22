# The diff package's text side: unified diffs checked against `git diff`'s,
# `apply` round trips over generated texts, and the errors of a patch that
# does not fit.

import diff;
import io;
import os;
import random;

# The contents of `tests/fixtures/<name>`; tests/run.sh runs from the
# package's root.
fixture(name: String): String {
    return io.File.read_to_string(io.Path("tests").join("fixtures").join(name)).value();
}

# Checks `unified` of fixture `name`'s two files against `git diff`'s output
# saved as `<expected>.diff` (without its `diff --git` and `index` lines).
check_git(
    name: String,
    expected: String,
    context: ulong = 3,
    algorithm: diff.Algorithm = diff.Algorithm.Myers,
    location: __ptr<char> = __caller_location()
) {
    var old_text = fixture($"{name}.old");
    var new_text = fixture($"{name}.new");
    var patch = diff.unified(old_text, new_text, context, $"a/{name}.old", $"b/{name}.new", algorithm);
    expect_equal(patch, fixture($"{expected}.diff"), location);
    expect_equal(diff.apply(old_text, patch).value(), new_text, location);
}

[Test]
matches_git_diff() {
    check_git("two_hunks", "two_hunks");
    check_git("two_hunks", "two_hunks_u1", 1);
    check_git("merged", "merged");
    check_git("merged", "merged_u0", 0);
    check_git("no_newline", "no_newline");
    check_git("drop_newline", "drop_newline");
    check_git("ends", "ends");
    check_git("replace_all", "replace_all");
    check_git("patience", "patience_patience", 3, diff.Algorithm.Patience);
    # Plain `git diff` changes 21 lines here, since xdiff's heuristics give
    # up minimality; Myers finds the 20-line diff, which is patience's.
    check_git("patience", "patience_patience");
}

[Test]
splits_lines_with_their_endings() {
    expect_equal(diff.split_lines("").count, 0);
    var lines = diff.split_lines("a\r\nb\n\nc");
    expect_equal(lines.count, 4);
    expect_equal(lines[0], "a\r\n");
    expect_equal(lines[2], "\n");
    expect_equal(lines[3], "c");
    expect_equal(diff.split_lines("a\n").count, 1);
}

[Test]
equal_texts_give_an_empty_diff() {
    expect_equal(diff.unified("a\nb\n", "a\nb\n"), "");
    expect_equal(diff.apply("a\nb\n", "").value(), "a\nb\n");
}

# A text of up to `size` lines drawn from `generator`, from a few distinct
# lines, sometimes without a final newline.
random_text(generator: random.Generator, size: ulong): (String, random.Generator) {
    var g = generator;
    var words = ["a", "b", "c", "d", "e", "f", "", "  x"];
    var out = StringBuilder();
    var count = g.next_ulong() % (size + 1);
    for (var i in 0..count) {
        out.append(words[g.next_ulong() % words.count]);
        if (i + 1 < count || g.next_ulong() % 3 != 0) {
            out.append("\n");
        }
    }
    return (out.to_string(), g);
}

[Test]
apply_inverts_unified() {
    var g = random.Generator(19);
    for (var round in 0..3000) {
        var (a, g1) = random_text(g, 25);
        var (b, g2) = random_text(g1, 25);
        g = g2;
        var context = (round % 5) as ulong;
        var algorithm = diff.Algorithm.Myers;
        if (round % 2 == 1) {
            algorithm = diff.Algorithm.Patience;
        }
        var patch = diff.unified(a, b, context, algorithm = algorithm);
        var back = diff.apply(a, patch);
        expect_true(back.is_ok());
        expect_equal(back.value(), b);
    }
}

[Test]
rejects_a_hunk_that_does_not_match() {
    var patch = diff.unified("one\ntwo\nthree\n", "one\n2\nthree\n");
    expect_equal(diff.apply("one\ntwo\nthree\n", patch).value(), "one\n2\nthree\n");
    expect_equal(
        diff.apply("one\nTWO\nthree\n", patch).error().message, "patch line 3: hunk does not match line 2 of the text"
    );
    # The same lines one line further down do not match either: no offsets.
    expect_equal(
        diff.apply("zero\none\ntwo\nthree\n", patch).error().message,
        "patch line 3: hunk does not match line 1 of the text"
    );
    expect_equal(
        diff.apply("one\n", patch).error().message,
        "patch line 3: the hunk runs past the end of the text, which has 1 lines"
    );
    # A missing newline is a difference too.
    expect_true(diff.apply("one\ntwo\nthree", patch).is_err());
}

[Test]
rejects_a_malformed_patch() {
    var text = "a\nb\n";
    expect_equal(diff.apply(text, "@@ -x +1 @@\n").error().message, "patch line 1: malformed hunk header");
    expect_equal(diff.apply(text, "@@ -1 +1\n").error().message, "patch line 1: malformed hunk header");
    expect_equal(
        diff.apply(text, "@@ -1,2 +1,2 @@\n a\n").error().message,
        "patch line 1: the hunk has fewer lines than its header counts"
    );
    expect_equal(
        diff.apply(text, "@@ -1 +1 @@\n-a\n+A\n+B\n").error().message,
        "patch line 4: more lines than the hunk header at line 1 counts"
    );
    expect_equal(
        diff.apply(text, "@@ -1 +1 @@\n*a\n").error().message,
        "patch line 2: expected a line starting with ' ', '-' or '+'"
    );
    expect_equal(
        diff.apply(text, "@@ -1 +1 @@\n\\ No newline at end of file\n").error().message,
        "patch line 2: '\\' before any line of the hunk"
    );
    expect_equal(
        diff.apply(text, "@@ -2 +2 @@\n-b\n+B\n@@ -1 +1 @@\n-a\n+A\n").error().message,
        "patch line 4: the hunk overlaps or comes before the one above it"
    );
}

# Two texts of 10,000 lines that differ in 100 places, and the time to diff
# and patch them.
[Test]
diffs_large_texts() {
    var a = StringBuilder();
    var b = StringBuilder();
    for (var i in 0..10000) {
        var line = $"line {i}: some text that is the same in both\n";
        a.append(line);
        if (i % 100 == 50) {
            b.append($"line {i}: changed\n");
        } else {
            b.append(line);
        }
    }
    var old_text = a.to_string();
    var new_text = b.to_string();
    var start = os.Instant.now();
    var patch = diff.unified(old_text, new_text);
    var myers_time = start.elapsed();
    start = os.Instant.now();
    var patience_patch = diff.unified(old_text, new_text, algorithm = diff.Algorithm.Patience);
    var patience_time = start.elapsed();
    expect_equal(diff.apply(old_text, patch).value(), new_text);
    expect_equal(patch, patience_patch);
    print(
        $"10,000 lines, 100 changes: myers {myers_time.microseconds()} us, patience {patience_time.microseconds()} us"
    );
}
