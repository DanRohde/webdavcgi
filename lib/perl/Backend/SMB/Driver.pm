#!/usr/bin/perl
#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2011 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package Backend::SMB::Driver;

use strict;
#use warnings;

use Backend::Helper;
our @ISA = qw( Backend::Helper);

use Filesys::SmbClient;

use File::Temp qw/ tempfile tempdir /;

use Fcntl qw(:flock);

use vars qw( $SHARESEP $DOCUMENT_ROOT %CACHE %SMBCLIENT);

$SHARESEP =  $main::SMB{sharesep} || '~';
$DOCUMENT_ROOT = $main::DOCUMENT_ROOT || '/';

sub new {
	my $this = shift;
	my $class = ref($this) || $this;
	my $self = { };
	bless $self, $class;
	$self->initialize();
	return $self;
}
sub initialize() {
	my $self = shift;
	## backup credential cache
	if ($ENV{KRB5CCNAME} && !exists $ENV{WEBDAVISWRAPPED} ) {
		if ($ENV{KRB5CCNAME}=~/^FILE:(.*)$/) {
			my $oldfilename = $1;
			my $newfilename = "/tmp/krb5cc_webdavcgi_$ENV{REMOTE_USER}";
			my ($in, $out);
			if ($oldfilename ne $newfilename && open($in, "<$oldfilename") && open($out, ">$newfilename") && flock($out, LOCK_EX | LOCK_NB) ) {
				#print STDERR "Backend::SMB::initialize: copy $oldfilename to $newfilename\n";
				binmode $in;
				binmode $out;
				while (read($in, my $buffer, $main::BUFSIZE || 1048576)) {
					print $out $buffer;
				}
				close($in);
				flock($out, LOCK_UN);
				close($out);
			} else {
				warn("Cannot read ticket file (don't use a setuid/setgid wrapper):" . (-r $oldfilename)) if ($oldfilename ne $newfilename);
			}
		}
	}
}
sub getSmbClient {
	my ($self) = @_;
	my $rmuser = $ENV{REMOTE_USER} || $ENV{REDIRECT_REMOTE_USER};

	$ENV{KRB5CCNAME} = "FILE:/tmp/krb5cc_webdavcgi_$rmuser" if -e "/tmp/krb5cc_webdavcgi_$rmuser";
	return $SMBCLIENT{$rmuser} if exists $SMBCLIENT{$rmuser};
	return $SMBCLIENT{$rmuser} = new Filesys::SmbClient(username=> $ENV{SMBUSER}, password=> $ENV{SMBPASSWORD}, workgroup=> $ENV{SMBWORKGROUP}) if exists $ENV{SMBUSER} && exists $ENV{SMBPASSWORD} && exists $ENV{SMBWORKGROUP};
	return $SMBCLIENT{$rmuser} = new Filesys::SmbClient(username=> &_getFullUsername(), flags=>Filesys::SmbClient::SMB_CTX_FLAG_USE_KERBEROS);
}
sub finalize {
	%CACHE = ();
	return 1;
}
sub readDir {
	my ($self, $base, $limit, $filter) = @_;

	my @files;

	return $self->_getCacheEntry('readDir:list',$base) if $self->_existsCacheEntry('readDir:list',$base);

	$base .=  '/' if $base !~ /\/$/;
	if (_isRoot($base)) {
		my $dom = $main::SMB{domains}{_getUserDomain()};
		foreach my $fserver (keys %{$$dom{fileserver}}) {
			if (exists $$dom{fileserver}{$fserver}{usershares} && exists $$dom{fileserver}{$fserver}{usershares}{_getUsername()}) {
				push @files, split(/, /, $fserver.$SHARESEP.join(", $fserver$SHARESEP",@{$$dom{fileserver}{$fserver}{usershares}{_getUsername()}}));
			} elsif (exists $$dom{fileserver}{$fserver}{shares}) {
				my $scounter=-1;
				foreach my $share ( @{ $$dom{fileserver}{$fserver}{shares} } ) {
					$scounter++;
					my $shareidx = undef;
					my $path = $fserver . $SHARESEP . $share;
					if ($path =~ s/:?(\/.*)$//) {
						$shareidx = $scounter;
						$path .= $SHARESEP . $shareidx;
					}
					push @files, $path;
				}
				#push @files, split(/, /, $fserver.$SHARESEP.join(", $fserver$SHARESEP",@{$$dom{fileserver}{$fserver}{shares}}) );
			} elsif (my $dir = $self->getSmbClient()->opendir("smb://$fserver/")) {
				my $sfilter = _getShareFilter($$dom{fileserver}{$fserver}, _getShareFilter($dom, _getShareFilter(\%main::SMB)));
				while (my $f = $self->getSmbClient()->readdir_struct($dir)) {
					$self->_setCacheEntry('readDir',"$DOCUMENT_ROOT$fserver$SHARESEP$$f[1]", { type=>$$f[0], comment=>$$f[2] });
					push @files, "$fserver$SHARESEP$$f[1]" if $$f[0] == $self->getSmbClient()->SMBC_FILE_SHARE && (!defined $sfilter || $$f[1]!~/$sfilter/);
				}
				$self->getSmbClient()->closedir($dir);
			} else {
				warn("Cannot open dir smb://$fserver/: $!");
			}
		}

	} elsif ((my $url = $self->_getSmbURL($base)) ne $base) {
		if (my $dir = $self->getSmbClient()->opendir($url)) {
			while (my $f = $self->getSmbClient()->readdir_struct($dir)) {
				last if defined $limit && $#files>=$limit;
				next if $self->filter($filter, $base, $$f[1]); 
				$self->_setCacheEntry('readDir',"$base$$f[1]", { type=>$$f[0], comment=>$$f[2] });
				push @files, $$f[1]; 
			}
			$self->getSmbClient()->closedir($dir);
		} else {
			warn("Cannot open dir $url: $!\nKRB5CCNAME=$ENV{KRB5CCNAME}");
		}
	}
	$self->_setCacheEntry('readDir:list',$base,\@files);
	return \@files;
}
sub _getShareFilter {
	my ($data,$filter) = @_;
	my $fh = $$data{sharefilter};
	$fh = $$data{usersharefilter}{_getUsername()} || $$data{usersharefilter}{_getFullUsername()} || $fh if exists $$data{usersharefilter};
	$filter = $fh ? '('.join('|',@{$fh}).')' : $filter;
	return $filter;
}

