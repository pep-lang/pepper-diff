# pepper-diff

Diffs for [Pepper](https://github.com/pep-lang/pepper): the edits that turn
one array into another (Myers' shortest diff, or patience diff), unified
diffs of text as `diff -u` and `git diff` write them, and applying such a
diff to the text it was made from. For `--check` output, test snapshot
diffs and other tooling. Pure Pepper, no dependencies beyond the runtime.

One module, **`diff`**:

- **`myers(a, b)`** returns a shortest edit script from array `a` to `b`
  as `Edit` runs (`Equal`, `Delete`, `Insert`, each with its start in both
  arrays and a count), in O((N + M) · D) time and O(N + M) space.
- **`patience(a, b)`** returns patience diff's script: it anchors on
  elements that occur once in each array and falls back to Myers between
  anchors where none is unique.
- **`split_lines(text)`** cuts text into lines that keep their `"\n"`.
- **`unified(a, b, context = 3, from_name = "a", to_name = "b", algorithm =
  Algorithm.Myers)`** returns the unified diff of two texts: `---`/`+++`
  lines, `@@ -start,count +start,count @@` hunks with `context` lines
  around each change (changes at most `2 * context` apart share a hunk), and
  `\ No newline at end of file` after a last line that has none. Equal texts
  give `""`.
- **`apply(text, patch)`** applies a unified diff and returns the new text,
  or an `Error` naming the patch line and text line where they disagree.

```pepper
import diff;

main(): int {
    var old_text = "one\ntwo\nthree\n";
    var new_text = "one\n2\nthree\n";
    var patch = diff.unified(old_text, new_text, from_name = "a/n.txt", to_name = "b/n.txt");
    print(patch);
    # --- a/n.txt
    # +++ b/n.txt
    # @@ -1,3 +1,3 @@
    #  one
    # -two
    # +2
    #  three
    print(diff.apply(old_text, patch).value() == new_text);   # true

    for (var edit in diff.myers([1, 2, 3], [1, 3, 4])) {
        print(edit.to_string());   # Equal 0 0 1, Delete 1 1 1, Equal 2 1 1, Insert 3 2 1
    }
    return 0;
}
```

Elements compare with `==`, so `myers` works on any array. `patience`
also counts elements in a `HashMap`, so its elements must hash the way they
compare, as `String`, the number types and `[Equatable]` structs do.

## Matching `git diff`

`unified` writes the same format as `git diff` and `diff -u`, and on the
fixtures in `tests/fixtures/` (made with `git diff --no-index`, less its
`diff --git` and `index` lines) the same bytes. Where several shortest
diffs exist, Myers here may pick another one than git's xdiff, whose
heuristics can also give up minimality: on `tests/fixtures/patience.*`
plain `git diff` changes 21 lines, `diff.myers` 20 (the same as
`git diff --patience`).

## Strict patches

`apply` places each hunk exactly where its header says and checks every
unchanged and removed line, line endings included. It never shifts a hunk
to another line or applies it fuzzily: a hunk that does not match is an
error, as is a malformed header, a hunk with more or fewer lines than its
header counts, or hunks out of order.

## Limits

- `apply` takes the diff of one file: it skips every line before the
  first `@@` and reads all hunks as one file's.
- No word or character diffs, no `git diff`-style indent heuristic, and no
  rename, mode or binary sections.
- Lines are compared whole, so `"\r\n"` and `"\n"` endings differ.

## Using it

This repository is a package: `pep.toml` marks its root, and its root
`module.pep` is the `diff` module. Add it to a project under the name
`diff`:

```sh
pepper package add pep-lang/pepper-diff --name diff
```

which writes

```toml
[dependencies]
diff = { github = "pep-lang/pepper-diff" }
```

Without a project, put a folder named `diff` that holds (or links to)
this repository on the import path: `pepper build -I packages main.pep`.

## Tests

```sh
tests/run.sh path/to/pepper
```

runs the `[Test]` functions in `tests/` with `pepper test`: Myers' scripts
checked against a dynamic-programming LCS for minimality, patience scripts
checked for validity, `apply(a, unified(a, b)) == b` over generated texts
with both algorithms and several context sizes, the `git diff` fixtures,
every `apply` error, and two 10,000-line texts. A package only the tests
use goes in `[dev-dependencies]` (`pepper package add --dev OWNER/name`):
projects that depend on this one do not fetch it.

## Performance

Two texts of 10,000 lines that differ in about 300 places (413 lines
deleted or inserted): `unified` takes 4.6 ms with Myers and 4.5 ms with
patience, and `apply` 1.5 ms (best of 9, `-O`, Windows 11, Pepper 0.10.1).

## Releasing

CI (`.github/workflows/ci.yml`) runs the tests on Linux, macOS and
Windows for every push to `main` and every pull request, and, when
`pep.toml` sets `minimum_toolchain`, on Linux with that toolchain too, so
the minimum it states stays true. It builds with `PEPPER_LOCKED=1`, the
same as `pepper test --locked`: a `pep.lock` out of date with `pep.toml`
fails the run, so commit `pep.lock` after changing a dependency. To
release, set `version` in `pep.toml`, merge, then push the matching tag
(`git tag v1.0.0 && git push origin v1.0.0`): CI tests the tag and
publishes a GitHub release for it. `pepper package add` and `pepper
package update` find versions by their tags.

## License

Apache-2.0; see [LICENSE](LICENSE).
