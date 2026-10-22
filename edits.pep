## Edit scripts: `myers` and `patience` find the edits that turn one
## sequence into another, as runs of equal, deleted and inserted elements.

## What a run of an edit script does.
export enum EditKind {
    ## The run is in both sequences.
    Equal,
    ## The run is only in the first sequence.
    Delete,
    ## The run is only in the second sequence.
    Insert,
}

## One run of an edit script: `count` elements at `a_start` in the first
## sequence and `b_start` in the second.
export struct Edit {
    ## What the run does.
    var kind: EditKind;
    ## Where the run starts in the first sequence; for an `Insert`, the
    ## index it goes before.
    var a_start: ulong;
    ## Where the run starts in the second sequence; for a `Delete`, the
    ## index of the element that follows it.
    var b_start: ulong;
    ## The number of elements in the run, at least 1.
    var count: ulong;

    ## Makes a run.
    ##
    ## @param kind what the run does
    ## @param a_start where it starts in the first sequence
    ## @param b_start where it starts in the second sequence
    ## @param count how many elements it covers
    construct(kind: EditKind, a_start: ulong, b_start: ulong, count: ulong) {
        this.kind = kind;
        this.a_start = a_start;
        this.b_start = b_start;
        this.count = count;
    }

    ## Returns the run as `kind a_start b_start count`, such as `Delete 4 3 2`.
    ##
    ## @returns the run in a line of text
    to_string(): String {
        var name = "Equal";
        if (kind == EditKind.Delete) {
            name = "Delete";
        } else if (kind == EditKind.Insert) {
            name = "Insert";
        }
        return $"{name} {a_start} {b_start} {count}";
    }
}

## Returns a shortest edit script from `a` to `b`, found with Myers'
## algorithm in O((N + M) * D) time and O(N + M) space, where D is the
## number of elements deleted and inserted.
##
## Elements compare with `==`. Runs alternate between `Equal` and changes,
## and within a change a `Delete` comes before the `Insert`, as `diff`
## prints them. Applying the runs in order to `a` gives `b`.
##
## @typeParam T the element type
## @param a the first sequence
## @param b the second sequence
## @returns the runs, in order; empty when both sequences are empty
## @example
##     var edits = diff.myers(["a", "b", "c"], ["a", "c", "d"]);
##     # Equal 0 0 1, Delete 1 1 1, Equal 2 1 1, Insert 3 2 1
export myers<T>(a: T[], b: T[]): Edit[] {
    var changes = _Changes(a.count, b.count);
    _myers(a, b, 0, a.count, 0, b.count, changes);
    return changes.edits();
}

## Returns an edit script from `a` to `b` found with patience diff: it
## matches the elements that occur exactly once in each sequence, keeps the
## longest run of them that is in the same order in both, and diffs between
## those anchors the same way, falling back to `myers` where no element is
## unique. The result is often easier to read than Myers' when blocks move,
## but need not be the shortest.
##
## Elements compare with `==` and are counted in a `HashMap<T, ...>`, so
## `T` must hash the way it compares (as `String`, the number types and
## `[Equatable]` structs do).
##
## @typeParam T the element type
## @param a the first sequence
## @param b the second sequence
## @returns the runs, in the same form as `myers` gives
export patience<T>(a: T[], b: T[]): Edit[] {
    var changes = _Changes(a.count, b.count);
    _patience(a, b, 0, a.count, 0, b.count, changes);
    return changes.edits();
}

# Which elements of each sequence an edit script deletes or inserts. Both
# algorithms only mark them; `edits` turns the marks into runs.
struct _Changes {
    var deleted: bool[];
    var inserted: bool[];

    construct(a_count: ulong, b_count: ulong) {
        deleted = Array<bool>();
        deleted.resize(a_count, false);
        inserted = Array<bool>();
        inserted.resize(b_count, false);
    }

    mark(a_lo: ulong, a_hi: ulong, b_lo: ulong, b_hi: ulong) {
        for (var i in a_lo..a_hi) {
            deleted[i] = true;
        }
        for (var j in b_lo..b_hi) {
            inserted[j] = true;
        }
    }

