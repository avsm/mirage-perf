#!/bin/bash -ex

export LC_ALL='C'

ROOTDIR=$(pwd)
RANGE=$(cat RANGE)

[ ! -d "data" ] && mkdir data

dictionary () {
  if [ ! -r "data/input" ]; then
    echo "mirage-perf.local" > data/input
    cut -f 1 -d "/" data/en_GB.dic | grep -v -- "[^a-zA-Z0-9-]" | grep -v -- "^-" >> data/input
  fi
}

zonefiles () {
  n=$1
  
  # generate config files
  for f in rawdata.conf format.conf ; do
    output="data/${f%.conf}-$n.conf"
    if [ ! -r "$output" ] ; then
      rm -f -- "$output"
      sed "s/@NHOSTS@/$n/g" $f > $output
    fi
  done

  # generate DNS data as CSV
  if [ ! -r "data/raw-$n.csv" ] ; then
    for f in data/rawdata-$n.conf ; do
      rm -f -- "raw-$n.csv"
      dlz-perf-tools/dnsDataGen.pl $f
    done
  fi
  
  # convert CSV DNS data to zonefiles
  if [ ! -r "data/named-$n" ]; then
    for f in data/format-$n.conf ; do
      rm -rf -- "named-$n/"
      mkdir data/named-$n
      dlz-perf-tools/dnsCSVDataReader.pl $f
    done
  fi
}
  
servers () {
  n=$1
  
  # generate server code
  pushd app
  if [ ! -r "app/server$n.ml" ]; then
    for f in serverTemplate.ml ; do
      rm -f -- "server$n.ml" "deens$n.mir"
      echo "Server$n" > deens$n.mir
      ZONEFILES=$(find ../data/named-$n -name '*.db' -print)
      cp serverTemplate.ml server$n.ml
      for zf in ${ZONEFILES}; do
        sed "/@ZONEBUF@/ {
        r $zf
        }" < server$n.ml > server$n.ml.tmp &&
        mv server$n.ml.tmp server$n.ml
      done

      sed "/@ZONEBUF@/ {
      d
      }" < server$n.ml > server$n.ml.tmp &&
      mv server$n.ml.tmp server$n.ml
    done
  fi
  popd

  # generate minios configs
  if [ ! -r "minios-$n.conf" ]; then
    sed "s!@NAME@!deens$n!g;s!@KERNEL@!deens$n.xen!g" minios.conf > minios-$n.conf
  fi
}

nsdconf () {
  n=$1

  pushd obj/nsd-install
  
  db=${ROOTDIR}/data/nsd-${n}.db
  zd=${ROOTDIR}/data/named-${n}
  zf=${ROOTDIR}/$(grep file ${zd}/named.conf-data | cut -d '"' -f 2)
  z=$(grep zone ${zd}/named.conf-data | cut -d'"' -f 2)

  sed "s!@ZONE@!${z}!g;s!@ZONEFILE@!${zf}!g" ${ROOTDIR}/nsd.conf > ./etc/nsd/nsd-$n.conf
  
  ./sbin/zonec -v -C -f $db -z $zf -o $z
}

  
dictionary
for n in $RANGE ; do
  zonefiles $n
  servers $n
  nsdconf $n
done

