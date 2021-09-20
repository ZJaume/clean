#!/bin/bash

# Fix Maltese tokenization in JW300 that detokenizer cannot fix
sed "s/ - $(echo -ne \u200b) /-/g" \
    | sed 's/ - /-/g' \
    | sed -E 's/(\w)- (\w)/\1-\2/g'
