#!/usr/bin/env zsh
# Run every tests/test_*.zsh and aggregate. Exits non-zero if any file fails.
#
#   zsh tests/run.zsh            # run all
#   zsh tests/run.zsh hooks      # run only files matching *hooks*
here="${0:A:h}"
filter="${1:-}"
fail=0
ran=0

for t in "$here"/test_*.zsh; do
  [[ -f "$t" ]] || continue
  [[ "${t:t}" == *"$filter"* ]] || continue
  (( ran++ ))
  print "\n# ==== ${t:t} ===="
  zsh "$t" || fail=1
done

print
if (( ran == 0 )); then
  print "# no test files matched '$filter'"
  exit 1
fi
(( fail )) && print "# SOME TESTS FAILED" || print "# ALL TESTS PASSED"
exit $fail
