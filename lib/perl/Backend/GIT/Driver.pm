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

use Backend::FS::Driver;
our @ISA = qw( Backend::FS::Driver );


use Fcntl qw(:flock);

use vars qw( %CACHE );

sub new {
	my $class = my $self = shift;
	my $self = { GIT=>$main::BACKEND_CONFIG{GIT}{gitcmd} || '/usr/bin/git',
		     EMPTYDIRFN=> $main::BACKEND_CONFIG{GIT}{emptydirfilename} || '.__empty__', 
		     LOCKFILE => $main::BACKEND_CONFIG{GIT}{lockfile} || '/tmp/webdav-git.lock'
	};
	bless $self, $class;
	$self->execGit('init') if !$self->isDir($main::DOCUMENT_ROOT.'.git');
	return $self;
}
sub unlinkFile {
	my ($self, $fn) = @_;
	createEmptyDirFile($fn);
	return $self->execGit('rm',$fn);
}
sub unlinkDir {
	my($self,$fn) = @_;
	return $self->execGit('rm','-r', $fn) && (!$self->exists($fn) || $self->SUPER::unlinkDir($fn));
}
sub readDir {
	my($self, $dirname, $limit, $filter) = @_;
	my $gitfilter = sub {
		my ($d, $f) = @_;
		return $self->gitFilter($d,$f) ||  !defined $filter || ((ref($filter) eq 'CODE' && $filter->($d,$f))||(ref($filter) ne 'CODE' && $filter->filter($d,$f)));
	};
	return $self->SUPER::readDir($dirname, $limit, $gitfilter);
}
sub gitFilter {
	my ($self, $dirname, $file) = @_;
	return $file eq '.git' || $file eq $$self{EMPTYDIRFN} || $self->filter(undef, $dirname, $file);
}
sub deltree {
	my ($self, $fn, $errRef) =  @_;
	$self->createEmptyDirFile($fn);
	return $self->execGit('rm','-r', $fn) && (!$self->exists($fn) || $self->SUPER::deltree($fn,$errRef));
}
sub saveData {
	my $self = shift @_;
	return $self->SUPER::saveData(@_) && $self->autoAdd();
}

sub saveStream {
	my $self = shift @_;
	return $self->SUPER::saveStream(@_) && $self->autoAdd();
}

sub compressFiles {
	my ($self, $desthandle, $basepath, @files) = @_;

	require Archive::Zip;
	my $zip =  Archive::Zip->new();
	my $gitfilter = sub {
		return !$self->gitFilter($self->dirname($_),$self->basename($_));
	};
	foreach my $file (@files) {	
		if ($self->isDir($basepath.$file)) {
			$zip->addTree($self->resolveVirt($basepath.$file), $file, $gitfilter);
		} elsif ($self->isReadable($basepath.$file) && $self->exists($basepath.$file)) {
			$zip->addFile($self->resolveVirt($basepath.$file), $file) unless $self->gitFilter($basepath, $file);
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
	if ($ret) {
		foreach my $member ($zip->members()) {
			my $fn = $self->resolveVirt($destination).$member->fileName();
			if (!$self->gitFilter($self->dirname($fn), $self->basename($fn))) {
				$zip->extractMember($member, $fn); 
			}
		}
	}
	return $self->autoAdd() && $ret;
}
sub createSymLink {
	my $self = shift @_;
	return $self->SUPER::createSymLink(@_) && $self->autoAdd();
}
sub rename {
	my $self = shift @_;
	return $self->execGit('mv',@_);
}
sub copy {
	my $self = shift @_;
	return $self->SUPER::copy(@_) && $self->autoAdd();
}

sub execGit {
	my $self = shift @_;
	return $self->_execGit(@_) && $self->commit();
}
sub _execGit {
	my $self = shift @_;
	my @params = map { $_=~s/^\Q$main::DOCUMENT_ROOT\E//r; } @_;
	my $ret = 1;
	#warn(join(" ",@_));
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
sub createEmptyDirFile {
	my ($self, $path) = @_;
	$path = $self->dirname($path) unless $self->isDir();
	my $edfn = "$path/$$self{EMPTYDIRFN}";
	$self->saveData($edfn,"") unless $self->exists($edfn);
	return 1;
}

1;