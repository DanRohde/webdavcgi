#!/usr/bin/perl
#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2012 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package Backend::RCS::Driver;

use strict;
#use warnings;

use Backend::Helper;
our @ISA = qw( Backend::Helper );

use Rcs;
use File::Temp qw/ tempfile /;
use vars qw( %CACHE );

sub new {
	my $class = my $self = shift;
	my $self = { BACKEND=> $main::backendmanager->getBackend($main::RCS{backend} || 'FS') };
	CGI::SpeedyCGI->register_cleanup(\&_cleanupCache) if eval{ require CGI::SpeedyCGI } && CGI::SpeedyCGI->i_am_speedy;
	return bless $self, $class;
}
sub _cleanupCache {
	%CACHE = ();
}

sub basename {
	my $self = shift @_;
	return main::getBaseURIFrag($_[0]) if $_[0] =~ /\/\Q$main::RCS{rcsdirname}\E\/\Q$main::RCS{virtualrcsdir}\E\/?/;
	return $$self{BACKEND}->basename(@_);
}
sub dirname {
	my $self = shift @_;
	return main::getParentURI($_[0]) if  $_[0] =~ /\/\Q$main::RCS{rcsdirname}\E\/\Q$main::RCS{virtualrcsdir}\E\/?/;
	return $$self{BACKEND}->dirname(@_);
}

sub exists {
	my $self = shift @_;
	return 1 if ($self->_isVirtual($_[0]));
	return $$self{BACKEND}->exists(@_);
}
sub isDir {
	my $self = shift @_;
	return 1 if ($self->_isVirtualDir($_[0]));
	return 0 if ($self->_isVirtualFile($_[0]));
	return $$self{BACKEND}->isDir(@_);
}
sub isFile {
	my $self = shift @_;
	return 1 if ($self->_isVirtualFile($_[0]));
	return 0 if ($self->_isVirtualDir($_[0]));
	return $$self{BACKEND}->isFile(@_);
}
sub isLink {
	my $self = shift @_;
	return 0 if ($self->_isVirtual($_[0]));
	return $$self{BACKEND}->isLink(@_);
}
sub isBlockDevice {
	my $self = shift @_;
	return 0 if ($self->_isVirtual($_[0]));
	return $$self{BACKEND}->isBlockDevice(@_);
}
sub isCharDevice {
	my $self = shift @_;
	return 0 if ($self->_isVirtual($_[0]));
	return $$self{BACKEND}->isCharDevice(@_);
}
sub isEmpty {
	my $self = shift @_;
	return 0 if ($self->_isVirtual($_[0]));
	return $$self{BACKEND}->isEmpty(@_);
}
sub isReadable {
	my $self = shift @_;
	return 1 if ($self->_isVirtual($_[0]));
	return $$self{BACKEND}->isReadable(@_);
}
sub isWriteable {
	my $self = shift @_;
	return 1 if ($self->_isVirtual($_[0]));
	return $$self{BACKEND}->isWriteable(@_);
}
sub isExecutable {
	my $self = shift @_;
	return 1 if ($self->_isVirtual($_[0]));
	return $$self{BACKEND}->isExecutable(@_);
}
sub getParent {
	my $self = shift @_;
	return $$self{BACKEND}->getParent(@_);
}

