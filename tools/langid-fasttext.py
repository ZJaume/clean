#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Usage:
#   ./langid-fasttext.py < sents.txt > code-tab-sents.txt
#
# Installation:
#   pip3 install pybind11 fasttext --user
#
# Parallelize:
#   cat sents.txt | parallel --pipe -k -j16 --block 20M ./langid-fasttext.py > code-tab-sents.txt

import argparse
import fasttext
import os
import sys
from mtdata.iso.iso639_1 import ISO693_1_to_3
ISO639_3to1 = {}
for key, val in ISO693_1_to_3.items():
    ISO639_3to1[val] = key

BIN = "lid201-model.bin"
URL = "https://data.statmt.org/lid/{}".format(BIN)

fasttext.FastText.eprint = lambda x: None

def main():
    args = parse_user_args()

    mpath = os.path.join(os.path.dirname(os.path.realpath(__file__)), BIN)
    if not os.path.exists(mpath):
        sys.stderr.write("Downloading model {} ...\n".format(URL))
        import gzip, shutil, urllib.request
        with urllib.request.urlopen(URL + '.gz') as response:
            with open(mpath, 'wb') as out_file, \
                    gzip.GzipFile(fileobj=response) as decompressor:
                shutil.copyfileobj(decompressor, out_file)


    model = fasttext.load_model(mpath)

    for line in sys.stdin:
        fields = line.strip().split("\t")
        lid = model.predict(fields[args.field].lower())[0][0][9:12]
        print(lid)
        if lid in ISO639_3to1:
            lid = ISO639_3to1[lid]
        else:
            lid = 'unk'
        sys.stdout.write("{}\t{}".format(lid, line))


def parse_user_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("-f", "--field", default=0, type=int, help="text field, default: 0")
    return parser.parse_args()


if __name__ == "__main__":
    main()
