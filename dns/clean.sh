#!/bin/sh -ex

rm -f data/input

RANGE=$(cat RANGE)
for n in $RANGE; do  
  rm -rf -- data/named-$n
  ( cd data && rm -f format-$n.conf queryperf-$n.txt raw-$n.csv rawdata-$n.conf) ;
  ( cd app && rm -f server$n.ml deens$n.mir ) ;
done


      
