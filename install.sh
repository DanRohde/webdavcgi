#!/bin/bash
##########################################################
# (C) ZE CMS, Humboldt-Universiteat zu Berlin
# Written 2011 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
##########################################################

CGIPATHS="/usr/lib/cgi-bin /usr/local/cgi-bin /usr/local/www/cgi-bin /etc/apache2/cgi-bin /etc/apache/cgi-bin /srv/cgi-bin"



wd=$(dirname $0)
test "$wd" = "." && wd=$(pwd)

if test "$UID" != 0 ; then
	echo "Please start this script with root rights"
	echo "sudo bash $0"
	exit 1
fi

cgibin=""
for cb in $CGIPATHS ; do
	if test -e $cb  ; then
		cgibin=$cb
		break
	fi
done

read -p "Please enter your cgi-bin path ($cgibin): " cb
test "$cb" != "" && cgibin=$cb

if test ! -e "$cgibin" ; then
	echo "Sorry, cannot find your cgi-bin '$cgibin'"
	exit 1
fi

usekrb=0
read -p "Do you use Kerberos authentication? (N/y): " krb
if test "$krb" = "y" -o "$krb" = "Y" ; then
	usekrb=1
	read -p "Please enter your Kerberos domain (without @ and with uppercase letters (e.g. EXAMPLE.ORG): " domain
fi

echo -n "Compiling wrapper ..."
if test "$usekrb" = 0 ; then
	gcc -o $wd/cgi-bin/webdavwrapper helper/webdavwrapper.c
else
	sed -e 's/@EXAMPLE.ORG/@'$domain'/g' < $wd/helper/webdavwrapper-krb.c > $wd/helper/webdavwrapper-krb-custom.c
	gcc -o $wd/cgi-bin/webdavwrapper $wd/helper/webdavwrapper-krb-custom.c
fi
echo "done."


echo -n "Fixing owner/group and rights ..."

strip $wd/cgi-bin/webdavwrapper

chown root:root $wd/cgi-bin/webdavwrapper 
chmod a+rx,ug+s $wd/cgi-bin/webdavwrapper 
chmod a+rx $wd/cgi-bin/webdav.pl

echo "done."



echo -n "Linking webdav.pl and webdavwrapper to your cgi-bin ($cgibin) ..."
test -e $cgibin/webdav.pl && mv $cgibin/webdav.pl $cgibin/webdav.pl.$(date +%Y%m%d-%H%M%S)
test -e $cgibin/webdavwrapper && mv $cgibin/webdavwrapper $cgibin/webdavwrapper.$(date +%Y%m%d-%H%M%S)

ln -s $wd/cgi-bin/webdav.pl $cgibin/webdav.pl
ln -s $wd/cgi-bin/webdavwrapper $cgibin/webdavwrapper
echo "done."

$wd/checkenv

echo "Please don't forget to configure WebDAV CGI and your web server."
echo "That's it."