    edits(): Edit[] {
        var out = Array<Edit>();
        var n = deleted.count;
        var m = inserted.count;
        var i = 0 as ulong;
        var j = 0 as ulong;
        while (i < n || j < m) {
            var i0 = i;
            var j0 = j;
            while (i < n && j < m && !deleted[i] && !inserted[j]) {
                i += 1;
                j += 1;
            }
            if (i > i0) {
                out.append(Edit(EditKind.Equal, i0, j0, i - i0));
            }
            i0 = i;
            j0 = j;
            while (i < n && deleted[i]) {
                i += 1;
            }
            while (j < m && inserted[j]) {
                j += 1;
            }
            if (i > i0) {
                out.append(Edit(EditKind.Delete, i0, j0, i - i0));
            }
            if (j > j0) {
                out.append(Edit(EditKind.Insert, i, j0, j - j0));
            }
        }
        return out;
    }
}

# Marks the shortest edit script of a[a_lo..a_hi] to b[b_lo..b_hi]: strips
# the common ends, then splits at the middle snake and recurses on each side.
_myers<T>(a: T[], b: T[], a_lo: ulong, a_hi: ulong, b_lo: ulong, b_hi: ulong, changes: _Changes) {
    var lo_a = a_lo;
    var lo_b = b_lo;
    var hi_a = a_hi;
    var hi_b = b_hi;
    while (lo_a < hi_a && lo_b < hi_b && a[lo_a] == b[lo_b]) {
        lo_a += 1;
        lo_b += 1;
    }
    while (lo_a < hi_a && lo_b < hi_b && a[hi_a - 1] == b[hi_b - 1]) {
        hi_a -= 1;
        hi_b -= 1;
    }
    if (lo_a == hi_a || lo_b == hi_b) {
        changes.mark(lo_a, hi_a, lo_b, hi_b);
        return;
    }
    var (x, y) = _middle_snake(a, b, lo_a, hi_a, lo_b, hi_b);
    if (x == lo_a && y == lo_b) {
        changes.mark(lo_a, hi_a, lo_b, hi_b);
        return;
    }
    _myers(a, b, lo_a, x, lo_b, y, changes);
    _myers(a, b, x, hi_a, y, hi_b, changes);
}

# Where a shortest path through a[a_lo..a_hi] and b[b_lo..b_hi] crosses its
# middle (Myers 1986, section 4b), searching from both ends at once; the
# ends must differ. Returns (a_lo, b_lo) if no crossing is found, which a
# correct search never does.
_middle_snake<T>(a: T[], b: T[], a_lo: ulong, a_hi: ulong, b_lo: ulong, b_hi: ulong): (ulong, ulong) {
    var n = (a_hi - a_lo) as long;
    var m = (b_hi - b_lo) as long;
    var max_d = (n + m + 1) / 2;
    var offset = max_d;
    var length = 2 * max_d + 2;
    # forward[offset + k]: the furthest x on diagonal k = x - y from the
    # start; backward[offset + k]: the same from the end, x and y counted back.
    var forward = Array<long>();
    forward.resize(length as ulong, -1);
    var backward = Array<long>();
    backward.resize(length as ulong, -1);
    forward[(offset + 1) as ulong] = 0;
    backward[(offset + 1) as ulong] = 0;
    var delta = n - m;
    # With an odd delta the paths meet on a forward step, else a backward one.
    var odd = delta % 2 != 0;
    # Diagonals that ran off the grid are skipped from then on.
    var k1_start = 0 as long;
    var k1_end = 0 as long;
    var k2_start = 0 as long;
    var k2_end = 0 as long;
    for (var d in 0..max_d) {
        var k1 = -d + k1_start;
        while (k1 <= d - k1_end) {
            var at = (offset + k1) as ulong;
            var x1 = forward[at - 1] + 1;
            if (k1 == -d || (k1 != d && forward[at - 1] < forward[at + 1])) {
                x1 = forward[at + 1];
            }
            var y1 = x1 - k1;
            while (x1 < n && y1 < m && a[a_lo + x1 as ulong] == b[b_lo + y1 as ulong]) {
                x1 += 1;
                y1 += 1;
            }
            forward[at] = x1;
            if (x1 > n) {
                k1_end += 2;
            } else if (y1 > m) {
                k1_start += 2;
            } else if (odd) {
                var other = offset + delta - k1;
                if (other >= 0 && other < length && backward[other as ulong] != -1) {
                    if (x1 >= n - backward[other as ulong]) {
                        return (a_lo + x1 as ulong, b_lo + y1 as ulong);
                    }
                }
            }
            k1 += 2;
        }
        var k2 = -d + k2_start;
        while (k2 <= d - k2_end) {
            var at = (offset + k2) as ulong;
            var x2 = backward[at - 1] + 1;
            if (k2 == -d || (k2 != d && backward[at - 1] < backward[at + 1])) {
                x2 = backward[at + 1];
            }
            var y2 = x2 - k2;
            while (x2 < n && y2 < m && a[a_lo + (n - x2 - 1) as ulong] == b[b_lo + (m - y2 - 1) as ulong]) {
                x2 += 1;
                y2 += 1;
            }
            backward[at] = x2;
            if (x2 > n) {
                k2_end += 2;
            } else if (y2 > m) {
                k2_start += 2;
            } else if (!odd) {
                var other = offset + delta - k2;
                if (other >= 0 && other < length && forward[other as ulong] != -1) {
                    var x1 = forward[other as ulong];
                    var y1 = x1 - (other - offset);
                    if (x1 >= n - x2) {
                        return (a_lo + x1 as ulong, b_lo + y1 as ulong);
                    }
                }
            }
            k2 += 2;
        }
    }
    return (a_lo, b_lo);
}