sub mkcol {
	my $self = shift @_;
	return 1 if ($self->_isVirtual($_[0]));
	return $$self{BACKEND}->mkcol(@_);
}
sub unlinkFile {
	my $self = shift @_;
	return 1 if ($self->_isVirtual($_[0]));
	return $$self{BACKEND}->unlinkFile(@_);
}
sub unlinkDir {
	my $self = shift @_;
	return 1 if ($self->_isVirtual($_[0]));
	return $$self{BACKEND}->unlinkDir(@_);
}
sub readDir {
	my ($self, $dirname, $limit, $filter) = @_;
	my $ret;
	if (! ($ret = $self->_readVirtualDir($dirname, $limit, $filter))) {
		$ret = $$self{BACKEND}->readDir($dirname, $limit, $filter);
		push @{$ret} , $main::RCS{virtualrcsdir} 
			unless $self->basename($dirname) ne $main::RCS{rcsdirname} || grep(/\Q$main::RCS{virtualrcsdir}\E/,@{$ret});
	}
	return $ret;
}
sub filter {
	my $self = shift @_;
	return $$self{BACKEND}->filter(@_);
}
sub stat {
	my ($self, $fn) = @_;
	return ( 0,0, 0555, 2, $<, $(, 0,0, time(),time(),time(), 4096,0 )  if ($self->_isVirtualDir($fn));
	if ($self->_isVirtualFile($fn)) {
		return @{$CACHE{$self}{$fn}{stat}} if exists $CACHE{$self}{$fn}{stat};
		my $lf = $self->_saveToLocal($fn);
		my @stat = $CACHE{$self}{$fn}{stat} ? @{ $CACHE{$self}{$fn}{stat} } : CORE::stat($lf);
		unlink $lf;
		return @stat;
	}
	return $$self{BACKEND}->stat($fn);
}
sub lstat {
	my $self = shift @_;
	return $self->stat(@_) if $self->_isVirtual($_[0]);
	return $$self{BACKEND}->lstat(@_);
}

sub deltree {
	my $self = shift @_;
	return 1 if ($self->_isVirtualDir($_[0]));
	return $$self{BACKEND}->deltree(@_);
}
sub changeFilePermissions {
	my $self = shift @_;
	return 0 if ($self->_isVirtualDir($_[0]));
	return $$self{BACKEND}->changeFilePermissions(@_);
}

sub saveData {
	my ($self, $destination, $data, $append) = @_;
	return 1 if ($self->_isVirtualDir($destination));
	my $ret = 0;
	my ($tmpfh, $localfilename) = tempfile(TEMPLATE=>'/tmp/webdavcgiXXXXX', CLEANUP=>1, SUFFIX=>'tmp');
	$ret = $$self{BACKEND}->printFile($localfilename, $tmpfh) if $append;
	print $tmpfh $data;
	close($tmpfh);

	if ($ret = open($tmpfh, "<$localfilename")) {
		$ret = $self->saveStream($destination, $tmpfh);
		close($tmpfh);
	}
	return $ret;
}

sub saveStream {
	my ($self, $destination, $fh) = @_;

	return 1 if ($self->_isVirtualDir($destination));

	my $ret = 0;

	my $filename = $self->basename($destination);
	my $remotercsfilename = $self->dirname($destination)."/$main::RCS{rcsdirname}/$filename,v";
	$destination=~/(\.[^\.]+)$/;
	my $suffix = $1;
	my ($tmpfh, $localfilename) = tempfile(TEMPLATE=>'/tmp/webdavcgiXXXXX', CLEANUP=>1, SUFFIX=>$suffix);
	my $arcfile = "$localfilename,v";

	my $rcs = $self->_getRcs();
	$rcs->workdir('/tmp');
	$rcs->file($self->basename($localfilename));
	$rcs->rcsdir($self->dirname($arcfile));
	$rcs->arcfile($self->basename($arcfile));
	if ($self->exists($destination)) {
		if ($self->exists($remotercsfilename)) {
			if ($ret = open(my $arcfilefh, ">$arcfile")) {
				$$self{BACKEND}->printFile($remotercsfilename, $arcfilefh);
				close($arcfilefh);
			} else {
				warn("Cannot open $arcfile for writing: $!");
			}
			unlink($localfilename);
		} else {
			if ($ret = open(my $lfh, ">$localfilename")) {
				$$self{BACKEND}->printFile($destination, $lfh);
				close($lfh);
			}
			$rcs->ci();
		}
		$rcs->co("-l");
	}

	if ($ret = open(my $lfh, ">$localfilename")) {
		binmode($lfh);
		binmode($fh);
		while (read($fh, my $buffer,$main::BUFSIZE || 1048576)>0) {
			print $lfh $buffer;
		}
		close($lfh);
		
		$rcs->ci();
		$rcs->co();


		if (($ret = open($lfh,"<$localfilename")) && ($ret = $$self{BACKEND}->saveStream($destination, $lfh))) {
			close($lfh);
			$ret = $$self{BACKEND}->mkcol($self->dirname($remotercsfilename)) if !$self->exists($self->dirname($remotercsfilename));
			if ($ret = open($lfh, "<$arcfile")) {
				$$self{BACKEND}->saveStream($remotercsfilename, $lfh);
				close($lfh);
			}
		}

		unlink($arcfile);
		unlink($localfilename);
	}
	return $ret;
}


sub uncompressArchive {
	my $self = shift @_;
	return 0 if ($self->_isVirtual($_[0]));
	return $$self{BACKEND}->uncompressArchive(@_);
}
sub changeMod {
	my $self = shift @_;
	return 0 if ($self->_isVirtual($_[0]));
	return $$self{BACKEND}->changeMod(@_);
}
sub createSymLink {
	my $self = shift @_;
	return 0 if ($self->_isVirtual($_[0]));
	return $$self{BACKEND}->createSymLink(@_);
}
sub getLinkSrc {
	my $self = shift @_;
	return $_[0] if ($self->_isVirtual($_[0]));
	return $$self{BACKEND}->getLinkSrc(@_);
}
sub resolve {
	my $self = shift @_;
	return $_[1] if $self->_isVirtual($_[1]);
	return $$self{BACKEND}->resolve(@_);
}

sub getFileContent {
	my $self = shift @_;
	if ($self->_isVirtualFile($_[0])) {
		my $lf = $self->_saveToLocal($_[0]);
		if (open(my $lfh, "<$lf")) {
			my @content = <$lfh>;
			close($lfh);
			return join("",@content);
		}
		return "";
	} 
	return $$self{BACKEND}->getFileContent(@_);
}
sub hasSetUidBit {
	my $self = shift @_;
	return 0 if ($self->_isVirtual($_[0]));
	return $$self{BACKEND}->hasSetUidBit(@_);
}
sub hasSetGidBit {
	my $self = shift @_;
	return 0 if ($self->_isVirtual($_[0]));
	return $$self{BACKEND}->hasSetGidBit(@_);
}
sub hasStickyBit {
	my $self = shift @_;
	return 0 if ($self->_isVirtual($_[0]));
	return $$self{BACKEND}->hasStickyBit(@_);
}
sub getLocalFilename {
	my $self = shift @_;
	return $self->_saveToLocal($_[0]) if $self->_isVirtualFile($_[0]);
	return $$self{BACKEND}->getLocalFilename(@_);
}

sub printFile {
	my($self,$fn,$fh) = @_;
	if ($self->_isVirtualFile($fn)) {
		$fh=\*STDOUT unless defined $fh;

		my $dn = $self->basename($self->dirname($fn));
		my ($file, $rcsfile) = $self->_getRcsFile($fn);

		my $rcs = $self->_getRcs();
		$rcs->workdir('/tmp');
		$rcs->rcsdir($self->dirname($rcsfile));
		$rcs->file($self->basename($file));
		if ($fn=~/log.txt$/) {
			my $filebn = $self->basename($file);
			my $rlog = join("",$rcs->rlog('-zLT'));
			$rlog=~s/\Q$rcsfile\E/$dn,v/mg;
			$rlog=~s/\Q$filebn\E/$dn/mg;
			print $fh $rlog;
		} elsif ($fn=~/diff.txt$/) {
			my $firstrev;
			foreach my $rev ($rcs->revisions()) {
				if (!defined $firstrev) {
					$firstrev = $rev;
					next;
				}
				eval { 
					my $diff = join('',$rcs->rcsdiff('-kkv','-q','-u',"-r$rev", "-r$firstrev",'-zLT'));
					$diff=~s/^(\+\+\+|\-\-\-) \Q$file\E/$1 $dn/mg;
					print $fh $diff;
				};
				$firstrev = $rev;
			}
		} else {
			$fn=~/\/(\d+\.\d+)\/[^\/]+$/;
			my $rev = $1;
			if ($rcs->co("-r$rev","-M$rev") && open(my $lfh, "<$file")) {
				my @stat = CORE::stat($lfh);
				$CACHE{$self}{$fn}{stat}=\@stat;
				binmode($fh);
				binmode($lfh);
				print $fh $_ while (<$lfh>);
				close($lfh);
			} else {
				print $fh "NOT IMPLEMENTED\n";
			}
			unlink($file);
		}
		unlink($rcsfile);
	} else {
		$$self{BACKEND}->printFile($fn,$fh);
	}
}
sub getDisplayName {
	my $self = shift @_;
	return main::getBaseURIFrag($_[0]).'/' if $self->_isVirtualDir($_[0]);
	return main::getBaseURIFrag($_[0]) if $self->_isVirtualFile($_[0]);
	return $$self{BACKEND}->getDisplayName(@_);
}
sub rename {
	my $self = shift @_;
	return 1 if ($self->_isVirtual($_[0]) || $self->_isVirtual($_[1]));
	return $$self{BACKEND}->rename(@_);
}
sub getQuota {
	my $self = shift @_;
	if ($self->_isVirtual($_[0])) {
		my $realpath = $_[0];
		$realpath=~s/\/$main::RCS{rcsdirname}(\/$main::RCS{virtualrcsdir}.*)?$//;
		return $$self{BACKEND}->getQuota($realpath);
	}
	return $$self{BACKEND}->getQuota(@_);
}
sub copy {
	my $self = shift @_;
	return 1 if ($self->_isVirtual($_[0]) || $self->_isVirtual($_[1]));
	return $$self{BACKEND}->copy(@_);
}

sub _readVirtualDir {
	my ($self, $dirname, $limit, $filter) = @_;
	my $ret;
	return $ret unless $self->_isVirtualDir($dirname);

	my $basename = $self->basename($dirname);
	my $parent = $self->dirname($dirname);
	my $parentbasename = $self->basename($parent);

	if ($self->_isRevisionDir($dirname)) {
		push  @{$ret}, $parentbasename;

	} elsif ($self->_isRevisionsDir($dirname)) {
		my $rcsfilename=$self->dirname($parent)."/$basename,v";
		my ($tmpfh, $localfilename) = tempfile(TEMPLATE=>'/tmp/webdavcgiXXXXX', CLEANUP=>1, SUFFIX=>",v");
		$$self{BACKEND}->printFile($rcsfilename, $tmpfh);
		close($tmpfh);

		my $rcs = $self->_getRcs();
		$rcs->workdir($self->dirname($localfilename));
		$rcs->rcsdir($self->dirname($localfilename));
		my $fn = $self->basename($localfilename);
		$fn=~s/,v$//;
		$rcs->file($fn);
		push @{$ret}, $rcs->revisions(), 'diff.txt', 'log.txt';
		
	} elsif ($self->_isVirtualRcsDir($dirname)) {
		my $fl = $$self{BACKEND}->readDir($parent, $limit, $filter);
		foreach my $f (@{$fl}) {
			$f=~s/,v$//;
			push @{$ret}, $f;
		}
	}
	return $ret;

}

sub _saveToLocal {
	my ($self, $fn, $suffix) = @_; 
	if (!$suffix && $fn=~/(\.[^\.]+)$/) { $suffix = $1; }
	my ($tmpfh, $vfile) = tempfile(TEMPLATE=>'/tmp/webdavcgiXXXXX', CLEANUP=>1, SUFFIX=>$suffix || '.tmp');
	$self->printFile($fn, $tmpfh);
	close($tmpfh);
	return $vfile;
}

sub _getRcsFile {
	my ($self, $vpath) = @_;

	$vpath=~/^(.*?\/\Q$main::RCS{rcsdirname}\E\/)\Q$main::RCS{virtualrcsdir}\E\/([^\/]+)/;
	my ($fn) = ("$1$2,v");

	my $rcsfile = $self->_saveToLocal($fn, ',v');
	my $file = $rcsfile;
	$file=~s/,v$//;

	return ($file, $rcsfile);
}
sub _isVirtual {
	my ($self, $fn) = @_;
	return $self->_isVirtualFile($fn) || $self->_isVirtualDir($fn);
}
	
sub _isVirtualFile {
	my ($self, $fn) = @_;
	return ($self->_isRevisionsDir($self->dirname($fn)) && $self->basename($fn) =~ /^(log|diff).txt$/) || $self->_isRevisionDir($self->dirname($fn));
}
sub _isVirtualDir {
	my ($self,$fn) = @_;
	return !$$self{BACKEND}->exists($fn)  && ( $self->_isVirtualRcsDir($fn) || $self->_isRevisionsDir($fn) || $self->_isRevisionDir($fn));
}
sub _isRcsDir {
	my ($self, $fn) = @_;
	return $fn =~ /\/\Q$main::RCS{rcsdirname}\E\/?$/;
}
sub _isVirtualRcsDir {
	my ($self, $fn) = @_;
	return $fn =~ /\/\Q$main::RCS{rcsdirname}\E\/\Q$main::RCS{virtualrcsdir}\E\/?$/;
}
sub _isRevisionsDir {
	my ($self, $fn) = @_;
	return $fn =~ /\/\Q$main::RCS{rcsdirname}\E\/\Q$main::RCS{virtualrcsdir}\E\/[^\/]+\/?$/;
}
sub _isRevisionDir {
	my ($self, $fn) = @_;
	return $fn =~ /\/\Q$main::RCS{rcsdirname}\E\/\Q$main::RCS{virtualrcsdir}\E\/[^\/]+\/\d+\.\d+\/?$/;
}
sub _getRcs {
	my ($self) = @_;
	my $rcs = Rcs->new;
	$rcs->bindir($main::RCS{bindir});
	return $rcs;
}
1;

