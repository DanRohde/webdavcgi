#!/usr/bin/perl

use smbclient;
use Data::Dumper;


my $context = smbclient::smbc_new_context();

smbclient::smbc_setDebug($context, 10);
smbclient::smbc_setOptionDebugToStderr($context, 1);
smbclient::smbc_setTimeout($context, 60);

smbclient::w_initAuth($context, 'cms_rohdedan@CMS.HU-BERLIN.DE','','');
smbclient::smbc_setOptionUseKerberos($context, 1);

smbclient::smbc_init_context($context);
smbclient::smbc_set_context($context);



my $dir = smbclient::smbc_opendir('smb://hucms11c.cms.hu-berlin.de/home/Abt4/cms_rohdedan/');

print STDERR "dir=$dir\n";


while (my $dirent = smbclient::smbc_readdir($dir)) {

	print sprintf("name: \%s, type: \%d\n",smbclient::w_smbc_dirent_name_get($dirent), smbclientc::smbc_dirent_smbc_type_get($dirent));

}
smbclient::smbc_closedir($dir);

