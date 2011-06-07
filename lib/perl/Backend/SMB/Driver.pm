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

use Backend::FS::Driver;

use POSIX;
use Filesys::SmbClient;

use File::Basename;
use File::Temp qw/ tempfile tempdir /;

use Archive::Zip;


our @ISA = qw( Backend::FS::Driver );

our %CACHE;

my $SHARESEP =  ':';
my $DOCUMENT_ROOT = $main::DOCUMENT_ROOT || '/';

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
	if ($ENV{KRB5CCNAME}) {
		if ($ENV{KRB5CCNAME}=~/^FILE:(.*)$/) {
			my $oldfilename = $1;
			my $newfilename = "/tmp/krb5cc_webdavcgi_$ENV{REMOTE_USER}";
			if ($oldfilename ne $newfilename && open(my $in, "<$oldfilename") && open(my $out, ">$newfilename")) {
				binmode $in;
				binmode $out;
				while (read($in, my $buffer, $main::BUFSIZE || 1048576)) {
					print $out $buffer;
				}
				close($in);
				close($out);
			} else {
				warn("Cannot read ticket file (don't use a setuid/setgid wrapper):" . (-r $oldfilename)) if ($oldfilename ne $newfilename);
			}
		}
	}
	$ENV{KRB5CCNAME} = "FILE:/tmp/krb5cc_webdavcgi_$ENV{REMOTE_USER}" if -e "/tmp/krb5cc_webdavcgi_$ENV{REMOTE_USER}";

	$$self{smb} = new Filesys::SmbClient(username=> _getFullUsername(), flags=>Filesys::SmbClient::SMB_CTX_FLAG_USE_KERBEROS);
}
sub readDir {
	my ($self, $base, $limit, $filter) = @_;

	my @files;

	main::debug("readDir($base)");

	return $self->_getCacheEntry('readDir:list',$base) if $self->_getCacheEntry('readDir:list',$base);

	$base .=  '/' if $base !~ /\/$/;
	if (_isRoot($base)) {
		main::debug("readDir: list shares for "._getFullUsername());
		my $dom = $main::SMB{domains}{_getUserDomain()};
		foreach my $fserver (keys %{$$dom{fileserver}}) {
			if (exists $$dom{fileserver}{$fserver}{usershares} && exists $$dom{fileserver}{$fserver}{usershares}{_getUsername()}) {
				push @files, split(/, /,$fserver.$SHARESEP.join(", $fserver.$SHARESEP",@{$$dom{fileserver}{$fserver}{usershares}{_getUsername()}}));
			} elsif (exists $$dom{fileserver}{$fserver}{shares}) {
				push @files, split(/, /,$fserver.$SHARESEP.join(", $fserver.$SHARESEP",@{$$dom{fileserver}{$fserver}{shares}}));
			} elsif (my $dir = $$self{smb}->opendir("smb://$fserver/")) {
				my $sfilter = _getShareFilter($$dom{fileserver}{$fserver}, _getShareFilter($dom, _getShareFilter(\%main::SMB)));
				while (my $f = $$self{smb}->readdir_struct($dir)) {
					$self->_setCacheEntry('readDir',"$DOCUMENT_ROOT$fserver$SHARESEP$$f[1]", { type=>$$f[0], comment=>$$f[2] });
					push @files, "$fserver$SHARESEP$$f[1]" if $$f[0] == $$self{smb}->SMBC_FILE_SHARE && (!defined $sfilter || $$f[1]!~/$sfilter/);
				}
				$$self{smb}->closedir($dir);
			}
		}

	} elsif ((my $url = _getSmbURL($base)) ne $base) {
		if (my $dir = $$self{smb}->opendir($url)) {
			while (my $f = $$self{smb}->readdir_struct($dir)) {
				last if defined $limit && $#files>=$limit;
				next if $self->filter($filter, $base, $$f[1]); 
				$self->_setCacheEntry('readDir',"$base$$f[1]", { type=>$$f[0], comment=>$$f[2] });
				push @files, $$f[1]; 
			}
			$$self{smb}->closedir($dir);
		} else {
			main::debug("readDir: nothing to read from $url");
		}
	} else {
		main::debug("readDir:: unkown path $base: _getSmbURL="._getSmbURL($base));
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
	return !_isRoot($file) && !_isShare($file) && _getType($self, $file) == $$self{smb}->SMBC_FILE;
}
sub isDir {
	my ($self, $file) = @_;
	return _isRoot($file) || _isShare($file) || _getType($self, $file) == $$self{smb}->SMBC_DIR;
}
sub isLink {
	my ($self, $file) = @_;
	return !_isRoot($file) && !_isShare($file) &&  _getType($self, $file) == $$self{smb}->SMBC_LINK;
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

	return @{$self->_getCacheEntry('stat',$file)} if $self->_getCacheEntry('stat',$file);

	my @stat;
	my $time = time();
	if (_isRoot($file)) {
		@stat = (0,0,0755,0,0,0,0,0,$time,$time,$time,0,0);
	} else {
		if ($file=~/^\Q$DOCUMENT_ROOT\E[^\Q$SHARESEP\E]+\Q$SHARESEP\E.*$/) {
			@stat = $$self{smb}->stat(_getSmbURL($file));
			if ($#stat>0) {
				my ( @a ) = splice(@stat,8,2);
				push @stat, @a;
				#$stat[2]=0755;
			} else {
				main::debug("stat: $file does not exists: $!");
				@stat = CORE::lstat($file);
			}
		} else {
			@stat = CORE::lstat($file);
		}
	}
	$self->_setCacheEntry('stat', $file, \@stat) if defined @stat;
	return @stat;
}
sub lstat {
	my ($self, $file) = @_;
	return $self->stat($file);
}

sub copy {
	my ($self, $src, $dst) = @_;
	if ( (my $srcfh=$$self{smb}->open('<'._getSmbURL($src))) && (my $dstfh=$$self{smb}->open('>'._getSmbURL($dst), 07777 ^ $main::UMASK))) {
		while (my $buffer = $$self{smb}->read($srcfh, $main::BUFSIZE || 1048576)) {
			$$self{smb}->write($dstfh, $buffer);
		}
		$$self{smb}->close($srcfh);
		$$self{smb}->close($dstfh);
		return 1;
	} 
	return 0;
}
sub printFile {
	my ($self, $file, $fh) = @_;

	$fh = \*STDOUT unless defined $fh;
	if (my $rd = $$self{smb}->open(_getSmbURL($file))) {
		while (my $buffer = $$self{smb}->read($rd, $main::BUFSIZE || 1048576)) {
			print $fh $buffer;
		}
		$$self{smb}->close($rd);
		return 1;
	}
	return 0;
}
sub saveStream {
	my ($self, $path, $fh) = @_;

	if (my $rd = $$self{smb}->open(">"._getSmbURL($path))) {
		while (read($fh, my $buffer, $main::BUFSIZE || 1048576)>0) {
			$$self{smb}->write($rd, $buffer);
		}
		$$self{smb}->close($rd);
		return 1;
	}
	return 0;
}
sub saveData {
	#my ($self, $path, $data, $append) = @_;
	if (my $rd = $_[0]{smb}->open('>'.($_[3]? '>':'')._getSmbURL($_[1]))) {
		$_[0]{smb}->write($rd, $_[2]);
		$_[0]{smb}->close($rd);
		$_[0]->_removeCacheEntry('readDir',$_[0]->getParent($_[1]));
		$_[0]->_removeCacheEntry('stat',$_[1]);
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
	if (my $fh = $_[0]{smb}->open("<"._getSmbURL($_[1]))) {
		$content = "";
		while (my $buffer = $_[0]{smb}->read($fh, $main::BUFSIZE || 1048576))  {
			$content.=$buffer;
		}
		$_[0]{smb}->close($fh);
	}
	return $content;
}
sub isReadable {
	my ($self, $file) = @_;
	return _isRoot($file) || _isShare($file) || $self->exists($file);
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
	return 1 if _isRoot($file) || _isShare($file);
	my @stat = $self->stat($file);
	return $#stat > 0;
}

sub mkcol {
	my ($self, $file) = @_;
	return $$self{smb}->mkdir(_getSmbURL($file),$main::UMASK);
}
sub unlinkFile {
	my ($self, $file) = @_;
	my $ret = $self->isDir($file) ? $$self{smb}->rmdir_recurse(_getSmbURL($file)) : $$self{smb}->unlink(_getSmbURL($file));
	main::debug("unlinkFile($file) : ret=$ret, $!");
	$self->_removeCacheEntry('readDir', $file) if $ret;
	$self->_removeCacheEntry('stat', $file) if $ret;
	return $ret;
}
sub deltree {
	my ($self, $path) = @_;
	return $self->unlinkFile($path);
}
sub rename {
	my ($self, $on, $nn) = @_;
	return $$self{smb}->rename(_getSmbURL($on), _getSmbURL($nn));
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
	return dirname($file);
}
sub getDisplayName {
	my ($self, $file) = @_;
	my $name;
	if (_isShare($file)) {
		my ($server, $share) = _getPathInfo($file);
		if (exists $main::SMB{domains}{_getUserDomain()}{fileserver}{$server}{sharealiases}{$share}) {
			$name = $main::SMB{domains}{_getUserDomain()}{fileserver}{$server}{sharealiases}{$share};
		} elsif (exists $main::SMB{domains}{_getUserDomain()}{fileserver}{$server}{sharealiases}{_USERNAME_} && $share eq _getUsername()) {
			$name = $main::SMB{domains}{_getUserDomain()}{fileserver}{$server}{sharealiases}{_USERNAME_};
		} else {
			$name = basename($file);
			my $comment = $self->_getCacheEntry('readDir',$file) && exists ${$self->_getCacheEntry('readDir',$file)}{comment} ? ${$self->_getCacheEntry('readDir',$file)}{comment} : '';
			$name = $name." ( ".${$self->_getCacheEntry('readDir',$file)}{comment}.")" if $comment ne "";
			$name.="/";
		}
	}
	$name = basename($file) . ($self->isDir($file) ? '/':'') unless $name || basename($file) eq '/';
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
	return $_[0] =~ /^\Q$DOCUMENT_ROOT\E[^\:\/]+\:[^\/]+\/?$/;
}
sub _getType {
	my ($self, $file) = @_;
	main::debug("_getType($file)");
	my $type;
	if (!$self->_getCacheEntry('readDir',$file)) {
		$self->readDir($self->getParent($file).'/');
	}
	
	$type = ${$self->_getCacheEntry('readDir',$file)}{type} if $self->_getCacheEntry('readDir', $file);
	return $type || 0;
}
sub _getCacheEntry {
	my ($self, $id, $file) = @_;
	return exists $CACHE{$self}{$id} && exists $CACHE{$self}{$id}{_stripTrailingSlash($file)} 
			? $CACHE{$self}{$id}{_stripTrailingSlash($file)} 
			: 0;
}
sub _setCacheEntry {
	my ($self, $id, $file, $value) = @_;
	$CACHE{$self}{$id}{_stripTrailingSlash($file)} = $value;
}
sub _removeCacheEntry {
	my ($self, $id, $file) = @_;
	delete $CACHE{$self}{$id}{_stripTrailingSlash($file)};
}
sub _getPathInfo {
	my ($file) = @_;
	my ($server, $share, $path) = ( '', '', $file);
	if ($file=~/^\Q$DOCUMENT_ROOT\E([^\Q$SHARESEP\E]+)$SHARESEP([^\/]+)(.*)$/) {
		($server, $share, $path) = ($1, $2, $3);

	}
	return ($server, $share, $path);
}

sub _getSmbURL {
	my ($file) = @_;
	my $url = $file;
	if ($file =~ /^\Q$DOCUMENT_ROOT\E([^\Q$SHARESEP\E]+)\Q$SHARESEP\E(.*)$/) {
		$url="smb://$1/$2";
	}
	return $url;
}
sub _stripTrailingSlash {
	my ($file ) = @_;
	$file=~s/\/$//;
	return $file;
}
sub changeFilePermissions {
	return 0;
}
sub _copytoshare {
	my ($self, $src, $dst) =@_;
	my $ret = 0;
	if (opendir(my $dir, $src)) {
		$ret = 1;
		while (my $file = readdir($dir)) {
			next if $file=~/^\.{1,2}$/;
			my $nsrc = "$src$file";
			my $ndst = "$dst$file";
			if (-d $nsrc) {
				$self->mkcol($ndst);
				$ret &= $self->_copytoshare("$nsrc/", "$ndst/");
			} else {
				if (open(my $fh, "<$nsrc")) {
					$ret &= $self->saveStream($ndst, $fh);
					close($fh);
				} else {
					$ret = 0;
				}
			}
		}
		closedir($dir);
	}
	return $ret;
}
sub uncompressArchive {
	my ($self, $zipfile, $destination) = @_;
	my $tempdir = tempdir(CLEANUP => 1);
	return $self->SUPER::uncompressArchive($self->getLocalFilename($zipfile), "$tempdir/") && $self->_copytoshare("$tempdir/",$destination);
}
sub _copytolocal {
	my ($self, $destdir, @files) = @_;
	foreach my $file (@files) {
		my $ndestdir=$destdir.basename($file);
		if ($self->isDir($file)) {
			$file.='/' if $file!~/\/$/;
			if ($self->SUPER::mkcol($ndestdir)) {
				foreach my $nfile (@{$self->readDir($file)}) {
					next if $nfile =~ /^\.{1,2}$/;
					$self->_copytolocal("$ndestdir/", "$file$nfile");
				}
			}
		} else {
			if (open(my $fh, ">$ndestdir")) {
				$self->printFile($file, $fh);
				close($fh);
			}
		}
		my @stat = $self->stat($file);
		utime($stat[8],$stat[9],$ndestdir);
	}
}
sub compressFiles {
	my ($self, $desthandle, $basepath, @files) = @_;

	my $tempdir = tempdir(CLEANUP => 1); 
	foreach my $file (@files) {
		$self->_copytolocal("$tempdir/", "$basepath$file");
	}
	$self->SUPER::compressFiles($desthandle, "$tempdir/", @{$self->SUPER::readDir("$tempdir/")});
}
sub getLinkSrc { return $_[1]; }
sub hasSetUidBit { return 0; }
sub hasSetGidBit { return 0; }
sub changeMod { return 0; }
sub createSymLink { return 0; }
sub isBlockDevice { return 0; }
sub isCharDevice { return 0; }
sub getLinkSrc { $!='not supported'; return undef; }
sub createSymLink { return 0; }
sub hasStickyBit { return 0; }
sub getQuota { 
	my ($server,$share,$path) = _getPathInfo($_[1]);
	$server=~s/'/\\'/g if $server;
	$share=~s/'/\\'/g if $share;
	$path=~s/'/\\'/g if $path;
	$path='/' unless $path;
	if ($server && open(my $c, "/usr/bin/smbclient -k '//$server/$share' -D '$path' -c du 2>/dev/null|")) {
		my @l= <$c>;
		close($c);
		
		$l[1] =~ /^\D+(\d+)\D+(\d+)\D+(\d+)/;
		my ($b,$s,$a) = ($1,$2,$3);
		return ($b*$s, ($b-$a)*$s);
	}
	return (0,0); 
}


1;

