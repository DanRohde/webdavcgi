#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2014 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
#########################################################################
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#########################################################################

package Filesys::SmbClient;

use strict;

our $VERSION = '1.000';
use smbclient;
use POSIX qw(:fcntl_h);

use constant {
	
	SMBC_WORKGROUP  	=> $smbclient::SMBC_WORKGROUP,
	SMBC_SERVER     	=> $smbclient::SMBC_SERVER,
	SMBC_FILE_SHARE 	=> $smbclient::SMBC_FILE_SHARE,
	SMBC_PRINTER_SHARE  	=> $smbclient::SMBC_PRINTER_SHARE,
	SMBC_COMMS_SHARE 	=> $smbclient::SMBC_COMMS_SHARE,
	SMBC_IPC_SHARE      	=> $smbclient::SMBC_IPC_SHARE,
	SMBC_DIR 		=> $smbclient::SMBC_DIR,
	SMBC_FILE		=> $smbclient::SMBC_FILE,
	SMBC_LINK		=> $smbclient::SMBC_LINK,

	SMB_CTX_FLAG_USE_KERBEROS 		=> $smbclient::SMB_CTX_FLAG_USE_KERBEROS,
	SMB_CTX_FLAG_FALLBACK_AFTER_KERBEROS	=> $smbclient::SMB_CTX_FLAG_FALLBACK_AFTER_KERBEROS,
	SMBCCTX_FLAG_NO_AUTO_ANONYMOUS_LOGON	=> $smbclient::SMBCCTX_FLAG_NO_AUTO_ANONYMOUS_LOGON,
	SMB_CTX_FLAG_USE_CCACHE			=> $smbclient::SMB_CTX_FLAG_USE_CCACHE,
};

sub new {
	my $class = shift;
	my $self = { };
	bless $self, $class;
	$self->_init(@_);
	return $self;
}

sub _init {
	my $self = shift;
	my %params = @_;

	$$self{flags} = $params{flags} // 0;
	$$self{username} = $params{username} // "\0";
	$$self{password} = $params{password} // "\0";
	$$self{workgroup} = $params{workgroup} // "\0";
	$$self{timeout} = $params{timeout} // 60;
	$$self{debug} = $params{debug} // 0;

	$$self{context} = smbclient::smbc_new_context();

	my ($c,$f) = ($$self{context}, $$self{flags});
	smbclient::smbc_setDebug($c, $$self{debug});
	smbclient::smbc_setOptionDebugToStderr($c, 1);
	smbclient::smbc_setOptionUseKerberos($c, $f & SMB_CTX_FLAG_USE_KERBEROS);
	smbclient::smbc_setOptionFallbackAfterKerberos($c, $f & SMB_CTX_FLAG_FALLBACK_AFTER_KERBEROS);
	smbclient::smbc_setOptionNoAutoAnonymousLogin($c, $f & SMBCCTX_FLAG_NO_AUTO_ANONYMOUS_LOGON);
	smbclient::smbc_setOptionUseCCache($c, $f & SMB_CTX_FLAG_USE_CCACHE);

	smbclient::smbc_setTimeout($c, $$self{timeout});

	smbclient::w_initAuth($c, $$self{username}, $$self{password}, $$self{workgroup});

	smbclient::smbc_init_context($c);
	smbclient::smbc_set_context($c);
}

