#!/bin/sh -ex

RANGE="1 10 100 1000 10000 100000 1000000"

if [ -r "en_GB.dic.stripped" ]; then
  cut -f 1 -d "/" en_GB.dic > en_GB.dic.stripped
fi

for n in $RANGE ; do
  for f in rawdata.conf format.conf ; do
    rm -f -- "$f-$n"
    sed "s/@NHOSTS@/$n/g" $f > ${f%.conf}-$n.conf
  done
  for f in rawdata-$n.conf ; do
    rm -f -- "raw-$n.csv"
    ../dlz-perf-tools/dnsDataGen.pl $f
  done
  for f in format-$n.conf ; do
    rm -rf -- "named-$n/"
    mkdir named-$n
    ../dlz-perf-tools/dnsCSVDataReader.pl $f
  done
done

