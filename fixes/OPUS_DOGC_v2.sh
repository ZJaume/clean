#!/bin/bash
set -e

# Detokenize DOGC

SRC=$1
TRG=$2

temp=$(mktemp -d)

tee >(cut -f1 | sacremoses -j 6 -l $SRC detokenize >$temp/$SRC.detok) \
    >(cut -f2 | sacremoses -j 6 -l $TRG detokenize >$temp/$TRG.detok)

# join sides and detokenize dates an laws
paste $temp/$SRC.detok $temp/$TRG.detok

rm -r $temp
