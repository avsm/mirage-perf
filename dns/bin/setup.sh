#!/bin/bash -ex
#
# mirage-perf DNS experiments: setup environment, including building
# domUs
#
# NB. this pulls and installs a variety of packages, most locally but
# a few are installed via apt-get
#
# Richard Mortier <mort@cantab.net>

KERNEL=/boot/vmlinuz-3.3.0-trunk-amd64
INITRD=/boot/initrd-3.3.0-trunk-amd64
ROOTDIR=$(cd $(dirname $0)/.. 2>/dev/null; pwd -P)
[ ! -d $ROOTDIR/obj ] && mkdir -p $ROOTDIR/obj
pushd $ROOTDIR/obj

# check password existence
if [ ! -r $ROOTDIR/cfg/PASSWORD ]; then
  echo Please set password in $ROOTDIR/cfg/PASSWORD
  exit 1
fi

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

