#!/bin/bash

get_seeded_random() {
    local seed=$1
    openssl enc -aes-256-ctr -pass pass:"$seed" -nosalt \
        </dev/zero 2>/dev/null
}

usage() {
    echo "Usage: `basename $0` [options]"
    echo "Options:"
    echo "      -B BLOCK        Block size of parallel"
    echo "      -c CORPORA      Comma-separated list of corpora"
    echo "                      from 'mtdata list -l SRC-TRG'"
    echo "      -C CACHE        mtdata cache directory"
    echo "                      Default: $MTDATA_CACHE"
    echo "      -j JOBS         Number of jobs of parallel"
    echo "      -l SRC-TRG      Language pair"
    echo "      -s SIZE         Number of sentences"
}

dedup() {
    parallel --pipe -j6 --block 30M ./tools/hash-seg.py -a \
        | ./tools/superdedup.py \
        | cut -f1,2
}

# Default options
DEDUP=TRUE
MTDATA_CACHE=./cache
export JOBS=16
export BLOCK=10M

# Get user options
while getopts ":b:c:C:dj:l:s:h" options
do
    case "${options}" in
        b) BLOCK=$OPTARG;;
        c) CORPORA=${OPTARG//,/ };;
        C) MTDATA_CACHE=$OPTARG;;
        d) DEDUP=FALSE;;
        j) JOBS=$OPTARG;;
        l) IFS='-' read SRC TRG <<< $OPTARG;;
        s) SIZE=$OPTARG;;
        h) usage; exit 0;;
        \?) echo "Unknown option: -$OPTARG" >&2
            usage >&2; exit 1;;
        :) echo "Missing option argument for -$OPTARG" >&2
            usage >&2; exit 1;;
        *) echo "Unimplemented option: -$OPTARG" >&2
            usage >&2; exit 1;;
    esac
done
export MTDATA=$MTDATA_CACHE

if [ -z "$SRC" ] || [ -z "$TRG" ] || [ -z "$CORPORA" ];
then
    echo $SRC $TRG $CORPORA
    echo "-l and -c options are mandatory" >&2; usage; exit 1;
fi


SRC_ISO=$(python -m mtdata.iso $SRC | grep "^$SRC" | cut -f2)
TRG_ISO=$(python -m mtdata.iso $TRG | grep "^$TRG" | cut -f2)

# Clean directory
rm *.{zst,debug.txt}

# Download corpora
mtdata get -j $JOBS -l $SRC_ISO-$TRG_ISO -tr $CORPORA -o .

# Copy from mtdata folder
for corpus in $CORPORA
do
    # Copy and compress files from mtdata directory
    zstdmt -c train-parts/$corpus.$SRC_ISO >$corpus.$SRC.zst
    zstdmt -c train-parts/$corpus.$TRG_ISO >$corpus.$TRG.zst
done

# Clean
./clean-corpus.sh $SRC $TRG $JOBS $BLOCK $CORPORA

if [ -z "$SIZE" ]; then
    # Mix and near-dedup
    if [ "$DEDUP" == "FALSE" ]; then
        cat *.$SRC$TRG.clean.zst >corpus.$SRC-$TRG.zst
    else
        zstdcat *.$SRC$TRG.clean.zst | dedup \
            | zstdmt >corpus.$SRC-$TRG.zst
    fi
else
    # Mix, sample and near-dedup
    N_CORPUS=$(echo $CORPORA | wc -w)
    MAX_SIZE=$((SIZE / N_CORPUS))
    echo Max size per corpus: $MAX_SIZE lines
    for corpus in $CORPORA
    do
        zstdcat $corpus.$SRC$TRG.clean.zst | shuf -n$MAX_SIZE
    done | dedup $SRC $TRG | shuf -n$SIZE >corpus.$SRC-$TRG
fi
