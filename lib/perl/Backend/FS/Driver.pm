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

package Backend::FS::Driver;

use strict;
#use warnings;

use File::Spec::Link;
use Fcntl qw(:flock);

use File::Spec::Link;


use vars qw( %CACHE );

sub new {
	my $class = shift;
	my $self = {};
	return bless $self, $class;
}

sub basename {
	return exists $CACHE{$_[0]}{$_[1]}{basename} ? $CACHE{$_[0]}{$_[1]}{basename} : ($CACHE{$_[0]}{$_[1]}{basename} = main::getBaseURIFrag($_[1]));
}
sub dirname {
	return main::getParentURI($_[1]);
}

sub exists {
	return exists $CACHE{$_[0]}{$_[1]}{exists} ? $CACHE{$_[0]}{$_[1]}{exists} : ($CACHE{$_[0]}{$_[1]}{exists} = -e $_[1]);
}
sub isDir {
	return exists $CACHE{$_[0]}{$_[1]}{isDir} ? $CACHE{$_[0]}{$_[1]}{isDir} : ($CACHE{$_[0]}{$_[1]}{isDir} = -d $_[1]);
}
sub isFile {
	return exists $CACHE{$_[0]}{$_[1]}{isFile} ? $CACHE{$_[0]}{$_[1]}{isFile} : ($CACHE{$_[0]}{$_[1]}{isFile} = -f $_[1]);
}
sub isLink {
	my ($self, $fn) = @_;
	$fn=~s/\/$//;
	return $CACHE{$self}{$fn}{isLink} if exists $CACHE{$self}{$fn}{isLink};
	return ($CACHE{$self}{$fn}{isLink} = -l $fn);
}
sub isBlockDevice {
	return -b $_[1];
}
sub isCharDevice {
	return -c $_[1];
}
sub isEmpty {
	return -z $_[1];
}
sub isReadable {
	return exists $CACHE{$_[0]}{$_[1]}{isReadable} ? $CACHE{$_[0]}{$_[1]}{isReadable} : ($CACHE{$_[0]}{$_[1]}{isReadable} = -r $_[1]);
}
sub isWriteable {
	return exists $CACHE{$_[0]}{$_[1]}{isWriteable} ? $CACHE{$_[0]}{$_[1]}{isWriteable} : ($CACHE{$_[0]}{$_[1]}{isWriteable} =  -w $_[1]);
}
sub isExecutable {
	return -x $_[1];
}
sub getParent {
	return $_[0]->dirname($_[1]);
}

sub mkcol {
	return CORE::mkdir($_[1]);
}
sub unlinkFile {
	my $ret = CORE::unlink($_[1]);
	delete $CACHE{$_[0]}{$_[1]} if $ret;
	return $ret;
}
sub readDir {
        my ($self, $dirname, $limit, $filter) = @_;
        my @files;
        if (opendir(my $dir,$dirname)) {
                while (my $file = readdir($dir)) {
			last if defined $limit && $#files >= $limit;
			next if $self->filter($filter, $dirname, $file);
                        push @files, $file;
                }
                closedir($dir);
	}
        return \@files;
}
sub filter {
	my ($self, $filter, $dirname, $file) = @_;
	return 1 if defined $file && $file =~ /^\.{1,2}$/;
	return defined $filter && ((ref($filter) eq 'CODE' && $filter->($dirname,$file))||(ref($filter) ne 'CODE' && $filter->filter($dirname,$file)));
}
sub stat {
	return CORE::stat($_[1]);
}
sub lstat {
	return CORE::lstat($_[1]);
}

sub deltree {
        my ($self,$f,$errRef) = @_;
        $errRef=[] unless defined $errRef;
        my $count = 0;
        my $nf = $f; $nf=~s/\/$//;
        if (!main::isAllowed($f,1)) {
                push(@$errRef, { $f => "Cannot delete $f" });
        } elsif (-l $nf) {
                if (unlink($nf)) {
			delete $CACHE{$self}{$f};
                        $count++;
                } else {
                        push(@$errRef, { $f => "Cannot delete '$f': $!" });
                }
        } elsif (-d $f) {
                if (opendir(my $dirh,$f)) {
                        foreach my $sf (grep { !/^\.{1,2}$/ } readdir($dirh)) {
                                my $full = $f.$sf;
                                $full.='/' if -d $full && $full!~/\/$/;
                                $count+=deltree($self,$full,$errRef);
                        }
                        closedir($dirh);
                        if (rmdir $f) {
				delete $CACHE{$self}{$f};
                                $count++;
                                $f.='/' if $f!~/\/$/;
                        } else {
                                push(@$errRef, { $f => "Cannot delete '$f': $!" });
                        }
                } else {
                        push(@$errRef, { $f => "Cannot open '$f': $!" });
                }
        } elsif (-e $f) {
                if (unlink($f)) {
                        $count++;
                } else {
                        push(@$errRef, { $f  => "Cannot delete '$f' : $!" }) ;
                }
        } else {
                push(@$errRef, { $f => "File/Folder '$f' not found" });
        }
        return $count;
}
sub changeFilePermissions {
        my ($self, $fn, $mode, $type, $recurse, $visited) = @_;
        if ($type eq 's') {
                chmod($mode, $fn);
        } else {
                my @stat = CORE::stat($fn);
                my $newmode;
                $newmode = $stat[2] | $mode if $type eq 'a';
                $newmode = $stat[2] ^ ($stat[2] & $mode ) if $type eq 'r';
                chmod($newmode, $fn);
        }
        my $nfn = $self->resolve($fn);
        return if exists $$visited{$nfn};
        $$visited{$nfn}=1;

        if ($recurse && -d $fn) {
                if (opendir(my $dir, $fn)) {
                        foreach my $f ( grep { !/^\.{1,2}$/ } readdir($dir)) {
                                $f.='/' if -d "$fn$f" && $f!~/\/$/;
                                changeFilePermissions($self, $fn.$f, $mode, $type, $recurse, $visited);
                        }
                        closedir($dir);
                }
        }
}