sub opendir {
	my ($self, $url) = @_;
	return smbclient::smbc_opendir($url);
}
sub closedir {
	my ($self, $dh) = @_;
	return $self->_hr(smbclient::smbc_closedir($dh));
}
sub readdir {
	my ($self, $dh) = @_;
	return undef unless $dh>-1;
	if (wantarray)  {
		my @a = ();
		while (my $e = $self->readdir($dh)) {
			push @a, $e;
		}
		return @a;
	} 
	my $dirent = smbclient::smbc_readdir($dh);
	return $dirent ? smbclient::w_smbc_dirent_name_get($dirent) : undef;
}
sub readdir_struct {
	my ($self, $dh) = @_;
	return undef unless $dh>-1;
	if (wantarray) {
		my @a = ();
		while (my $e = $self->readdir_struct($dh)) {
			push @a, $e;
		}
		return @a;
	}
	my $dirent = smbclient::smbc_readdir($dh);
	return $dirent ? 
			[ 
				smbclientc::smbc_dirent_smbc_type_get($dirent), 
				smbclient::w_smbc_dirent_name_get($dirent), 
				smbclientc::smbc_dirent_comment_get($dirent) 
			] 
			: $dirent;
}
sub mkdir {
	my ($self, $url, $mode) = @_;
	return $self->_hr(smbclient::smbc_mkdir($url, $mode // 0666));
}
sub rmdir {
	my ($self, $url) = @_;
	return $self->_hr(smbclient::smbc_rmdir($url));
}
sub rmdir_recurse {
	my ($self, $url) = @_;
	my $fd = $self->opendir($url) || return 0;
	my @f = $self->readdir_struct($fd);
	$self->closedir($fd);
	foreach my $v (@f) {
		next if $$v[1] eq '.' || $$v[1] eq '..';
		my $u = $url.'/'.$$v[1];
		if ($$v[0] == SMBC_FILE) { $self->unlink($u); }
		elsif ($$v[0] == SMBC_DIR) { $self->rmdir_recurse($u); }
	}
	return $self->rmdir($url);
}
sub stat {
	my ($self, $url) = @_;
	my $stat = smbclient::w_create_struct_stat();
	my $ret = smbclient::smbc_stat($url, $stat);
	my $s = $ret == 0 ? smbclient::w_stat2str($stat) : "";
	smbclient::w_free_struct_stat($stat);
	$!=$ret unless $ret==0;
	return $ret == 0 ? split(/,/, $s) : ();
}
sub fstat {
	my ($self, $fh) = @_;
	my $stat = smbclient::w_create_struct_stat();
	my $ret = smbclient::smbc_fstat($fh, $stat);
	my $s = $ret == 0 ? smbclient::w_stat2str($stat) : "";
	smbclient::w_free_struct_stat($stat);
	$!=$ret unless $ret==0;
	return $ret == 0 ? split(/,/, $s) : ();
}
sub rename {
	my ($self, $old, $new) = @_;
	return $self->_hr(smbclient::smbc_rename($old,$new));
}
sub unlink {
	my ($self, $url) = @_;
	return $self->_hr(smbclient::smbc_unlink($url));
}
sub open {
	my ($self, $url, $mode) = @_;
	my $fn = $url;
	my $flags = O_RDONLY;
	if ($url=~/^>>(.*)$/) {
		$fn=$1;
		$flags = O_WRONLY | O_CREAT | O_APPEND;
	} elsif ($url=~/^>(.*)$/) {
		$fn=$1;
		$flags = O_WRONLY | O_CREAT | O_TRUNC;
	} elsif ($url=~/^<(.*)$/) {
		$fn=$1;
		$flags = O_RDONLY;
	}
	return smbclient::smbc_open($fn, $flags, $mode // '0666');
}
sub close {
	my ($self, $fh) = @_;
	return $self->_hr(smbclient::smbc_close($fh));
}
sub read {
	my ($self, $fh, $length) = @_;
	return smbclient::w_smbc_read($fh, $length // 4096);
}
sub write {
	my $self = shift;
	my $fh = shift;
	my $buf = join("",@_);
	return smbclient::w_smbc_write($fh, $buf, length($buf));	
}
sub seek {
	my ($self, $fh, $pos) = @_;
	return $self->_hr(smbclient::w_offt2int(smbclient::smbc_lseek($fh, smbclient::w_int2offt($pos), &POSIX::SEEK_SET)));
}
sub shutdown {
	my ($self,$flag) = @_;
	return $self->_hr(smbclient::smbc_free_context($$self{context}, $flag));
}
sub _hr {
	my ($self, $ret) = @_;
	$!= $ret unless $ret == 0;
	return $ret == 0 ? 1 : $ret;
}
1;