sub isFile {
	my ($self, $file) = @_;
	return !_isRoot($file) && !_isShare($file) && $self->_getType($file) == $self->getSmbClient()->SMBC_FILE;
}
sub isDir {
	my ($self, $file) = @_;
	return $self->_existsCacheEntry('isDir', $file) 
			?  $self->_getCacheEntry('isDir', $file) 
			: $self->_setCacheEntry('isDir', $file, _isRoot($file) || _isShare($file) || $self->_getType($file) == $self->getSmbClient()->SMBC_DIR);
}
sub isLink {
	my ($self, $file) = @_;
	return $self->_existsCacheEntry('isLink', $file) 
			?  $self->_getCacheEntry('isLink', $file) 
			: $self->_setCacheEntry('isLink', $file, $self->_getType($file) == $self->getSmbClient()->SMBC_LINK);
	return 0;
}

sub isEmpty {
	my ($self, $file) = @_;
	if (my @stat = $self->stat($file)) {
		return $stat[7] == 0;
	}
	return 1;
}
sub stat {
	my ($self, $file) = @_;

	return @{$self->_getCacheEntry('stat',$file)} if $self->_existsCacheEntry('stat',$file);

	my @stat;
	my $time = time();
	if (_isRoot($file) || _isShare($file)) {
		@stat = (0,0,0755,0,0,0,0,0,$time,$time,$time,0,0);
	} else {
		if ($file=~/^\Q$DOCUMENT_ROOT\E[^\Q$SHARESEP\E]+\Q$SHARESEP\E.*$/) {
			@stat = $self->getSmbClient()->stat($self->_getSmbURL($file));
			if ($#stat>0) {
				my ( @a ) = splice(@stat,8,2);
				push @stat, @a;
				#$stat[2]=0755;
			} else {
				@stat = CORE::lstat($file);
			}
		} else {
			@stat = CORE::lstat($file);
		}
	}
	$self->_setCacheEntry('stat', $file, \@stat) if @stat;
	return @stat;
}
sub lstat {
	my ($self, $file) = @_;
	return $self->stat($file);
}

