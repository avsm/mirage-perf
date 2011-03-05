#!/bin/sh -ex

export LC_ALL='C'

RANGE=$(cat RANGE)

if [ ! -r "data/en_GB.dic.stripped" ]; then
  cut -f 1 -d "/" data/en_GB.dic >| data/en_GB.dic.stripped
fi

for n in $RANGE ; do
  for f in rawdata.conf format.conf ; do
    rm -f -- "$f-$n"
    sed "s/@NHOSTS@/$n/g" $f > data/${f%.conf}-$n.conf
  done
  for f in data/rawdata-$n.conf ; do
    rm -f -- "raw-$n.csv"
    dlz-perf-tools/dnsDataGen.pl $f
  done
  for f in data/format-$n.conf ; do
    rm -rf -- "named-$n/"
    mkdir data/named-$n
    dlz-perf-tools/dnsCSVDataReader.pl $f
  done
done

