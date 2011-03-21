#!/bin/bash -ex
#
# mirage-perf DNS experiments: remove generated files; leaves result
# data in place
#
# Richard Mortier <mort@cantab.net>

#function canonpath () 
#{ 
#    echo $(cd $(dirname $1); pwd -P)/$(basename $1)
#}

ROOTDIR=$(dirname $(readlink -f $0))

rm -f data/input

RANGE=$(cat RANGE)
for n in $RANGE; do  
  rm -rf -- data/named-$n obj/nsd-install/etc/nsd/nsd-$n.conf
  ( cd data && rm -f format-$n.conf queryperf-$n.txt \
  rawdata-$n.csv rawdata-$n.conf minios-$n.conf nsd-$n.db ) 
  ( cd app && rm -rf server$n.ml deens$n.mir deens$n-*.mir _build )
done

# distribute config and data files into domU images
[ ! -d m ] && mkdir m
R=./m/root
sudo mount -o loop ./obj/xen-images/domains/client.mirage-perf.local/disk.img ./m
sudo rm -rf $R/data
sudo umount ./m

sudo mount -o loop ./obj/xen-images/domains/server.mirage-perf.local/disk.img ./m
sudo rm -rf $R/nsd-install/
sudo rm -rf $R/bind9-install/
sudo rm -rf $R/named-* 
sudo rm -f $R/*.bin
sudo umount ./m
