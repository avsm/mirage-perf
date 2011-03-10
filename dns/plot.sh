#!/bin/bash -ex

ROOTDIR=$(pwd)

pushd data
rm -f result-*.txt

awk -- '
    /Queries per second/ {
#        print FILENAME, $4 
        split(FILENAME, ns, "[.-]");
        fn = sprintf("result-%s-%s.txt", ns[1], ns[2])
        printf("%s %s\n", ns[4], $4) >> fn;
    }
    END { print "done!" }
' output-*.txt

#grep "Queries per second" *.txt | cut -d ":" -f 1,3 | tr -s " " | cut -d " " -f 1,2 | awk -- '{ split($1, fs, "[-.]"); printf("%s-%s %s %s\n", fs[2],fs[3], fs[5], fs[6]) }'

#gnuplot plot.gp
