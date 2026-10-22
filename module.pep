## Diffs: the edits that turn one sequence into another, unified diffs of
## text, and applying them.
##
## Bring it in with `import diff`.
##
## - `myers`, `patience`: an edit script between two arrays, as `Edit` runs
## - `split_lines`: text cut into lines that keep their endings
## - `unified`: the unified diff of two texts, as `diff -u` and `git diff` write it
## - `apply`: a unified diff applied to the text it was made from
##
## @example
##     import diff;
##
##     main(): int {
##         var old_text = "one\ntwo\nthree\n";
##         var new_text = "one\n2\nthree\n";
##         var patch = diff.unified(old_text, new_text, from_name = "a/n.txt", to_name = "b/n.txt");
##         print(patch);
##         # --- a/n.txt
##         # +++ b/n.txt
##         # @@ -1,3 +1,3 @@
##         #  one
##         # -two
##         # +2
##         #  three
##         assert(diff.apply(old_text, patch).value() == new_text, "a round trip");
##         return 0;
##     }

# This file only gathers the module's public API from its other files.

import "edits";
import "patch";
import "unified";

export EditKind;
export Edit;
export myers;
export patience;
export Algorithm;
export split_lines;
export unified;
export apply;
