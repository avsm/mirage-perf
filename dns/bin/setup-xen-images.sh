#!/bin/bash -ex

ROOTDIR=$(cd $(dirname $0)/.. 2>/dev/null; pwd -P)
[ ! -d $ROOTDIR/obj ] && mkdir -p $ROOTDIR/obj
pushd $ROOTDIR/obj

# get xen-tools
if [ ! -d xen-tools ]; then
  #  git clone git://gitorious.org/xen-tools/xen-tools.git
  git clone git://github.com/mor1/xen-tools.git
  sudo apt-get install debootstrap libfile-slurp-perl libtext-template-perl

  pushd xen-tools
  sudo make install
  popd
fi

# build perf test domUs
if [ ! -d xen-images ]; then
  sudo apt-get install sshpass
  mkdir xen-images
  mkdir -p apt-cache

  SERVERIP=$(cat $ROOTDIR/cfg/SERVERIP)
  CLIENTIP=$(cat $ROOTDIR/cfg/CLIENTIP)
  PASSWORD=$(cat $ROOTDIR/cfg/PASSWORD)

  sudo http_proxy=$http_proxy \
    xen-create-image --force --verbose --password=$PASSWORD \
    --output=$(pwd)/xen-images --dir=$(pwd)/xen-images \
    --hostname=server.mirage-perf.local --bridge=perf0 \
    --ip=${SERVERIP} --gateway=10.0.0.1 --netmask=10.0.0.255 \
      --mirror=http://cdn.debian.net/debian/ --dist=squeeze \
      --cachedir=./apt-cache --role=udev --pygrub \
      --initrd=/boot/initrd.img-2.6.32-26-pvops \
      --kernel=/boot/vmlinuz-2.6.32-26-pvops
 
  sudo http_proxy=$http_proxy \
    xen-create-image --force --verbose --password=$PASSWORD \
    --output=$(pwd)/xen-images --dir=$(pwd)/xen-images \
    --hostname=client.mirage-perf.local --bridge=perf0 \
    --ip=${CLIENTIP} --gateway=10.0.0.1 --netmask=10.0.0.255 \
      --mirror=http://cdn.debian.net/debian/ --dist=squeeze \
      --cachedir=./apt-cache --role=udev --pygrub \
      --initrd=/boot/initrd.img-2.6.32-26-pvops \
      --kernel=/boot/vmlinuz-2.6.32-26-pvops

fi

# update domUs regardless
sudo xen-update-image --dir=./xen-images \
  client.mirage-perf.local server.mirage-perf.local

# ensure necessary perf tools in the right images
[ ! -d m ] && mkdir m

R=./m/root

sudo mount -o loop ./xen-images/domains/client.mirage-perf.local/disk.img ./m
sudo cp ../queryperf $R
sudo umount ./m

sudo mount -o loop ./xen-images/domains/server.mirage-perf.local/disk.img ./m
sudo cp -r nsd-install $R/nsd-install
sudo cp -r bind9-install $R/bind9-install
sudo umount ./m

popd
