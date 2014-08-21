#!/usr/bin/perl
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

package Backend::GIT::Driver;

use strict;
#use warnings;

use Backend::Helper;
our @ISA = qw( Backend::Helper );


use Fcntl qw(:flock);

use vars qw( %CACHE );

sub new {
	my $class = my $self = shift;
	my $self = { BACKEND=> $main::backendmanager->getBackend($main::BACKEND_CONFIG{GIT}{backend} || 'FS'), 
		     GIT=>$main::BACKEND_CONFIG{GIT}{gitcmd} || '/usr/bin/git', 
		     LOCKFILE => $main::BACKEND_CONFIG{GIT}{LOCKFILE} || '/tmp/webdav-git.lock',
		     EMPTYDIRFN => $main::BACKEND_CONFIG{GIT}{EMPTYDIRFN} || '.__empty__'
	};
	return bless $self, $class;
}
sub finalize {
	my ($self) = @_;
	%CACHE = ();
	$$self{BACKEND}->finalize();
}

sub basename {
	my $self = shift @_;
	return $$self{BACKEND}->basename(@_);
}
sub dirname {
	my $self = shift @_;
	return $$self{BACKEND}->dirname(@_);
}

sub exists {
	my $self = shift @_;
	return $$self{BACKEND}->exists(@_);
}
sub isDir {
	my $self = shift @_;
	return $$self{BACKEND}->isDir(@_);
}
sub isFile {
	my $self = shift @_;
	return $$self{BACKEND}->isFile(@_);
}
sub isLink {
	my $self = shift @_;
	return $$self{BACKEND}->isLink(@_);
}
sub isBlockDevice {
	my $self = shift @_;
	return $$self{BACKEND}->isBlockDevice(@_);
}
sub isCharDevice {
	my $self = shift @_;
	return $$self{BACKEND}->isCharDevice(@_);
}
sub isEmpty {
	my $self = shift @_;
	return $$self{BACKEND}->isEmpty(@_);
}
sub isReadable {
	my $self = shift @_;
	return $$self{BACKEND}->isReadable(@_);
}
sub isWriteable {
	my $self = shift @_;
	return $$self{BACKEND}->isWriteable(@_);
}
sub isExecutable {
	my $self = shift @_;
	return $$self{BACKEND}->isExecutable(@_);
}
sub getParent {
	my $self = shift @_;
	return $$self{BACKEND}->getParent(@_);
}

sub mkcol {
	my $self = shift @_;
	return $$self{BACKEND}->mkcol(@_) && $$self{BACKEND}->saveData($_[0].'/'.$$self{EMPTYDIRFN},"") && $self->autoAdd();
}
sub unlinkFile {
	my $self = shift @_;
	return $self->execGit('rm',shift @_);
}
sub unlinkDir {
	my $self = shift @_;
	return $self->execGit('rm','-r', shift @_);
}
sub readDir {
	my($self, $dirname, $limit, $filter) = @_;
	my $gitfilter = sub {
		my ($d, $f) = @_;
		return $self->filter($d,$f) ||  !defined $filter || ((ref($filter) eq 'CODE' && $filter->($d,$f))||(ref($filter) ne 'CODE' && $filter->filter($d,$f)));
	};
	return $$self{BACKEND}->readDir($dirname, $limit, $gitfilter);
}
sub filter {
	my ($self, $dirname, $file) = @_;
	return $file eq $$self{EMPTYDIRFN} || $file eq '.git';
}
sub stat {
	my ($self, $fn) = @_;
	return $$self{BACKEND}->stat($fn);
}
sub lstat {
	my $self = shift @_;
	return $$self{BACKEND}->lstat(@_);
}

sub deltree {
	my $self = shift @_;
	return $self->execGit('rm','-r', shift @_);
}
sub changeFilePermissions {
	my $self = shift @_;
	return $$self{BACKEND}->changeFilePermissions(@_);
}

sub saveData {
	my $self = shift @_;
	return $$self{BACKEND}->saveData(@_) && $self->autoAdd();
}

sub saveStream {
	my $self = shift @_;
	return $$self{BACKEND}->saveStream(@_) && $self->autoAdd();
}

