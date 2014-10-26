#!/bin/bash
set -e
swig -v -perl -I/usr/include smbclient.i
perl Makefile.PL
make
sudo make install
