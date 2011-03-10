set terminal pdf color enhanced fsize 14 size 5,4
set output "dns-perf.pdf"

#set title ""
set boxwidth 0.9 absolute
set style linespoints lt 2

set logscale x

plot 't' u 1:2 t "unix-direct" w lp,\
     't' u 1:3  t "unix-socket" w lp,\
     't' u 1:4 t "xen-direct" w lp

