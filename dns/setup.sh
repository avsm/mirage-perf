#!/bin/bash -ex

ROOTDIR=$(pwd)
SERVERIP=$(cat SERVERIP)
CLIENTIP=$(cat CLIENTIP)

[ ! -d obj ] && mkdir -p obj
cd obj

# compile up queryperf
if [ ! -x ../queryperf ]; then
  V=9.7.3
  wget http://ftp.isc.org/isc/bind9/${V}/bind-${V}.tar.gz
  tar -zxvf bind-${V}.tar.gz
  cd bind-${V}/contrib/queryperf
  ./configure && make
  cp queryperf ../../../..
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
fi

# build latest bind 
if [ ! -d bind9-install ]; then
  V=9.7.3
  mkdir bind9-install
  wget http://ftp.isc.org/isc/bind9/${V}/bind-${V}.tar.gz  
  tar -zxvf bind-${V}.tar.gz
  cd bind-${V}
  ./configure --prefix=${ROOTDIR}/obj/bind9-install
  make -j 16 && make all install
fi

# get xen-tools
if [ ! -d xen-tools ]; then
  git clone git://gitorious.org/xen-tools/xen-tools.git
  pushd xen-tools
  sudo make install
  popd
  sudo apt-get install debootstrap libfile-slurp-perl libtext-template-perl
fi

# build perf test domUs
if [ ! -d xen-images ]; then
  mkdir xen-images
  
  sudo http_proxy=$http_proxy \
    xen-create-image --force --verbose --accounts --output=$(pwd)/xen-images \
    --dir=$(pwd)/xen-images --hostname=server.mirage-perf.local --bridge=perf0 \
    --ip=${SERVERIP} --gateway=10.0.0.1 --netmask=10.0.0.255 

    sudo http_proxy=$http_proxy \
      xen-create-image --force --verbose --accounts --output=$(pwd)/xen-images \
      --dir=$(pwd)/xen-images --hostname=client.mirage-perf.local --bridge=perf0 \
      --ip=${CLIENTIP} --gateway=10.0.0.1 --netmask=10.0.0.255 

fi
