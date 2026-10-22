# The diff package's edit scripts: `myers` is a shortest one, `patience`
# a valid one, over generated inputs.

import diff;
import random;

# Two arrays drawn from `seed`: up to `size` elements each from an alphabet
# of `letters`, with `b` mostly a mutated copy of `a` so they share runs.
random_pair(seed: ulong, size: ulong, letters: ulong): (int[], int[]) {
    var g = random.Generator(seed);
    var a = Array<int>();
    var count = g.next_ulong() % (size + 1);
    for (var i in 0..count) {
        a.append((g.next_ulong() % letters) as int);
    }
    var b = Array<int>();
    for (var x in a) {
        var roll = g.next_ulong() % 10;
        if (roll == 0) {
            continue;
        }
        if (roll == 1) {
            b.append((g.next_ulong() % letters) as int);
        }
        b.append(x);
    }
    if (g.next_ulong() % 4 == 0) {
        b.append((g.next_ulong() % letters) as int);
    }
    return (a, b);
}

# The length of the longest common subsequence, by dynamic programming.
lcs(a: int[], b: int[]): ulong {
    var row = Array<ulong>();
    row.resize(b.count + 1, 0);
    for (var i in 0..a.count) {
        var diagonal = 0 as ulong;
        for (var j in 0..b.count) {
            var above = row[j + 1];
            if (a[i] == b[j]) {
                row[j + 1] = diagonal + 1;
            } else if (row[j] > above) {
                row[j + 1] = row[j];
            }
            diagonal = above;
        }
    }
    return row[b.count];
}

# Checks that `edits` is a script from `a` to `b`, in order, alternating
# Equal runs and changes, and returns how many elements it changes.
check_script<T>(a: T[], b: T[], edits: diff.Edit[], location: __ptr<char> = __caller_location()): ulong {
    var i = 0 as ulong;
    var j = 0 as ulong;
    var changed = 0 as ulong;
    var previous = diff.EditKind.Insert;
    for (var edit in edits) {
        expect_true(edit.count > 0, location);
        expect_equal(edit.a_start, i, location);
        expect_equal(edit.b_start, j, location);
        if (edit.kind == diff.EditKind.Equal) {
            expect_true(previous != diff.EditKind.Equal, location);
            for (var k in 0..edit.count) {
                expect_true(a[i + k] == b[j + k], location);
            }
            i += edit.count;
            j += edit.count;
        } else if (edit.kind == diff.EditKind.Delete) {
            expect_true(previous == diff.EditKind.Equal || edits[0] === edit, location);
            i += edit.count;
            changed += edit.count;
        } else {
            expect_true(previous != diff.EditKind.Insert || edits[0] === edit, location);
            j += edit.count;
            changed += edit.count;
        }
        previous = edit.kind;
    }
    expect_equal(i, a.count, location);
    expect_equal(j, b.count, location);
    return changed;
}

[Test]
myers_gives_a_shortest_script() {
    for (var seed in 0..2000) {
        var (a, b) = random_pair(seed as ulong, 40, 2 + (seed % 5) as ulong);
        var changed = check_script(a, b, diff.myers(a, b));
        expect_equal(changed, a.count + b.count - 2 * lcs(a, b));
    }
}

[Test]
patience_gives_a_valid_script() {
    for (var seed in 0..2000) {
        var (a, b) = random_pair(seed as ulong, 40, 2 + (seed % 20) as ulong);
        check_script(a, b, diff.patience(a, b));
    }
}

[Test]
handles_empty_and_equal_sequences() {
    var none = Array<int>();
    expect_equal(diff.myers(none, none).count, 0);
    expect_equal(diff.patience(none, none).count, 0);
    var a = [1, 2, 3];
    var same = diff.myers(a, [1, 2, 3]);
    expect_equal(same.count, 1);
    expect_equal(same[0].to_string(), "Equal 0 0 3");
    expect_equal(diff.myers(a, none)[0].to_string(), "Delete 0 0 3");
    expect_equal(diff.myers(none, a)[0].to_string(), "Insert 0 0 3");
}

[Test]
puts_a_delete_before_its_insert() {
    var edits = diff.myers(["a", "b", "c"], ["a", "x", "c", "d"]);
    var text = Array<String>();
    for (var edit in edits) {
        text.append(edit.to_string());
    }
    expect_equal(", ".join(text), "Equal 0 0 1, Delete 1 1 1, Insert 2 1 1, Equal 2 2 1, Insert 3 3 1");
}

[Test]
patience_anchors_on_unique_elements() {
    # "f", "x", "g" and "y" are unique; the longest run of them in order in
    # both is "g", "y", so the "g" block stays whole and "f" moves.
    var a = ["f", "{", "x", "}", "g", "{", "y", "}"];
    var b = ["g", "{", "y", "}", "f", "{", "x", "}"];
    var edits = diff.patience(a, b);
    check_script(a, b, edits);
    var equal = 0 as ulong;
    for (var edit in edits) {
        if (edit.kind == diff.EditKind.Equal) {
            equal += edit.count;
        }
    }
    expect_equal(equal, 4);
}
