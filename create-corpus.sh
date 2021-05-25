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
    local SRC=$1
    local TRG=$2
    parallel --no-notice --pipe -k -j$JOBS --block $BLOCK "python3 tools/bifixer/bifixer/bifixer.py -q --aggressive_dedup --ignore_segmentation --scol 1 --tcol 2 - - $SRC $TRG" \
        | LC_ALL=C sort -t $'\t' -S 10G -k3,3 -k4,4nr \
        | LC_ALL=C sort -t $'\t' -S 10G -k3,4 -u \
        | cut -f1,2
}

# Default options
MTDATA_CACHE=./cache
export JOBS=16
export BLOCK=10M

# Get user options
while getopts ":c:l:s:h" options
do
    case "${options}" in
        b) BLOCK=$OPTARG;;
        c) CORPORA=${OPTARG//,/ };;
        C) MTDATA_CACHE=$OPTARG;;
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

if [ -z "$SRC" ] || [ -z "$TRG" ] || [ -z "$SIZE" ] || [ -z "$CORPORA" ];
then
    echo $SRC $TRG $SIZE $CORPORA
    echo "-l -c and -s options are mandatory" >&2; usage; exit 1;
fi

SRC_ISO=$(python -m mtdata.iso $SRC | grep "^$SRC" | cut -f2)
TRG_ISO=$(python -m mtdata.iso $TRG | grep "^$TRG" | cut -f2)

# Clean directory
rm *.{gz,txt}

# Download corpora
mtdata -c $MTDATA_CACHE get -l $SRC_ISO-$TRG_ISO -tr $CORPORA -o .

# Copy from mtdata folder
for corpus in $CORPORA
do
    # Copy and compress files from mtdata directory
    pigz -c train-parts/$corpus-"$SRC_ISO"_$TRG_ISO.$SRC_ISO >$corpus.$SRC.gz
    pigz -c train-parts/$corpus-"$SRC_ISO"_$TRG_ISO.$TRG_ISO >$corpus.$TRG.gz
done

# Clean
./clean-corpus.sh $SRC $TRG $CORPORA

# Mix them
N_CORPUS=$(echo $CORPORA | wc -w)
MAX_SIZE=$((SIZE / N_CORPUS))
echo Max size per corpus $MAX_SIZE lines
for corpus in $CORPORA
do
    pigz -dc $corpus.$SRC$TRG.clean.gz | shuf -n$MAX_SIZE
done | dedup $SRC $TRG | shuf -n$SIZE >corpus.$SRC-$TRG
