#!/bin/bash

# Detokenize Catalan apostrophe
sed "s/\([lndsLNDS]\) ' \([a-zA-Z]\)/\1'\2/g"
