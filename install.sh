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

if test -x /usr/bin/speedy ; then
	read -p "Do you want to use Speedy for a better performance? (Y/n)" answer
	test "$answer" = "y" -o "$answer" = "Y" -o -z "$answer" && sed -i -e '1i#!/usr/bin/speedy -- -r50 -M10 -t3600' $wd/cgi-bin/webdav.pl
fi	

echo -n "Compiling all wrapper ... "
for w in $wd/helper/*.c ; do
	gcc -o $wd/cgi-bin/$(basename $w .c) $w
done
echo "done."


echo -n "Fixing owner/group and rights ..."

strip $wd/cgi-bin/webdavwrapper*

chown root:root $wd/cgi-bin/webdavwrapper*
chmod a+rx,ug+s $wd/cgi-bin/webdavwrapper* 
chmod a+rx $wd $wd/cgi-bin $wd/cgi-bin/webdav.pl $wd/cgi-bin/afswrapper $wd/cgi-bin/smbwrapper
chmod -R a+r  $wd


echo "done."

$wd/checkenv

echo "Please don't forget to configure WebDAV CGI and your web server."
echo "That's it."


