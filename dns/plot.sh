#!/bin/bash -ex

ROOTDIR=$(pwd)

pushd data
rm -f result-*.txt

awk -- '
    /Queries per second/ {
        split(FILENAME, ns, "[.-]");
        fn = sprintf("result-%s-%s.tmp", ns[2], ns[3]);
        printf("%s %s\n", ns[4], $4) >> fn;
    }
    END { print "done!" }
    ' output-*.txt
for n in result-*.tmp; do
  sort -n $n > ${n%tmp}txt
done

popd

gnuplot plot.gp
