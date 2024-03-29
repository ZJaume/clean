#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import re
import regex
import argparse


# The variables below need to be adjusted for a language pair and dataset.
# To add a new language, define the list of alpha characters in the dict below.

MIN_LENGTH = 1      # minimum number of words in a sentence
MAX_LENGTH = 200    # maximum number of words in a sentence
RATIO_LENGTH = 0.3  # maximum length difference between the source and target sentence

RATIO_ALPHA_WORDS = 0.4  # minimum fraction of "real" words in a source sentence
RATIO_ALPHA_CHARS = 0.5  # minimum fraction of alpha characters in a source sentence

CHARS = {
    'bg': r'[АаБбВвГгДддЕеЖжЗзИиЙйКкkasЛлМмНнОоПпРрСсТтУуФфХхЦцЧчШшЩщЪъЬьЮюЯя]',
    'bs': r'[abcčČćĆdđĐefghijklmnoprsšŠtuvzžŽАаБбВвГгДддЂђЕеЖжЗзИиЙйКкkЛлЉљМмНнЊњОоПпРрЋћТтУуФфХхЦцЧчШшЩщ]',
    'cs': r'[a-zÁáČčĎďÉéěÍíŇňÓóŘřŠšŤťÚúůÝýŽž]',
    'ca': r'[a-zÀàÈèÉéÍíÒòÓóÚúÇç]',
    'da': r'[a-zÆæØøÅå]',
    'de': r'[a-zÄäÖöÜüß]',
    'en': r'[a-z]',
    'el': r'[a-zΑαΒβΓγΔδΕεΖζΗηΘθΙιΚκΛλΜμΝνΞξΟοΠπΡρΣσςΤτΥυΦφΧχΨψΩω]',
    'es': r'[a-zÁáÉéÍíÓóÚúñÑ]',
    'et': r'[a-zÕõÄäÖöÜü]',
    'eu': r'[a-zñÑ]',
    'fi': r'[a-zÅåÄäÖö]',
    'fr': r'[a-zÂâÁáÀàâÇçÉéÈèÊêÓóÒòÔôŒœÜüÛûŸÿ]',
    'ga': r'[abcdefghilmnoprstuáéíóúÁÉÍÓÚ]',
    'gl': r'[a-zÁáÉéÍíÓóÚúÑñ]',
    'hr': r'[abcčČćĆdđĐefghijklmnoprsšŠtuvzžŽ]',
    'hu': r'[a-zÁáÉéÍíÓóÖöŐőŰű]',
    'is': r'[abdefghijklmnoprstuvxyÁáðÐÉéÍíÓóÚúÝýÞþÆæÖö]',
    'it': r'[a-zàÀèÈéÉìÌíÍîÎòÒóÓùÙúÚ]',
    'lt': r'[aąbcČčdeĘęĖėfghiĮįyjklmnoprsŠštuŲųŪūvzŽž]',
    'lv': r'[aĀābcČčdeĒēfgĢģhiĪījkĶķlĻļmnŅņoprsŠštuŪūvzŽž]',
    'mt': r'[abĊċdefĠġghĦħiiejklmnopqrstuvwxŻżz]',
    'me': r'[abcčČćĆdđĐefghijklmnoprsšŠtuvzžŽАаБбВвГгДддЂђЕеЖжЗзИиЙйКкkЛлЉљМмНнЊњОоПпРрЋћТтУуФфХхЦцЧчШшЩщ]',
    'nb': r'[a-zÂâÁáÀàâÉéÈèÊêÓóÒòÔôÜüÆæØøÅå]',
    'nl': r'[a-zÂâÁáÀàâÉéÈèÊêÓóÒòÔôÚú]',
    'no': r'[a-zÂâÁáÀàâÉéÈèÊêÓóÒòÔôÜüÆæØøÅå]',
    'nn': r'[a-zÂâÁáÀàâÉéÈèÊêÓóÒòÔôÜüÆæØøÅå]',
    'pl': r'[a-zĄąĆćĘęŁłŃńÓóŚśŹźŻż]',
    'pt': r'[a-zÁáÉéÍíÓóÚúÂâÊêÔôÀàÈèÌìÒòÙùÇçÃãÕõ]',
    'ro': r'[a-zĂăÂâÎîȘșȚț]',
    'sk': r'[a-záäÁÄčČďĎžéÉíÍĺĹľĽňŇóÓôÔŕŔšŠťŤúÚýÝžŽ]',
    'sl': r'[abcčČdđĐefghijklmnoprsšŠtuvzžŽ]',
    'sr': r'[abcčČćĆdđĐefghijklmnoprsšŠtuvzžŽАаБбВвГгДддЂђЕеЖжЗзИиЙйКкkЛлЉљМмНнЊњОоПпРрЋћТтУуФфХхЦцЧчШшЩщ]',
    'sv': r'[a-zÅåÄäÖö]',
    'uk': r'[АаБбВвГгДддЕеЖжЗзИиЙйКкkasЛлМмНнОоПпРрСсТтУуФфХхЦцЧчШшЩщЪъЬьЮюЯя]',
}

middle_period = regex.compile(r'\w+[\.\?\!] \p{Lu}\w*,? ')

def main():
    args = parse_user_args()

    for i, line in enumerate(sys.stdin):
        fields = line.strip().split('\t')
        if len(fields) < 2:
            continue

        src = fields[-2].strip()
        trg = fields[-1].strip()

        skip = clean_parallel(src, trg, args.src_lang, args.trg_lang)
        if skip:
            if args.debug:
                sys.stderr.write("{}\t{}".format(skip, line))
            continue
        sys.stdout.write(line)


def clean_parallel(src, trg, src_lang, trg_lang):
    if src.lower() == trg.lower():
        return "IDENTICAL"

    src_toks = src.split()
    trg_toks = trg.split()
    src_len = len(src_toks)
    trg_len = len(trg_toks)

    if not src_len or not trg_len:
        return "EMPTY"

    ratio_len = src_len / float(trg_len)
    if ratio_len < RATIO_LENGTH or ratio_len > (1. / RATIO_LENGTH):
        return "RATIO_LENGTH"

    if src_len < MIN_LENGTH or trg_len < MIN_LENGTH:
        return "TOO_SHORT"

    if src_len > MAX_LENGTH or trg_len > MAX_LENGTH:
        return "TOO_LONG"

    num_alpha = sum(
        [1 if re.match(CHARS[src_lang], t, re.IGNORECASE) else 0 for t in src_toks])
    if num_alpha / float(src_len) < RATIO_ALPHA_WORDS:
        return "RATIO_ALPHA"

    char_alpha = len(re.findall(CHARS[src_lang], src, re.IGNORECASE))
    if char_alpha / float(len(src.replace(' ', ''))) < RATIO_ALPHA_CHARS:
        return "RATIO_CHARS"

    #if len(middle_period.findall(src)) != len(middle_period.findall(trg)):
    #    return "MIDDLE_PERIOD"

    #if src_lang in CHARS and trg_lang in CHARS:
    #    if (src[0].isalpha() and not src[0].isupper() and (len(src)>1 and src[1]!=')')) \
    #            or (trg[0].isalpha() and not trg[0].isupper() and (len(trg)>1 and trg[1]!=')')):
    #        return "START_CAPITAL"

    return None


def parse_user_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("-l1", "--src-lang", default='es')
    parser.add_argument("-l2", "--trg-lang", default='en')
    parser.add_argument("--debug", action='store_true')
    return parser.parse_args()


if __name__ == "__main__":
    main()