sub saveData {
	my ($self, $file, $data, $append) = @_;
	my $ret = 1;

	my $mode = $append ? '>>' : '>';

	if (($ret = open(my $f, "${mode}${file}"))) {
		if ($main::ENABLE_FLOCK && !flock($f, LOCK_EX | LOCK_NB)) {
			$ret = 0;
		} else {
			print $f $data;
			flock($f, LOCK_UN) if $main::ENABLE_FLOCK;
		}
		close($f);
	}
	return $ret;
}

sub saveStream {
	my ($self, $destination, $filename) = @_;

	my $ret = 1;

	if (($ret=open(my $f,">$destination"))) {
		if ($main::ENABLE_FLOCK && !flock($f, LOCK_EX | LOCK_NB)) {
			close($f);
			$ret = 0;
		} else {
			binmode($f);
			binmode($filename);
			while (read($filename,my $buffer,$main::BUFSIZE || 1048576)>0) {
				print $f $buffer;
			}
			flock($f, LOCK_UN) if $main::ENABLE_FLOCK;
			close($f);
		}
	} else {
		$ret = 0;
	}
	return $ret;
}


sub uncompressArchive {
	my ($self, $zipfile, $destination) = @_;
	my $ret = 1;
	require Archive::Zip;
	my $zip = Archive::Zip->new();
	my $status = $zip->read($zipfile);
	$ret = $status eq $zip->AZ_OK;
	$zip->extractTree(undef, $destination) if $ret;
	return $ret;
}

sub compressFiles {
	my ($self, $desthandle, $basepath, @files) = @_;

	require Archive::Zip;
	my $zip =  Archive::Zip->new();
	foreach my $file (@files) {
		if (-d $basepath.$file) {
			$zip->addTree($basepath.$file, $file);
		} else {
			$zip->addFile($basepath.$file, $file);
		}
	}
	$zip->writeToFileHandle($desthandle,0);
}

sub changeMod {
	chmod($_[1], $_[2]);
}
sub createSymLink {
	return CORE::symlink($_[1],$_[2]);
}
sub getLinkSrc {
	return CORE::readlink($_[1]);
}
sub resolve {
	return $CACHE{$_[0]}{$_[1]}{resolve} || ($CACHE{$_[0]}{$_[1]}{resolve} = File::Spec::Link->full_resolve($_[1]));
}

sub getFileContent {
        my ($self,$fn) = @_;
        my $content="";
        if (-e $fn && !-d $fn && open(F,"<$fn")) {
                $content = join("",<F>);
                close(F);
        }
        return $content;
}
sub hasSetUidBit {
	return -u $_[1]; 
}
sub hasSetGidBit {
	return -g $_[1];
}
sub hasStickyBit {
	return -k $_[1];
}
sub getLocalFilename {
	return $_[1];
}

sub printFile {
	my ($self, $file, $to) =@_;
	$to = \*STDOUT unless defined $to;
	if (open(my $fh, $file)) {
		binmode $fh;
		binmode $to;
		while (read($fh, my $buffer, $main::BUFSIZE || 1048576)>0) {
			print $to $buffer;
		}
		close($fh);
	}
}
sub getDisplayName {
	return $CACHE{$_[0]}{$_[1]}{getDisplayName}
			? $CACHE{$_[0]}{$_[1]}{getDisplayName}
			: ( $CACHE{$_[0]}{$_[1]}{getDisplayName} =  $_[0]->basename($_[1]) . ($_[0]->isDir($_[1]) && $_[1] ne '/'? '/':''));
}
sub rename {
	return CORE::rename($_[1],$_[2]);
}
sub getQuota {
	my ($self, $fn) = @_;
	require Quota;
	my @quota =  Quota::query(Quota::getqcarg($fn));
	return @quota ? ( $quota[2] * 1024, $quota[0] * 1024 ) : (0, 0);
}
sub copy {
	my ($self, $src, $dst) = @_;

	if (open(my $srcfh,"<$src") && open(my $dstfh, ">$dst")) {
		while (read($srcfh, my $buffer, $main::BUFSIZE || 1048576)) {
			syswrite($dstfh, $buffer);
		}
		close($srcfh);
		close($dstfh);
		return 1;
	}
	return 0;
}
	
1;

