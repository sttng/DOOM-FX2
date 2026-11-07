#!/bin/bash
# det_suite.sh ROM NAME : dettest.py runs (600 rendered frames, scripted input) on the levels in
#   $LEVELS (default "0 2 12 18 23"; e.g. LEVELS="0 1 7" for the ones a change touches), two at
#   a time -> $TESTOUT/suite_NAME_<level> (TESTOUT default ${TMPDIR:-/tmp}/doomtest); prints
#   each level's result ("600 rendered frames ...", or the error)
# det_suite.sh --compare NAME_A NAME_B : compare two suites level by level
HERE=$(cd "$(dirname "$0")" && pwd)
MESENRUN=${MESENRUN:-mesenrun}
S=${TESTOUT:-${TMPDIR:-/tmp}/doomtest}; mkdir -p "$S"
LEVELS=${LEVELS:-"0 2 12 18 23"}
if [ "$1" == "--compare" ]; then
  rc=0
  for l in $LEVELS; do echo -n "level $l: "; python3 $HERE/dettest.py --compare $S/suite_$2_$l $S/suite_$3_$l || rc=1; done
  exit $rc
fi
ROM=$1; N=$2; SYM=${ROM%.sfc}.sym
IN="900:a@5;1100:a@5;1300:a@5;r5:up@40;r50:b@5;r60:right@8;r70:up@60;r135:b@10;r150:a@3;r160:left@16;r180:up@80;r265:b@10;r280:a@3;r290:right@8;r300:up@100;r405:b@20;r430:left@8;r440:up@80;r525:a@3;r530:b@20;r555:up@45"
run() { python3 $HERE/dettest.py $ROM --sym $SYM --out $S/suite_${N}_$1 --frames 600 --level $1 --input "$IN" --mesenrun $MESENRUN > $S/suite_${N}_$1.log 2>&1; }
set -- $LEVELS
while [ $# -gt 0 ]; do
  run $1 & [ $# -gt 1 ] && run $2 & wait; shift; [ $# -gt 0 ] && shift
done
for l in $LEVELS; do echo "$N level $l: $(tail -n1 $S/suite_${N}_$l.log | sed 's/.*: //')"; done
