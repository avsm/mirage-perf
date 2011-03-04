#!/bin/sh

RANGE="1 10 100 1000 10000"
for n in $RANGE ; do
  for f in rawdata.conf format.conf ; do
    rm -f -- "$n-$f"
    sed "s/@NHOSTS@/$n/g" $f > $n-$f
  done
  for f in $n-rawdata.conf ; do
    rm -f -- "$n-raw.csv"
    ../dlz-perf-tools/dnsDataGen.pl $f
  done
  for f in $n-format.conf ; do
    rm -rf -- "$n-named/"
    mkdir $n-named
    ../dlz-perf-tools/dnsCSVDataReader.pl $f
  done
done

