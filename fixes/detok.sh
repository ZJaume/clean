#!/bin/bash
set -eu

source venv/bin/activate
# Detokenize

SRC=$1
TRG=$2

temp=$(mktemp -d)

tee >(cut -f1 | parallel -j6 --pipe -k --block 5M sacremoses -l $SRC detokenize >$temp/$SRC.detok) \
    | cut -f2 | parallel -j6 --pipe -k --block 5M sacremoses -l $TRG detokenize >$temp/$TRG.detok

paste $temp/$SRC.detok $temp/$TRG.detok

rm -r $temp
