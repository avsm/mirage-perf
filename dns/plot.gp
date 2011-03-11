set terminal pdf color enhanced size 5,4
set output "dns-perf.pdf"

#set title ""
set boxwidth 0.9 absolute

set yrange [0:]
set logscale x
set xrange [1:]

plot 'data/result-unix-socket.txt' u 1:2 t "unix-direct" w lp,\
     'data/result-unix-direct.txt' u 1:2  t "unix-socket" w lp,\
     'data/result-xen-direct.txt' u 1:2 t "xen-direct" w lp,\
     'data/result-bind9-unix.txt' u 1:2 t "bind9-unix" w lp,\
     'data/result-nsd-unix.txt' u 1:2 t "nsd-unix" w lp
