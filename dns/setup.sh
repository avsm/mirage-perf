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
