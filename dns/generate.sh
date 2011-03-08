#!/bin/sh -ex

export LC_ALL='C'

RANGE=$(cat RANGE)

if [ ! -r "data/input" ]; then
  echo "mirage-perf.local" > data/input
  cut -f 1 -d "/" data/en_GB.dic | grep -v "[^a-zA-Z0-9-]" | grep -v "^-" >> data/input
fi

for n in $RANGE ; do
  # generate config files
  for f in rawdata.conf format.conf ; do
    rm -f -- "$f-$n"
    sed "s/@NHOSTS@/$n/g" $f > data/${f%.conf}-$n.conf
  done

  # generate DNS data as CSV
  for f in data/rawdata-$n.conf ; do
    rm -f -- "raw-$n.csv"
    dlz-perf-tools/dnsDataGen.pl $f
  done

  # convert CSV DNS data to zonefiles
  for f in data/format-$n.conf ; do
    rm -rf -- "named-$n/"
    mkdir data/named-$n
    dlz-perf-tools/dnsCSVDataReader.pl $f
  done

  # generate server code
  cd app
  for f in serverTemplate.ml ; do
    rm -f -- "server$n.ml" "deens$n.mir""
    echo "Server$n" > deens$n.mir
    ZONEFILE=$(find ../data/named-$n -name '*.db' -print)
    for zf in ${ZONEFILE}; do 
      sed '/@ZONEFILE@/ { r $zf } < serverTemplate.ml > serverTemplate.ml.tmp &&
      mv serverTemplate.ml.tmp serverTemplate.ml
    done
    sed '/@ZONEFILE@/ { d }' < serverTemplate.ml > serverTemplate.ml.tmp
    mv serverTemplate.ml.tmp serverTemplate.ml
  done
    
done