# How often an element occurs in each side of a patience range, and where.
struct _Seen {
    var a_count: ulong;
    var b_count: ulong;
    var a_index: ulong;
    var b_index: ulong;
}

# Marks a patience edit script of a[a_lo..a_hi] to b[b_lo..b_hi].
_patience<T>(a: T[], b: T[], a_lo: ulong, a_hi: ulong, b_lo: ulong, b_hi: ulong, changes: _Changes) {
    var lo_a = a_lo;
    var lo_b = b_lo;
    var hi_a = a_hi;
    var hi_b = b_hi;
    while (lo_a < hi_a && lo_b < hi_b && a[lo_a] == b[lo_b]) {
        lo_a += 1;
        lo_b += 1;
    }
    while (lo_a < hi_a && lo_b < hi_b && a[hi_a - 1] == b[hi_b - 1]) {
        hi_a -= 1;
        hi_b -= 1;
    }
    if (lo_a == hi_a || lo_b == hi_b) {
        changes.mark(lo_a, hi_a, lo_b, hi_b);
        return;
    }

    var seen = HashMap<T, _Seen>();
    for (var i in lo_a..hi_a) {
        var entry = seen.try_get(a[i]);
        if (entry.is_empty()) {
            var fresh = _Seen();
            fresh.a_count = 1;
            fresh.a_index = i;
            seen.insert(a[i], fresh);
        } else {
            entry.value().a_count += 1;
        }
    }
    for (var j in lo_b..hi_b) {
        var entry = seen.try_get(b[j]);
        if (!entry.is_empty()) {
            entry.value().b_count += 1;
            entry.value().b_index = j;
        }
    }

    # The unique pairs in a's order, then the longest run of them that is in
    # b's order too (patience sorting: each pile's top, and each pair's
    # predecessor in the pile to its left).
    var pair_a = Array<ulong>();
    var pair_b = Array<ulong>();
    for (var i in lo_a..hi_a) {
        var entry = seen.get(a[i]);
        if (entry.a_count == 1 && entry.b_count == 1) {
            pair_a.append(i);
            pair_b.append(entry.b_index);
        }
    }
    if (pair_a.count == 0) {
        _myers(a, b, lo_a, hi_a, lo_b, hi_b, changes);
        return;
    }
    var tops = Array<ulong>();
    var previous = Array<long>();
    previous.resize(pair_a.count, -1);
    for (var p in 0..pair_a.count) {
        var low = 0 as ulong;
        var high = tops.count;
        while (low < high) {
            var middle = (low + high) / 2;
            if (pair_b[tops[middle]] < pair_b[p]) {
                low = middle + 1;
            } else {
                high = middle;
            }
        }
        if (low > 0) {
            previous[p] = tops[low - 1] as long;
        }
        if (low == tops.count) {
            tops.append(p);
        } else {
            tops[low] = p;
        }
    }
    var chain = Array<ulong>();
    var link = tops.last() as long;
    while (link >= 0) {
        chain.append(link as ulong);
        link = previous[link as ulong];
    }
    chain.reverse();

    var next_a = lo_a;
    var next_b = lo_b;
    for (var p in chain) {
        _patience(a, b, next_a, pair_a[p], next_b, pair_b[p], changes);
        next_a = pair_a[p] + 1;
        next_b = pair_b[p] + 1;
    }
    _patience(a, b, next_a, hi_a, next_b, hi_b, changes);
}
