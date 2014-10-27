# File : Makefile.PL
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME=>'smbclient',
	LIBS=>['-lsmbclient'],
	OBJECT=>'smbclient_wrap.o',
	INC=>'-I/usr/include -I/usr/include/samba-4.0'

);
