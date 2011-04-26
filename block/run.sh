#!/bin/bash -ex
# Performance tests for blk read/writes

ROOTDIR=`pwd`

FILE=test2.vbd
function xen_direct {
  sudo xl destroy blk || true
  # compile
  mir-xen block.xen
  rm -rf vobj
  mkdir vobj
  dd if=/dev/zero of=vobj/t1 bs=1M count=1
  dd if=/dev/zero of=vobj/t2 bs=1M count=1
  echo 1 >> vobj/t2
  dd if=/dev/zero of=${FILE} bs=1M count=32
  (cd vobj && mir-fs-create . ../${FILE})
  # spawn VM
  sed -e "s,@VBD@,`pwd`/${FILE},g" < minios-config > _build/minios-config
  cd _build
  sudo xl create -c minios-config 
}

xen_direct
