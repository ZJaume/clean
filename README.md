# clean

This is a set of scripts for downloading parallel corpora, fixing and cleaning them.
It uses [MTData](https://github.com/thammegowda/mtdata) to download and then some rule-based filtering.
It started using the cleaning scripts from [Bergamot students](https://github.com/browsermt/students) repository but I added a few more things.

## Installation
Clone the repository and install python modules:
```
git clone --recursive https://github.com/ZJaume/clean
cd clean
pip install -r requirements.txt
pip install -r tools/bifixer/requirements.txt
```

## Usage
```
Usage: create-corpus.sh [options]
Options:
      -B BLOCK        Block size of parallel
      -c CORPORA      Comma-separated list of corpora
                      from 'mtdata list -l SRC-TRG'
      -C CACHE        mtdata cache directory
                      Default: ./cache
      -j JOBS         Number of jobs of parallel
      -l SRC-TRG      Language pair
      -s SIZE         Number of sentences
```

First of all look at the available corpora with `mtdata`:
```
$ mtdata list -l en-mt
```
INFO:root:Loaded entries: Statmt.org:355  Paracrawl:59  Tilde:519  JoshuaIndianCoprus:29  GlobalVoices:812  UnitedNations:30  OPUS:53,321  OPUS_JW300:44,663  OPUS100:302  WikiMatrix:1,617  Other:7  Neulab_TEDTalksv1:4,455  Total:106,169
WARNING:root:Suggestion: Use ISO 639_3 codes eng-mlt instead of en-mt. Let's make a little space for all 7000+ languages of our planet 😢.
INFO:root:Found 24
paracrawl_v6    eng-mlt https://s3.amazonaws.com/web-language-models/paracrawl/release6/en-mt.txt.gz
paracrawl_v7_1  eng-mlt https://s3.amazonaws.com/web-language-models/paracrawl/release7.1/en-mt.txt.gz
EESC2017        eng-mlt https://tilde-model.s3-eu-west-1.amazonaws.com/EESC2017.en-mt.tmx.zip  *.tmx
EMA2016 eng-mlt https://tilde-model.s3-eu-west-1.amazonaws.com/EMA2016.en-mt.tmx.zip    *.tmx
ecb2017 eng-mlt https://tilde-model.s3-eu-west-1.amazonaws.com/ecb2017.en-mt.tmx.zip    *.tmx
rapid2016       eng-mlt https://tilde-model.s3-eu-west-1.amazonaws.com/rapid2016.en-mt.tmx.zip  *.tmx
OPUS_EUconst_v1 eng-mlt http://opus.nlpl.eu/download.php?f=EUconst/v1/moses/en-mt.txt.zip       *.en,*.mt
OPUS_EUbookshop_v2      eng-mlt http://opus.nlpl.eu/download.php?f=EUbookshop/v2/moses/en-mt.txt.zip    *.en,*.mt
OPUS_EMEA_v3    eng-mlt http://opus.nlpl.eu/download.php?f=EMEA/v3/moses/en-mt.txt.zip  *.en,*.mt
OPUS_ECB_v1     eng-mlt http://opus.nlpl.eu/download.php?f=ECB/v1/moses/en-mt.txt.zip   *.en,*.mt
OPUS_DGT_v2019  eng-mlt http://opus.nlpl.eu/download.php?f=DGT/v2019/moses/en-mt.txt.zip        *.en,*.mt
OPUS_wikimedia_v20190628        eng-mlt http://opus.nlpl.eu/download.php?f=wikimedia/v20190628/moses/en-mt.txt.zip      *.en,*.mt
OPUS_Ubuntu_v14_10      eng-mlt http://opus.nlpl.eu/download.php?f=Ubuntu/v14.10/moses/en-mt.txt.zip    *.en,*.mt
OPUS_TildeMODEL_v2018   eng-mlt http://opus.nlpl.eu/download.php?f=TildeMODEL/v2018/moses/en-mt.txt.zip *.en,*.mt
OPUS_Tatoeba_v20190709  eng-mlt http://opus.nlpl.eu/download.php?f=Tatoeba/v20190709/moses/en-mt.txt.zip        *.en,*.mt
OPUS_QED_v2_0a  eng-mlt http://opus.nlpl.eu/download.php?f=QED/v2.0a/moses/en-mt.txt.zip        *.en,*.mt
OPUS_ParaCrawl_v5       eng-mlt http://opus.nlpl.eu/download.php?f=ParaCrawl/v5/moses/en-mt.txt.zip     *.en,*.mt
OPUS_KDE4_v2    eng-mlt http://opus.nlpl.eu/download.php?f=KDE4/v2/moses/en-mt.txt.zip  *.en,*.mt
OPUS_JRC_Acquis eng-mlt http://opus.nlpl.eu/download.php?f=JRC-Acquis/en-mt.txt.zip     *.en,*.mt
OPUS_GNOME_v1   eng-mlt http://opus.nlpl.eu/download.php?f=GNOME/v1/moses/en-mt.txt.zip *.en,*.mt
JW300   eng-mlt http://opus.nlpl.eu/download.php?f=JW300/v1/xml/en-mt.xml.gz    http://opus.nlpl.eu/download.php?f=JW300/v1/xml/en.zip,http://opus.nlpl.eu/download.php?f=JW300/v1/xml/mt.zip
```

Then, run the main script specifying the desired corpora passing their `mtdata` id's separated by commas:
```
./create-corpus.sh -l en-mt -c OPUS_TildeMODEL_v2018,JW300,OPUS_Tatoeba_v20190709,OPUS_ECB_v1
```

The script will download the corpora with `mtdata`, apply some fixes, clean, concatenation and near-deduplication.

## Customization
Specific corpus fixes can be applied adding custom executable scripts at `fixes/` directoryi that will be called inside the pipeline.
These scripts must follow the naming `fixes/corpus_id.sh` for processing parallel tab-separated input or `fixes/corpus_id.lang.sh` for processing monolingual data.
For example, the `fixes/JW300.mt.sh` reads monolingual data and fixes some tokenization issues present in the JW300 corpus of Maltese:
```
#!/bin/bash

# Fix Maltese tokenization in JW300 that detokenizer cannot fix
sed "s/ - $(echo -ne \u200b) /-/g" \
    | sed 's/ - /-/g'
```

Or the `fixes/JW300.sh` that reads the tab-separated input, detokenizes it and then it prints to stdout in the same tab-separated format and fixed:
```
#!/bin/bash
set -e

# Detokenize JW300

SRC=$1
TRG=$2

temp=$(mktemp -d)

tee >(cut -f1 | sacremoses -j 6 -l $SRC detokenize >$temp/$SRC.detok) \
    >(cut -f2 | sacremoses -j 6 -l $TRG detokenize >$temp/$TRG.detok)

paste $temp/$SRC.detok $temp/$TRG.detok

rm -r $temp
```

Note that the scripts that process parallel data will be called with the language identifiers as arguments.
