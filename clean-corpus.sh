#!/bin/bash
##
# Basic cleaning of parallel corpora.
#
# Usage:
#   bash clean-corpus.sh prefix [prefix...]
#

set -e

TOOLS=./tools
SRC=$1
TRG=$2
JOBS=$3
BLOCK=$4

for data in ${@:5}; do
    # Check if files exist
    test -s $data.$SRC.zst || exit 1
    test -s $data.$TRG.zst || exit 1

    ######################################################################
    # Basic preprocessing
    for lng in $SRC $TRG; do

        zstdcat $data.$lng.zst \
            | $TOOLS/remove-non-printing-char.perl \
            | zstdmt > $data.$lng.nrm.zst
    done

    test -s $data.$SRC.nrm.zst || exit 1
    test -s $data.$TRG.nrm.zst || exit 1

    #####################################################################
    # Apply monolingual fixes
    for lng in $SRC $TRG; do
        if [[ ! -x fixes/$data.$lng.sh ]]; then
            ln -sf $data.$lng.nrm.zst $data.$lng.monofix.zst
        else
            zstdcat $data.$lng.nrm.zst \
                | fixes/$data.$lng.sh \
                | zstdmt >$data.$lng.monofix.zst
        fi
    done

    ######################################################################
    # Apply bilingual fixes and bifixer, not dedup
    if [[ -x fixes/$data.sh ]]; then
        FIX="fixes/$data.sh $SRC $TRG"
        echo Applying bilingual fix "$FIX" >&2
    else
        FIX=cat
    fi
    paste <(zstdcat $data.$SRC.monofix.zst) <(zstdcat $data.$TRG.monofix.zst) \
        | $FIX \
        | parallel --no-notice --pipe -k -j$JOBS --block $BLOCK "bifixer -q --ignore_duplicates --scol 1 --tcol 2 - - $SRC $TRG" \
        | zstdmt > $data.$SRC$TRG.fix.zst

    test -s $data.$SRC$TRG.fix.zst || exit 1

    ######################################################################
    # Language identification
    export OPENBLAS_NUM_THREADS=1
    zstdcat $data.$SRC$TRG.fix.zst \
        | parallel --no-notice --pipe -k -j$JOBS --block $BLOCK "python3 $TOOLS/langid-fasttext.py -f 1 | python3 $TOOLS/langid-fasttext.py -f 1" \
        | tee >(grep -Pv "^$SRC\t$TRG\t" > $data.$SRC$TRG.langid.debug.txt) \
        | grep -P "^$SRC\t$TRG\t" \
        | cut -f3,4 \
        | zstdmt > $data.$SRC$TRG.langid.zst

    test -s $data.$SRC$TRG.langid.zst

    ######################################################################
    # Rule-based filtering
    zstdcat $data.$SRC$TRG.langid.zst \
        | parallel --no-notice --pipe -k -j$JOBS --block $BLOCK "python3 $TOOLS/clean-parallel.py -l1 $SRC -l2 $TRG --debug" \
        2> $data.$SRC$TRG.clean.debug.txt \
        | zstdmt > $data.$SRC$TRG.clean.zst

    # No need to separate
    #zstdcat $data.$SRC$TRG.clean.zst | cut -f1 | zstdmt > $data.$SRC.clean.zst
    #zstdcat $data.$SRC$TRG.clean.zst | cut -f2 | zstdmt > $data.$TRG.clean.zst
    #test -s $data.$SRC.clean.zst || exit 1
    #test -s $data.$TRG.clean.zst || exit 1

    test -s $data.$SRC$TRG.clean.zst || exit 1

    # Remove $data from intermediate steps
    #rm -f *.nrm.zst *.fix.zst *.langid.zst *.monofix.zst
    wc -l *.debug.txt
done

