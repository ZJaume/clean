#!/bin/bash
set -e

# Detokenize neulabs
# Most of these quote, space, quote, can be replaced by a single quote
fixes/detok.sh $1 $2 \
    | sed -E 's/" +"( " *")*/"/g' \
    | sed -E 's/" +"( " *")*/"/g'