sub copy {
	my ($self, $src, $dst) = @_;
	if ( (my $srcfh=$self->getSmbClient()->open('<'.$self->_getSmbURL($src))) && (my $dstfh=$self->getSmbClient()->open('>'.$self->_getSmbURL($dst), 07777 ^ $main::UMASK))) {
		while (my $buffer = $self->getSmbClient()->read($srcfh, $main::BUFSIZE || 1048576)) {
			$self->getSmbClient()->write($dstfh, $buffer);
		}
		$self->getSmbClient()->close($srcfh);
		$self->getSmbClient()->close($dstfh);
		$self->finalize();
		return 1;
	} 
	return 0;
}
sub printFile {
	my ($self, $file, $fh) = @_;

	$fh = \*STDOUT unless defined $fh;
	if (my $rd = $self->getSmbClient()->open($self->_getSmbURL($file))) {
		while (my $buffer = $self->getSmbClient()->read($rd, $main::BUFSIZE || 1048576)) {
			print $fh $buffer;
		}
		$self->getSmbClient()->close($rd);
		return 1;
	}
	return 0;
}
sub saveStream {
	my ($self, $path, $fh) = @_;
	if (my $rd = $self->getSmbClient()->open(">".$self->_getSmbURL($path))) {
		while (read($fh, my $buffer, $main::BUFSIZE || 1048576)>0) {
			$self->getSmbClient()->write($rd, $buffer);
		}
		$self->getSmbClient()->close($rd);
		$self->finalize();
		return 1;
	}
	return 0;
}
sub saveData {
	#my ($self, $path, $data, $append) = @_;
	if (my $rd = $_[0]->getSmbClient()->open('>'.($_[3]? '>':'').$_[0]->_getSmbURL($_[1]))) {
		$_[0]->getSmbClient()->write($rd, $_[2]);
		$_[0]->getSmbClient()->close($rd);
		$_[0]->finalize();
		return 1;
	}
	return 0;
}
sub getLocalFilename {
	my ($self, $file) = @_;
	if ($self->exists($file)) {
		$file=~/(\.[^\.]+)$/;
		my $suffix = $1;
		my ($fh, $filename) = tempfile(TEMPLATE=>'/tmp/webdavcgiXXXXX', CLEANUP=>1, SUFFIX=>$suffix);
		$self->printFile($file, $fh);
		return $filename;
	}
	return $file;
}
sub getFileContent {
	my $content;
	if (my $fh = $_[0]->getSmbClient()->open("<".$_[0]->_getSmbURL($_[1]))) {
		$content = "";
		while (my $buffer = $_[0]->getSmbClient()->read($fh, $main::BUFSIZE || 1048576))  {
			$content.=$buffer;
		}
		$_[0]->getSmbClient()->close($fh);
	}
	return $content;
}
sub isReadable {
	my ($self, $file) = @_;
	return $self->_existsCacheEntry('isReadable', $file) 
			? $self->_getCacheEntry('isReadable',$file) 
			: $self->_setCacheEntry('isReadable',$file,_isRoot($file) || _isShare($file) || $self->exists($file));
}
sub isWriteable {
	my ($self, $file) = @_;
	return !_isRoot($file) && $self->exists($file);
}
sub isExecutable {
	my ($self, $file) = @_;
	return _isRoot($file) || _isShare($file) || $self->isDir($file);
}
sub exists {
	my ($self, $file) = @_;
	return 1 if _isRoot($file) || _isShare($file) || $self->_existsCacheEntry('readDir', $file);
	my @stat = $self->stat($file);
	return $#stat > 0;
}

