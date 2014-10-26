# File : Makefile.PL
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME=>'smbclient',
	LIBS=>['-lsmbclient'],
	OBJECT=>'smbclient_wrap.o'
);
