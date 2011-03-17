Richard Mortier <mort@cantab.net>

* install xen-tools

    git clone git://gitorious.org/xen-tools/xen-tools.git
    cd xen-tools && sudo make install
    mkdir xen-images

* use xen-tools to build xen images

assuming you're building guests of the same flavour as dom0, i.e.,
ubuntu on ubuntu, 

1. ensure you've the right packages installed

    sudo apt-get install debootstrap libfile-slurp-perl libtext-template-perl

2. then build the client and server guest VM images

    sudo http_proxy=$http_proxy xen-create-image --force --verbose \
       --dir=xen-images --hostname=server.mirage-perf.local \
       --ip=10.0.0.2 --gateway=10.0.0.1 --netmask=10.0.0.255 

    sudo http_proxy=$http_proxy xen-create-image --force --verbose \
       --dir=xen-images --hostname=client.mirage-perf.local \
       --ip=10.0.0.3 --gateway=10.0.0.1 --netmask=10.0.0.255 

to build cross-distribution, e.g., a debian image on ubuntu, use the `--mirror`
and `--dist` switches: 

    sudo http_proxy=$http_proxy xen-create-image --force --verbose \
       --dir=xen-images --hostname=debian.mirage-perf.local \
       --ip=10.0.0.2 --gateway=10.0.0.1 --netmask=10.0.0.255 \
       --mirror=http://cdn.debian.net/debian/ --dist=squeeze \
       --cachedir=./apt-cache --role=udev --pygrub \
       --initrd=/boot/initrd.img-2.6.32-26-pvops \
       --kernel=/boot/vmlinuz-2.6.32-26-pvops

to update existing images, 

    sudo xen-update-image --dir=./xen-images \
       client.mirage-perf.local server.mirage-perf.local

3. 

