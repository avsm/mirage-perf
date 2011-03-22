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

if [ -z "$(which mir-unix-socket)" ]; then
  echo 'Add mirage tools to your path!'
  exit
fi

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
  if [ ! -r "data/named-$1" ]; then
    for f in data/format-$1.conf ; do
      rm -rf -- "named-$1/"
      mkdir data/named-$1
      obj/dns-perf/dnsCSVDataReader.pl $f

      zd=${ROOTDIR}/data/named-$1
      zf=${ROOTDIR}/$(grep file ${zd}/named.conf-data | cut -d '"' -f 2)
      echo "ns1	10	IN	a	127.0.0.1" >> $zf
      echo "ns2	10	IN	a	127.0.0.1" >> $zf
    done
  fi
}
  
servers () {
  # generate server code
  pushd app
  if [ ! -r "app/server$1.ml" ]; then
    for f in serverTemplate.ml ; do
      rm -f -- "server$1.ml" "deens$1.mir"
      echo "Server$1" >| deens$1-direct.mir
      echo "Server$1" >| deens$1-socket.mir
      echo "Server$1" >| deens$1.mir
      
      ZONEFILES=$(find ../data/named-$1 -name '*.db' -print)
      cp serverTemplate.ml server$1.ml
      for zf in ${ZONEFILES}; do
        sed "/@ZONEBUF@/ {
        r $zf
        }" < server$1.ml >| server$1.ml.tmp &&
        mv server$1.ml.tmp server$1.ml
      done

      sed "/@ZONEBUF@/ {
      d
      }" < server$1.ml >| server$1.ml.tmp &&
      mv server$1.ml.tmp server$1.ml

      mir-unix-direct deens$1-direct.bin && cp _build/deens$1-direct.bin .
      mir-unix-socket deens$1-socket.bin && cp _build/deens$1-socket.bin .
      mir-xen deens$1.xen && cp _build/deens$1.xen .
    done
  fi
  popd

  # generate minios configs
  if [ ! -r "data/minios-$1.conf" ]; then
    sed "s!@NAME@!deens$1!g;s!@KERNEL@!deens$1.xen!g" cfg/minios.conf > data/minios-$1.conf
  fi
}

nsdconf () {
  pushd obj/nsd-install
  
  zd=$ROOTDIR/data/named-$1
  zf=$(grep file ${zd}/named.conf-data | cut -d '"' -f 2)
  z=$(grep zone ${zd}/named.conf-data | cut -d'"' -f 2)

  sed "s!@ZONE@!${z}!g;s!@ZONEFILE@!${zf}!g" $ROOTDIR/cfg/nsd.conf >| ./etc/nsd/nsd-$1.conf

  popd
}

for n in $RANGE ; do
  zonefiles $n
  servers $n
  nsdconf $n
done

# distribute config and data files into domU images
[ ! -d m ] && mkdir m

R=./m/root

sudo mount -o loop ./obj/xen-images/domains/client.mirage-perf.local/disk.img ./m
sudo cp -v $ROOTDIR/data/queryperf-* $R
sudo cp -v $ROOTDIR/queryperf $R
sudo umount ./m

sudo mount -o loop ./obj/xen-images/domains/server.mirage-perf.local/disk.img ./m
sudo cp -vr obj/nsd-install/ $R
sudo cp -vr obj/bind9-install/ $R
sudo [ ! -d $R/data ] && sudo mkdir $R/data
sudo cp -vr $ROOTDIR/data/named-* $R/data
sudo cp -vr app/*.bin $R
sudo umount ./m

popd
