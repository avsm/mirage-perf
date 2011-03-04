#!/bin/sh

# compile up queryperf
if [ ! -x queryperf ]; then
  V=9.7.3
  rm -rf obj
  mkdir -p obj
  cd obj
  wget http://ftp.isc.org/isc/bind9/${V}/bind-${V}.tar.gz
  tar -zxvf bind-${V}.tar.gz
  cd bind-${V}/contrib/queryperf
  ./configure && make
  cp queryperf ../../../..
fi

# grab dns-perf-tools
if [ ! -d obj/dns-perf ]; then
  mkdir -p obj/dns-perf
  cd obj
  wget http://downloads.sourceforge.net/project/bind-dlz/DLZ%20Perf%20Tools/DLZPerfTools-1.1/DLZPerfTools-1.1.tar.gz
  cd dns-perf && tar xzvf ../DLZPerfTools-1.1.tar.gz
fi
