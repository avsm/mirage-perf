#!/bin/bash -ex

[ ! -r PASSWORD ] && ( echo Please set password in ./PASSWORD ; exit 1 )

ROOTDIR=$(pwd)
SERVERIP=$(cat SERVERIP)
CLIENTIP=$(cat CLIENTIP)
PASSWORD=$(cat PASSWORD)
                        
[ ! -d obj ] && mkdir -p obj
cd obj

# pull en_GB dictonary
if [ ! -d dictionary ]; then
  mkdir dictionary
  pushd dictionary
  wget http://en-gb.pyxidium.co.uk/dictionary/en_GB.zip

  unzip en_GB.zip
  echo "mirage-perf.local" > input
  cut -f 1 -d "/" en_GB.dic | grep -v -- "[^a-zA-Z0-9-]" | grep -v -- "^-" >> input

  popd
fi

# compile up queryperf
if [ ! -x ../queryperf ]; then
  V=9.7.3
  wget http://ftp.isc.org/isc/bind9/${V}/bind-${V}.tar.gz
  tar -zxvf bind-${V}.tar.gz
  pushd bind-${V}/contrib/queryperf
  ./configure && make
  cp queryperf ../../../..
  popd
fi

# grab dns-perf-tools
if [ ! -d dns-perf ]; then
  V=1.1
  mkdir -p dns-perf
  wget http://downloads.sourceforge.net/project/bind-dlz/DLZ%20Perf%20Tools/DLZPerfTools-${V}/DLZPerfTools-${V}.tar.gz
  pushd dns-perf
  tar xzvf ../DLZPerfTools-${V}.tar.gz
  popd
fi

# grab latest stable nsd3 since ubuntu package seems broken
if [ ! -d nsd-install ]; then
  V=3.2.7
  mkdir nsd-install
  wget http://www.nlnetlabs.nl/downloads/nsd/nsd-${V}.tar.gz
  tar xzvf nsd-${V}.tar.gz
  pushd nsd-${V}
  ./configure --prefix=${ROOTDIR}/obj/nsd-install
  make -j 16 && make all install
  popd
fi

# build latest bind 
if [ ! -d bind9-install ]; then
  V=9.7.3
  mkdir bind9-install
  wget http://ftp.isc.org/isc/bind9/${V}/bind-${V}.tar.gz  
  tar -zxvf bind-${V}.tar.gz
  pushd bind-${V}
  ./configure --prefix=${ROOTDIR}/obj/bind9-install
  make -j 16 && make all install
  popd
fi

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
  
  sudo http_proxy=$http_proxy \
    xen-create-image --force --verbose --password=$PASSWORD \
    --output=$(pwd)/xen-images --dir=$(pwd)/xen-images \
    --hostname=server.mirage-perf.local --bridge=perf0 \
    --ip=${SERVERIP} --gateway=10.0.0.1 --netmask=10.0.0.255 

  sudo http_proxy=$http_proxy \
    xen-create-image --force --verbose --password=$PASSWORD \
    --output=$(pwd)/xen-images --dir=$(pwd)/xen-images \
    --hostname=client.mirage-perf.local --bridge=perf0 \
    --ip=${CLIENTIP} --gateway=10.0.0.1 --netmask=10.0.0.255 

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
