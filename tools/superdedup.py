#!/usr/bin/env python
import sys

def main():
    shashes, thashes = set(), set()
    for line in sys.stdin:
        parts = line.rstrip("\n").split('\t')

        src_hash = parts[2]
        trg_hash = parts[3]

        if src_hash not in shashes and trg_hash not in thashes:
            sys.stdout.write(line)
        shashes.add(src_hash)
        thashes.add(trg_hash)


if __name__ == "__main__":
    main()

