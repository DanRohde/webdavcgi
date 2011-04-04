#!/bin/bash
##########################################################
# (C) ZE CMS, Humboldt-Universiteat zu Berlin
# Written 2011 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
##########################################################

CGIPATHS="/usr/lib/cgi-bin /usr/local/cgi-bin /usr/local/www/cgi-bin /etc/apache2/cgi-bin /etc/apache/cgi-bin /srv/cgi-bin"


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
test "$krb" = "y" -o "$krb" = "Y"  && usekrb=1

echo -n "Compiling wrapper ..."
if test "$usekrb" = 0 ; then
	gcc -o cgi-bin/webdavwrapper helper/webdavwrapper.c
else
	read -p "Please enter your Kerberos domain (without @ and with uppercase letters (e.g. EXAMPLE.ORG): " domain
	sed -e 's/@EXAMPLE.ORG/@'$domain'/g' < helper/webdavwrapper-krb.c > helper/webdavwrapper-krb-custom.c
	test "$usekrb" = 1 && gcc -o cgi-bin/webdavwrapper helper/webdavwrapper-krb-custom.c
fi
echo "done."


echo -n "Fixing owner/group and rights ..."

strip cgi-bin/webdavwrapper

chown root:root cgi-bin/webdavwrapper 
chmod a+rx,ug+s cgi-bin/webdavwrapper 
chmod a+rx cgi-bin/webdav.pl

echo "done."



echo -n "Linking webdav.pl and webdavwrapper to your cgi-bin ($cgibin) ..."
test -e $cgibin/webdav.pl && mv $cgibin/webdav.pl $cgibin/webdav.pl.$(date +%Y%m%d-%H%M%S)
test -e $cgibin/webdavwrapper && mv $cgibin/webdavwrapper $cgibin/webdavwrapper.$(date +%Y%m%d-%H%M%S)

ln -s $(pwd)/cgi-bin/webdav.pl $cgibin/webdav.pl
ln -s $(pwd)/cgi-bin/webdavwrapper $cgibin/webdavwrapper
echo "done."

if perl $cgibin/webdav.pl 1>/dev/null 2>&1; then
	echo "Okay, all perl modules seems to be available."
else
	echo -- perl -c $cgibin/webdav.pl  failed
	perl -c $cgibin/webdav.pl
	echo
	echo Please install all required Perl modules.
	echo
	exit 1
fi

echo "Please don't forget to configure WebDAV CGI and your web server."
echo "That's it."



