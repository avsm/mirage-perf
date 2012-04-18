#!/bin/bash -ex
#
# mirage-perf DNS experiments: generate input data and configs
#
# Anil Madhavapeddy <anil@recoil.org>
# Richard Mortier <mort@cantab.net>

ROOTDIR=$(cd $(dirname $0)/.. 2>/dev/null; pwd -P)
[ ! -d data ] && mkdir data
pushd $ROOTDIR

export LC_ALL='C'

RANGE=$1
[ -z "$RANGE" ] && RANGE=$(cat ./cfg/RANGE)

zonefiles () {
  # generate config files
  for f in cfg/rawdata.conf cfg/format.conf ; do
    bn=$(basename $f)
    output="data/${bn%.conf}-$1.conf"
    if [ ! -r "$output" ] ; then
      rm -f -- "$output"
      sed "s/@NHOSTS@/$1/g" $f >| $output
    fi
  done

  # generate DNS data as CSV
  if [ ! -r "data/rawdata-$1.csv" ] ; then
    for f in data/rawdata-$1.conf ; do
      rm -f -- "rawdata-$1.csv"
      obj/dns-perf/dnsDataGen.pl $f
    done
  fi
  
  # convert CSV DNS data to zonefiles
  if [ ! -r "data/namedx-$1" ]; then
    for f in data/format-$1.conf ; do
      rm -rf -- "data/named-$1/"
      mkdir data/named-$1
      obj/dns-perf/dnsCSVDataReader.pl $f

      zd=${ROOTDIR}/data/named-$1
      zf=${ROOTDIR}/$(grep file ${zd}/named.conf-data | cut -d '"' -f 2)
      echo "ns1	10	IN	a	127.0.0.1" >> $zf
      echo "ns2	10	IN	a	127.0.0.1" >> $zf
      echo >> $zf
      mkdir -p ${ROOTDIR}/data/namedx-$1
      cp ${zf} ${ROOTDIR}/data/namedx-$1/zones.db
    done
  fi

  # convert zone files to mirage crunches 
  if [ ! -r "data/crunch-$1" ]; then
    mkdir -p data/crunch-$1
    mir-crunch -name fs data/namedx-$1 > data/crunch-$1/datax.ml
    cp app/crunchDNS.mir app/serverDNS.ml data/crunch-$1
    (cd data/crunch-$1 && mir-build xen/crunchDNS.xen)
    (cd data/crunch-$1 && mir-build unix-socket/crunchDNS.bin)
    (cd data/crunch-$1 && mir-build unix-direct/crunchDNS.bin)
  fi
}
  
servers () {
  # convert zone file to a VBD
  rm -f data/named-$1.vbd
  mkdir -p data
  dd if=/dev/zero of=data/named-$1.vbd bs=1024 count=10
  chmod 644 data/named-$1.vbd
  (cd data/namedx-$1 && mir-fs-create . ../named-$1.vbd)
  # generate minios configs
  sed "s!@VBD@!$ROOTDIR/data/named-$1.vbd!g;s!@NAME@!deens$1!g;s!@KERNEL@!/home/rmm/mirage/mirage-perf/dns/data/crunch-$1/_build/xen/crunchDNS.xen!g" cfg/minios.conf > data/minios-$1.conf
}

nsdconf () {
  pushd obj/nsd-install
  
  zd=$ROOTDIR/data/named-$1
  zf=$(grep file ${zd}/named.conf-data | cut -d '"' -f 2)
  z=$(grep zone ${zd}/named.conf-data | cut -d'"' -f 2)

  sed "s!@ZONE@!${z}!g;s!@ZONEFILE@!${zf}!g" $ROOTDIR/cfg/nsd.conf >| ./etc/nsd/nsd-$1.conf
  popd
  ./obj/nsd-install/sbin/zonec -v -C -f data/nsd-$1.db -z $zf -o $z
}

for n in $RANGE ; do
  zonefiles $n
  servers $n
  nsdconf $n
done