sub mkcol {
	my ($self, $file) = @_;
	return $self->getSmbClient()->mkdir($self->_getSmbURL($file),$main::UMASK) && $self->finalize();
}
sub unlinkFile {
	my ($self, $file) = @_;
	my $ret = $self->isDir($file) ? $self->getSmbClient()->rmdir_recurse($self->_getSmbURL($file)) : $self->getSmbClient()->unlink($self->_getSmbURL($file));
	warn("Could not delete $file: $!") if (!$ret);
	$self->finalize() if $ret;
	return $ret;
}
sub deltree {
	my ($self, $path) = @_;
	return $self->unlinkFile($path);
}
sub rename {
	my ($self, $on, $nn) = @_;
	return $self->getSmbClient()->rename($self->_getSmbURL($on), $self->_getSmbURL($nn)) && $self->finalize();
}
sub resolve {
        my ($self, $fn) = @_;
        $fn=~s/([^\/]*)\/\.\.(\/?.*)/$1/;
        $fn=~s/(.+)\/$/$1/;
        $fn=~s/\/\//\//g;
        return $fn;
}
sub getParent {
	my ($self, $file) = @_;
	return $self->dirname($file);
}
sub getDisplayName {
	my ($self, $file) = @_;
	my $name;
	if (_isShare($file)) {
		my ($server, $share, $path, $shareidx) = _getPathInfo($file);
		my $fs = $main::SMB{domains}{_getUserDomain()}{fileserver}{$server};
		my $initdir = undef;
		if  (defined $shareidx && $$fs{shares}[$shareidx]=~/:?(\/.*)/) {
			$initdir=$1;
		}
		if (defined $initdir && exists $$fs{sharealiases}{"$share:$initdir"}) {
			$name = $$fs{sharealiases}{"$share:$initdir"};
		} elsif (defined $initdir && exists $$fs{sharealiases}{"$share$initdir"}) {
			$name = $$fs{sharealiases}{"$share$initdir"};
		} elsif (exists $$fs{sharealiases}{$share}) {
			$name = $$fs{sharealiases}{$share};
		} elsif (exists $$fs{sharealiases}{_USERNAME_} && $share eq _getUsername()) {
			$name = $$fs{sharealiases}{_USERNAME_};
		} else {
			$name = $self->basename($file);
			my $comment = $self->_existsCacheEntry('readDir',$file) && exists ${$self->_getCacheEntry('readDir',$file)}{comment} ? ${$self->_getCacheEntry('readDir',$file)}{comment} : '';
			$name = $name." ( ".${$self->_getCacheEntry('readDir',$file)}{comment}.")" if $comment ne "";
			$name.="/";
		}
	}
	$name = $self->basename($file) . (!$self->_existsCacheEntry('readDir',$file) || $self->isDir($file) ? '/':'') unless $name || $self->basename($file) eq '/';
	return $name ? $name :  $file;
}

sub _getAllShareAliases {
	my ($domain) = @_;
	my @aliases;
	foreach my $server ( keys %{$$main::SMB{domains}{$domain}{sharealiases}}) {
		push @aliases, keys %{$server};
	}
	return \@aliases;
}
sub _getFullUsername {
	return $ENV{REMOTE_USER} =~ /\@/ ? $ENV{REMOTE_USER} : $ENV{REMOTE_USER} . '@' . _getUserDomain();
}
sub _getUsername {
	$ENV{REMOTE_USER} =~ /^([^\@]+)/;
	return $1;
}
sub _getUserDomain {
	my $domain;
	if ($ENV{REMOTE_USER} =~ /\@(.*)$/ ) {
		$domain = $1;
	} else {
		$domain = $main::SMB{defaultdomain};
	}
	return $domain ? $domain : undef;
}

