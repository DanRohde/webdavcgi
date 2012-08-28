#!/bin/bash
###############################################################
# (C) ZE CMS, Humboldt-Universiteat zu Berlin
# Written 2011,2012 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
###############################################################

wd=$(dirname $0)
test "$wd" = "." && wd=$(pwd)

if test "$UID" != 0 ; then
	echo "Please start this script with root rights"
	echo "sudo bash $0"
	exit 1
fi

echo -n "Compiling wrapper ..."
gcc -o $wd/cgi-bin/webdavwrapper $wd/helper/webdavwrapper.c
gcc -o $wd/cgi-bin/webdavwrapper-krb $wd/helper/webdavwrapper-krb.c
gcc -o $wd/cgi-bin/webdavwrapper-afs $wd/helper/webdavwrapper-afs.c
gcc -o $wd/cgi-bin/webdavwrapper-smb $wd/helper/webdavwrapper-smb.c
echo "done."


echo -n "Fixing owner/group and rights ..."

strip $wd/cgi-bin/webdavwrapper*

chown root:root $wd/cgi-bin/webdavwrapper*
chmod a+rx,ug+s $wd/cgi-bin/webdavwrapper* 
chmod a+rx $wd $wd/cgi-bin $wd/cgi-bin/webdav.pl $wd/cgi-bin/afswrapper 
chmod -R a+r  $wd


echo "done."

$wd/checkenv

echo "Please don't forget to configure WebDAV CGI and your web server."
echo "That's it."