sub compressFiles {
	my ($self, $desthandle, $basepath, @files) = @_;

	require Archive::Zip;
	my $zip =  Archive::Zip->new();
	my $gitfilter = sub {
		return !$self->filter($self->dirname($_),$self->basename($_));
	};
	foreach my $file (@files) {	
		if ($self->isDir($basepath.$file)) {
			$zip->addTree($self->resolveVirt($basepath.$file), $file, $gitfilter);
		} elsif ($self->isReadable($basepath.$file) && $self->exists($basepath.$file)) {
			$zip->addFile($self->resolveVirt($basepath.$file), $file) unless $self->filter($basepath, $file);
		}
	}
	$zip->writeToFileHandle($desthandle,0);
}
sub uncompressArchive {
	my ($self, $zipfile, $destination) = @_;
	my $ret = 1;
	require Archive::Zip;
	my $zip = Archive::Zip->new();
	my $status = $zip->read($self->resolveVirt($zipfile));
	$ret = $status eq $zip->AZ_OK;
	$zip->extractTree(undef, $self->resolveVirt($destination)) if $ret;
	return $ret;
}

sub changeMod {
	my $self = shift @_;
	return $$self{BACKEND}->changeMod(@_);
}
sub createSymLink {
	my $self = shift @_;
	return $$self{BACKEND}->createSymLink(@_) && $self->autoAdd();
}
sub getLinkSrc {
	my $self = shift @_;
	return $$self{BACKEND}->getLinkSrc(@_);
}
sub resolve {
	my $self = shift @_;
	return $$self{BACKEND}->resolve(@_);
}

sub getFileContent {
	my $self = shift @_;
	return $$self{BACKEND}->getFileContent(@_);
}
sub hasSetUidBit {
	my $self = shift @_;
	return $$self{BACKEND}->hasSetUidBit(@_);
}
sub hasSetGidBit {
	my $self = shift @_;
	return $$self{BACKEND}->hasSetGidBit(@_);
}
sub hasStickyBit {
	my $self = shift @_;
	return $$self{BACKEND}->hasStickyBit(@_);
}
sub getLocalFilename {
	my $self = shift @_;
	return $$self{BACKEND}->getLocalFilename(@_);
}

sub printFile {
	my $self = shift @_;
	return $$self{BACKEND}->printFile(@_);
}
sub getDisplayName {
	my $self = shift @_;
	return $$self{BACKEND}->getDisplayName(@_);
}
sub rename {
	my $self = shift @_;
	return $self->execGit('mv',@_);
}
sub getQuota {
	my $self = shift @_;
	return $$self{BACKEND}->getQuota(@_);
}
sub copy {
	my $self = shift @_;
	return $$self{BACKEND}->copy(@_) && $self->autoAdd();
}

sub execGit {
	my $self = shift @_;
	return $self->_execGit(@_) && $self->commit();
}
sub _execGit {
	my $self = shift @_;
	my @params = map { $_=~s/^\Q$main::DOCUMENT_ROOT\E//r; } @_;
	my $ret = 1;
	if (open(my $fd, ">", $$self{LOCKFILE})) {
		chdir $main::DOCUMENT_ROOT;
		if (($main::ENABLE_FLOCK || flock($fd, LOCK_EX)) && open(my $git, '-|',$$self{GIT}, @params)) {
			my @output = <$git>;
			close($git);	
		}
		flock($fd, LOCK_UN) if $main::ENABLE_FLOCK;
		close($fd);
	} else {
		$ret = 0;
	} 
	
	return $ret;
}
sub autoAdd {
	my ($self) = @_;
	my $ret = 1;
	my @add;
	if (open(my $fd, ">", $$self{LOCKFILE})) {
		$ret= 0 if $main::ENABLE_FLOCK && !flock($fd,LOCK_EX);
		chdir $main::DOCUMENT_ROOT;
		if ($ret && open(my $git, '-|', $$self{GIT}, 'status', '-s')) {
			while (my $line = <$git>) {
				chomp($line);
				if ($line=~/^\?\? (.*)$/) {
					push @add, $1;					
				}
			}
		}
		close($fd)
	} else {
		$ret = 0;
	}
	return $ret && ( scalar(@add)==0 || $self->execGit('add',@add));
}
sub commit {
	my $self = shift @_;
	return $self->_execGit('commit','--allow-empty' ,'-m',$ENV{REMOTE_USER} || $ENV{REDIRECT_REMOTE_USER});
}
1;