sub _isRoot {
	return $_[0]  eq $DOCUMENT_ROOT;
}
sub _isShare {
	return $_[0] =~ /^\Q$DOCUMENT_ROOT\E[^\Q$SHARESEP\E]+\Q$SHARESEP\E[^\/]+\/?$/;

}
sub S_ISLNK { return ($_[0] & 0120000) == 0120000; }
sub S_ISDIR { return ($_[0] & 0040000) == 0040000; }
sub S_ISFILE { return ($_[0] & 0100000) == 0100000; }
sub _getType {
	my ($self, $file) = @_;
	if (!$self->_existsCacheEntry('readDir',$file)) {
		my @stat = $self->stat($file);
		return 0 if scalar(@stat)==0;
		$self->_setCacheEntry('readDir', $file, { type=>S_ISLNK($stat[2]) ? $self->getSmbClient()->SMBC_LINK : S_ISDIR($stat[2]) ? $self->getSmbClient()->SMBC_DIR : $self->getSmbClient()->SMBC_FILE , comment=>'' } );
	}
	return ${$self->_getCacheEntry('readDir',$file)}{type} || 0;
}
sub _getCacheEntry {
	my ($self, $id, $file) = @_;
	$file=~s/\/$//;
	return $CACHE{$self}{$file}{$id};
}
sub _setCacheEntry {
	my ($self, $id, $file, $value) = @_;
	$file=~s/\/$//;
	return $CACHE{$self}{$file}{$id} = $value;
}
sub _existsCacheEntry {
	my ($self, $id, $file) = @_;
	$file=~s/\/$//;
	return exists $CACHE{$self}{$file} && exists $CACHE{$self}{$file}{$id} && defined $CACHE{$self}{$file}{$id};
}
sub _getPathInfo {
	my ($file) = @_;
	my ($server, $share, $path, $shareidx) = ( '', '', $file, undef);
	if ($file=~/^\Q$DOCUMENT_ROOT\E([^\Q$SHARESEP\E]+)\Q$SHARESEP\E([^\/\Q$SHARESEP\E]+)(\Q$SHARESEP\E(\d+))?(.*)$/) {
		($server, $share, $path, $shareidx) = ($1, $2, $5, $4);
	}
	return ($server, $share, $path, $shareidx);
}

sub _getSmbURL {
	my ($self, $file) = @_;
	my $url = $file;
	my $fs = $main::SMB{domains}{_getUserDomain()}{fileserver};
	if ($file =~ /^\Q$DOCUMENT_ROOT\E([^\Q$SHARESEP\E]+)\Q$SHARESEP\E([^\/\Q$SHARESEP\E]*)(\Q$SHARESEP\E(\d+))?(\/.*)?$/) {
		my ($server, $share, $initdir, $path, $shareidx) = ($1, $2, $$fs{$1}{initdir}{$2}, $5, $4);

		if (defined $shareidx && $$fs{$server}{shares}[$shareidx] =~ /:?(\/.*)/) {
			$initdir = $1;
		}
		
		$url ="smb://$server/$share";
		$url .= $initdir if defined $initdir;
		$path=~s/[\*\?<>\|:\"\\]/_/g if defined $path; # fix strange characters in filenames or pathnames
		$url .= $path;
	}
	return $url;
}
sub changeFilePermissions {
	return 0;
}
sub hasSetUidBit { return 0; }
sub hasSetGidBit { return 0; }
sub changeMod { return 0; }
sub isBlockDevice { return 0; }
sub isCharDevice { return 0; }
sub createSymLink { return 0; }
sub getLinkSrc { $!='not supported'; return undef; }
sub hasStickyBit { return 0; }
sub getQuota { 
	my ($server,$share,$path,$shareidx) = _getPathInfo($_[1]);
	$server=~s/'/\\'/g if $server;
	$share=~s/'/\\'/g if $share;
	$path=~s/'/\\'/g if $path;
	$path='/' unless $path;
	my $fs = $main::SMB{domains}{_getUserDomain()}{fileserver}{$server};
	my $initdir = $$fs{initdir}{$share};
	if (defined $shareidx && $$fs{shares}[$shareidx] =~ /:?(\/.*)/) {
		$initdir = $1;
	}
	$path = "$initdir/$path" if defined $initdir;
	my $smbclient =  "/usr/bin/smbclient -k '//$server/$share' -D '$path' -c du";
	$smbclient = "/usr/bin/smbclient '//$server/$share' '$ENV{SMBPASSWORD}' -U '$ENV{SMBUSER}' -W '$ENV{SMBWORKGROUP}' -D '$path' -c du" if exists $ENV{SMBWORKGROUP} && exists $ENV{SMBUSER} && exists $ENV{SMBPASSWORD};
	if ($server && open(my $c, "$smbclient 2>/dev/null |" )) {
		my @l= <$c>;
		close($c);
		if (@l && $l[1] =~ /^\D+(\d+)\D+(\d+)\D+(\d+)/) {
			my ($b,$s,$a) = ($1,$2,$3);
			return ($b*$s, ($b-$a)*$s);
		}
	}
	return (0,0); 
}
1;
