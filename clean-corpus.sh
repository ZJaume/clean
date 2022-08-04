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
JOBS=24
BLOCK=10M

for data in ${@:3}; do
    # Check if files exist
    test -s $data.$SRC.gz || exit 1
    test -s $data.$TRG.gz || exit 1

    ######################################################################
    # Basic preprocessing
    for lng in $SRC $TRG; do

        pigz -dc $data.$lng.gz \
            | parallel --no-notice --pipe -k -j$JOBS --block $BLOCK "perl $TOOLS/remove-non-printing-char.perl" \
            | pigz > $data.$lng.nrm.gz
    done

    test -s $data.$SRC.nrm.gz || exit 1
    test -s $data.$TRG.nrm.gz || exit 1

    #####################################################################
    # Apply monolingual fixes
    for lng in $SRC $TRG; do
        if [[ ! -x fixes/$data.$lng.sh ]]; then
            cp $data.$lng.nrm.gz $data.$lng.monofix.gz
        else
            pigz -dc $data.$lng.nrm.gz \
                | fixes/$data.$lng.sh \
                | pigz >$data.$lng.monofix.gz
        fi
    done

    ######################################################################
    # Apply bilingual fixes and bifixer, not dedup
    if [[ -x fixes/$data.sh ]]; then
        FIX="fixes/$data.sh $SRC $TRG"
    else
        FIX=cat
    fi
    paste <(pigz -dc $data.$SRC.monofix.gz) <(pigz -dc $data.$TRG.monofix.gz) \
        | $FIX \
        | parallel --no-notice --pipe -k -j$JOBS --block $BLOCK "bifixer -q --ignore_duplicates --scol 1 --tcol 2 - - $SRC $TRG" \
        | pigz > $data.$SRC$TRG.fix.gz

    test -s $data.$SRC$TRG.fix.gz || exit 1

    ######################################################################
    # Language identification
    export OPENBLAS_NUM_THREADS=1
    pigz -dc $data.$SRC$TRG.fix.gz \
        | parallel --no-notice --pipe -k -j$JOBS --block $BLOCK "python3 $TOOLS/langid-fasttext.py -f 1 | python3 $TOOLS/langid-fasttext.py -f 1" \
        | tee >(grep -Pv "^$SRC\t$TRG\t" > $data.$SRC$TRG.langid.debug.txt) \
        | grep -P "^$SRC\t$TRG\t" \
        | cut -f3,4 \
        | pigz > $data.$SRC$TRG.langid.gz

    test -s $data.$SRC$TRG.langid.gz

    ######################################################################
    # Rule-based filtering
    pigz -dc $data.$SRC$TRG.langid.gz \
        | parallel --no-notice --pipe -k -j$JOBS --block $BLOCK "python3 $TOOLS/clean-parallel.py -l1 $SRC -l2 $TRG --debug" \
        2> $data.$SRC$TRG.clean.debug.txt \
        | pigz > $data.$SRC$TRG.clean.gz

    # No need to separate
    #pigz -dc $data.$SRC$TRG.clean.gz | cut -f1 | pigz > $data.$SRC.clean.gz
    #pigz -dc $data.$SRC$TRG.clean.gz | cut -f2 | pigz > $data.$TRG.clean.gz
    #test -s $data.$SRC.clean.gz || exit 1
    #test -s $data.$TRG.clean.gz || exit 1

    test -s $data.$SRC$TRG.clean.gz || exit 1

    # Remove $data from intermediate steps
    #rm -f *.nrm.gz *.fix.gz *.langid.gz *.monofix.gz
    wc -l *.debug.txt
done

