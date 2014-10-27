#!/bin/bash
set -e
swig -v -perl -I/usr/include -I/usr/include/samba-4.0 smbclient.i
perl Makefile.PL
make
sudo make install
