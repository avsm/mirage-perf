#!/bin/bash -ex

export LC_ALL='C'

ROOTDIR=$(pwd)
RANGE=$(cat RANGE)

if [ -z "$(which mir-unix-socket)" ]; then
  echo 'Add mirage tools to your path!'
  exit
fi

[ ! -d "data" ] && mkdir data

zonefiles () {
  cd ${ROOTDIR}
  n=$1
  
  # generate config files
  for f in rawdata.conf format.conf ; do
    output="data/${f%.conf}-$n.conf"
    if [ ! -r "$output" ] ; then
      rm -f -- "$output"
      sed "s/@NHOSTS@/$n/g" ${f} > $output
    fi
  done

  # generate DNS data as CSV
  if [ ! -r "data/rawdata-$n.csv" ] ; then
    for f in data/rawdata-$n.conf ; do
      rm -f -- "rawdata-$n.csv"
      obj/dns-perf/dnsDataGen.pl $f
    done
  fi
  
  # convert CSV DNS data to zonefiles
  if [ ! -r "data/named-$n" ]; then
    for f in data/format-$n.conf ; do
      rm -rf -- "named-$n/"
      mkdir data/named-$n
      obj/dns-perf/dnsCSVDataReader.pl $f

      zd=${ROOTDIR}/data/named-${n}
      zf=${ROOTDIR}/$(grep file ${zd}/named.conf-data | cut -d '"' -f 2)
      echo "ns1	10	IN	a	127.0.0.1" >> $zf
      echo "ns2	10	IN	a	127.0.0.1" >> $zf
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
      echo "Server$n" > deens$n-direct.mir
      echo "Server$n" > deens$n-socket.mir
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

      mir-unix-direct deens$n-direct.bin && cp _build/deens$n-direct.bin .
      mir-unix-socket deens$n-socket.bin && cp _build/deens$n-socket.bin .
      mir-xen deens$n.xen && cp _build/deens$n.xen .
    done
  fi
  popd

  # generate minios configs
  if [ ! -r "minios-$n.conf" ]; then
    sed "s!@NAME@!deens$n!g;s!@KERNEL@!deens$n.xen!g" minios.conf > ./data/minios-$n.conf
  fi
}

nsdconf () {
  n=$1

  pushd obj/nsd-install
  
  zd=$ROOTDIR/data/named-${n}
  zf=$(grep file ${zd}/named.conf-data | cut -d '"' -f 2)
  z=$(grep zone ${zd}/named.conf-data | cut -d'"' -f 2)

  sed "s!@ZONE@!${z}!g;s!@ZONEFILE@!${zf}!g" ${ROOTDIR}/nsd.conf > ./etc/nsd/nsd-$n.conf

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
