#!/bin/bash -ex

ROOTDIR=$(pwd)

pushd data
rm -f result-*.txt

awk -- '
    /Queries per second/ {
        split(FILENAME, ns, "[.-]");
        fn = sprintf("result-%s-%s.txt", ns[2], ns[3]);
        printf("%s %s\n", ns[4], $4) >> fn;
    }
    END { print "done!" }
' output-*.txt
popd

gnuplot plot.gp
