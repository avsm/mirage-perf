#!/bin/sh

ROOTDIR=$(pwd)

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
  cd dns-perf && tar xzvf ../DLZPerfTools-${V}.tar.gz
fi

# grab latest stable nsd3 since ubuntu package seems broken
if [ ! -d nsd-install ]; then
  V=3.2.7
  mkdir nsd-install
  wget http://www.nlnetlabs.nl/downloads/nsd/nsd-${V}.tar.gz
  tar xzvf nsd-${V}.tar.gz
  pushd nsd-${V}
  ./configure --prefix=${ROOTDIR}/obj/nsd-install
  make -j 16 && make install
fi
