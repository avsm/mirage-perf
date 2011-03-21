set terminal pdf color enhanced size 5,4
set yrange [0:]
set logscale x
set xrange [1:1.1e5]

set output "dns-qps.pdf"
set key bottom left
plot 'data/result-unix-socket.txt' u 1:6  t "unix-socket" w lp,\
     'data/result-xen-direct.txt' u 1:6 t "xen-direct" w lp,\
     'data/result-bind9-unix.txt' u 1:6 t "bind9-unix" w lp,\
     'data/result-nsd-unix.txt' u 1:6 t "nsd-unix" w lp


set output "dns-rtt.pdf"
set xrange [1:1.1e5]
set key top left
plot [:][0:0.008] \
     'data/result-unix-socket.txt' u 1:($4-$5):2:3:($4+$5) t "unix-socket" w candlesticks,\
     ''                            u 1:4:4:4:4 with candlesticks lt -1 lw 2 notitle,\
     'data/result-xen-direct.txt' u 1:($4-$5):2:3:($4+$5) t "xen-direct" w candlesticks,\
     ''                            u 1:4:4:4:4 with candlesticks lt -1 lw 2 notitle,\
     'data/result-bind9-unix.txt' u 1:($4-$5):2:3:($4+$5) t "bind9-unix" w candlesticks,\
     ''                            u 1:4:4:4:4 with candlesticks lt -1lw 2 notitle,\
     'data/result-nsd-unix.txt' u 1:($4-$5):2:3:($4+$5) t "nsd-unix" w candlesticks,\
     ''                            u 1:4:4:4:4 with candlesticks lt -1 lw 2 notitle

