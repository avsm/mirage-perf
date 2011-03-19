#!/bin/bash -ex

ROOTDIR=$(pwd)

pushd data
rm -f result-*.{txt,tmp}

awk -- '
    /RTT max:/ {
        split(FILENAME, ns, "[.-]");
        k = sprintf("result-%s-%s.tmp", ns[2], ns[3]);
        n = ns[4];
        print k, n;
        mx[k,n] = $3;
    }

    /RTT min:/ { mn[k,n] = $3 }
    /RTT average:/ { av[k,n] = $3 }
    /RTT std deviation:/ { sdv[k,n] = $4 }    
    /Queries per second:/ { qps[k,n] = $4 }

    END {
        for (kn in mn) {
            split(kn, t, SUBSEP);
            k = t[1]; n = t[2];
            printf("%s %s %s %s %s %s\n", 
                   n, mn[kn], mx[kn], av[kn], sdv[kn], qps[kn]) >> k
        }
        print "done!" ;
    }
    ' output-*.txt

for n in result-*.tmp ; do
  sort -n $n > ${n%tmp}txt
done

popd

gnuplot plot.gp
