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

# fixed ACL bug  reported by Thomas Klose <thomas.klose@gmx.com>:
use filetest 'access';

use File::Spec::Link;
use Fcntl qw(:flock);

use File::Spec::Link;


use vars qw( %CACHE );

sub new {
	my $class = shift;
	my $self = { cache=>\%CACHE };
	return bless $self, $class;
}
sub finalize {
	my ($self) = @_;
	%CACHE = ();
	$$self{cache}=\%CACHE;
}

sub basename {
	return exists $CACHE{$_[0]}{$_[1]}{basename} ? $CACHE{$_[0]}{$_[1]}{basename} : ($CACHE{$_[0]}{$_[1]}{basename} = main::getBaseURIFrag($_[1]));
}
sub dirname {
	return main::getParentURI($_[1]);
}

sub exists {
	return exists $CACHE{$_[0]}{$_[1]}{exists} && defined $CACHE{$_[0]}{$_[1]}{exists} ? $CACHE{$_[0]}{$_[1]}{exists} : ($CACHE{$_[0]}{$_[1]}{exists} = -e $_[0]->resolveVirt($_[1]));
}
sub isDir {
	return exists $CACHE{$_[0]}{$_[1]}{isDir} ? $CACHE{$_[0]}{$_[1]}{isDir} : ($CACHE{$_[0]}{$_[1]}{isDir} = -d $_[0]->resolveVirt($_[1]));
}
sub isFile {
	return exists $CACHE{$_[0]}{$_[1]}{isFile} ? $CACHE{$_[0]}{$_[1]}{isFile} : ($CACHE{$_[0]}{$_[1]}{isFile} = -f $_[0]->resolveVirt($_[1]));
}
sub isLink {
	my ($self, $fn) = @_;
	$fn=~s/\/$//;
	return $CACHE{$self}{$fn}{isLink} if exists $CACHE{$self}{$fn}{isLink};
	return $CACHE{$self}{$fn}{isLink}=1 if $self->isVirtualLink($fn); 
	return ($CACHE{$self}{$fn}{isLink} = -l $self->resolveVirt($fn,1));
}
sub isBlockDevice {
	return -b $_[0]->resolveVirt($_[1]);
}
sub isCharDevice {
	return -c $_[0]->resolveVirt($_[1]);
}
sub isEmpty {
	return -z $_[0]->resolveVirt($_[1]);
}
sub isReadable {
	return exists $CACHE{$_[0]}{$_[1]}{isReadable} && defined $CACHE{$_[0]}{$_[1]}{isReadable} ? $CACHE{$_[0]}{$_[1]}{isReadable} : ($CACHE{$_[0]}{$_[1]}{isReadable} = -r $_[0]->resolveVirt($_[1]));
}
sub isWriteable {
	return exists $CACHE{$_[0]}{$_[1]}{isWriteable} && defined $CACHE{$_[0]}{$_[1]}{isWriteable} ? $CACHE{$_[0]}{$_[1]}{isWriteable} : ($CACHE{$_[0]}{$_[1]}{isWriteable} =  -w $_[0]->resolveVirt($_[1]));
}
sub isExecutable {
	return -x $_[0]->resolveVirt($_[1]);
}
sub getParent {
	return $_[0]->dirname($_[1]);
}

sub mkcol {
	delete $CACHE{$_[0]}{$_[1]};
	return CORE::mkdir($_[0]->resolveVirt($_[1]));
}
sub unlinkFile {
	my ($self, $f) = @_;
	return 0 if $self->isVirtualLink($f);
	delete $CACHE{$self}{$f};
	$f=~s/\/$//;
	delete $CACHE{$self}{$f};
	return CORE::unlink($self->resolveVirt($f));
}
sub unlinkDir {
	delete $CACHE{$_[0]}{$_[1]};
	return 0 if $_[0]->isVirtualLink($_[1]);
	return CORE::rmdir($_[0]->resolveVirt($_[1]));
}
sub readDir {
        my ($self, $dirname, $limit, $filter) = @_;
        my @files;
        if (opendir(my $dir,$self->resolveVirt($dirname))) {
                while (my $file = readdir($dir)) {
			last if defined $limit && $#files >= $limit;
			next if $self->filter($filter, $dirname, $file);
                        push @files, $file;
                }
                closedir($dir);
		if (exists $main::BACKEND_CONFIG{$main::BACKEND}{fsvlink}{$dirname} && (!defined $limit || $#files < $limit)) {
			foreach my $file (keys %{$main::BACKEND_CONFIG{$main::BACKEND}{fsvlink}{$dirname}}) {
				last if defined $limit && $#files >= $limit;
				next if $self->filter($filter, $dirname, $file);
				push @files, $file;
			}
		}
	}
        return \@files;
}
sub filter {
	my ($self, $filter, $dirname, $file) = @_;
	return 1 if defined $file && $file =~ /^\.{1,2}$/;
	return defined $filter && ((ref($filter) eq 'CODE' && $filter->($dirname,$file))||(ref($filter) ne 'CODE' && $filter->filter($dirname,$file)));
}
sub stat {
	return CORE::stat($_[0]->resolveVirt($_[1]));
}
sub lstat {
	return CORE::lstat($_[0]->resolveVirt($_[1]));
}

sub deltree {
        my ($self,$f,$errRef) = @_;
        $errRef=[] unless defined $errRef;
        my $count = 0;
        if (!main::isAllowed($f,1)) {
                push(@$errRef, { $f => "Cannot delete $f" });
        } elsif ($self->isLink($f)) {
                if ($self->unlinkFile($f)) {
                        $count++;
                } else {
                        push(@$errRef, { $f => "Cannot delete '$f': $!" });
                }
        } elsif ($self->isDir($f)) {
                if (opendir(my $dirh,$self->resolveVirt($f))) {
                        foreach my $sf (grep { !/^\.{1,2}$/ } readdir($dirh)) {
                                my $full = $f.$sf;
                                $full.='/' if $self->isDir($full) && $full!~/\/$/;
                                $count+=$self->deltree($full,$errRef);
                        }
                        closedir($dirh);
                        if ($self->unlinkDir($f)) {
                                $count++;
                                $f.='/' if $f!~/\/$/;
                        } else {
                                push(@$errRef, { $f => "Cannot delete '$f': $!" });
                        }
                } else {
                        push(@$errRef, { $f => "Cannot open '$f': $!" });
                }
        } elsif ($self->exists($f)) {
                if ($self->unlinkFile($f)) {
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
                my @stat = $self->stat($fn);
                my $newmode;
                $newmode = $stat[2] | $mode if $type eq 'a';
                $newmode = $stat[2] ^ ($stat[2] & $mode ) if $type eq 'r';
                chmod($newmode, $fn);
        }
        my $nfn = $self->resolve($self->resolveVirt($fn));
        return if exists $$visited{$nfn};
        $$visited{$nfn}=1;

        if ($recurse && $self->isDir($fn)) {
                if (opendir(my $dir, $self->resolveVirt($fn))) {
                        foreach my $f ( grep { !/^\.{1,2}$/ } readdir($dir)) {
                                $f.='/' if $self->isDir("$fn$f") && $f!~/\/$/;
                                changeFilePermissions($self, $fn.$f, $mode, $type, $recurse, $visited);
                        }
                        closedir($dir);
                }
        }
}

sub saveData {
	my ($self, $file, $data, $append) = @_;
	my $ret = 1;

	delete $CACHE{$self}{$file};

	my ($block_hard, $block_curr) = $self->getQuota($self->dirname($file));
	return 0 if $block_hard > 0 && length($data) + $block_curr > $block_hard;

	my $mode = $append ? '>>' : '>';

	if (($ret = open(my $f, ${mode}.$self->resolveVirt(${file})))) {
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
	my ($self, $destination, $filehandle) = @_;
	my $ret = 1;

	delete $CACHE{$self}{$destination};

	my ($block_hard, $block_curr) = $self->getQuota($self->dirname($destination));

	if (($ret=open(my $f,">".$self->resolveVirt($destination)))) {
		if ($main::ENABLE_FLOCK && !flock($f, LOCK_EX | LOCK_NB)) {
			close($f);
			$ret = 0;
		} else {
			binmode($f);
			binmode($filehandle);
			my ($consumed) = 0;
			while (read($filehandle,my $buffer,$main::BUFSIZE || 1048576)>0) {
				last if $block_hard>0 && $consumed+$block_curr >= $block_hard;
				print $f $buffer;
				$consumed+=length($buffer);
			}
			flock($f, LOCK_UN) if $main::ENABLE_FLOCK;
			close($f);
			$ret = 0 if $block_hard > 0 && $consumed+$block_curr >= $block_hard;
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
	my $status = $zip->read($self->resolveVirt($zipfile));
	$ret = $status eq $zip->AZ_OK;
	$zip->extractTree(undef, $self->resolveVirt($destination)) if $ret;
	return $ret;
}

sub compressFiles {
	my ($self, $desthandle, $basepath, @files) = @_;

	require Archive::Zip;
	my $zip =  Archive::Zip->new();
	foreach my $file (@files) {
		if ($self->isDir($basepath.$file)) {
			$zip->addTree($self->resolveVirt($basepath.$file), $file);
		} elsif ($self->exists($basepath.$file)) {
			$zip->addFile($self->resolveVirt($basepath.$file), $file);
		}
	}
	$zip->writeToFileHandle($desthandle,0);
}

sub changeMod {
	delete $CACHE{$_[1]}{$_[2]};
	chmod($_[1], $_[0]->resolveVirt($_[2]));
}
sub createSymLink {
	delete $CACHE{$_[1]}{$_[2]};
	return CORE::symlink($_[0]->resolveVirt($_[1]),$_[0]->resolveVirt($_[2]));
}
sub getLinkSrc {
	return $_[0]->resolveVirt($_[1]) if $_[0]->isVirtualLink($_[1]);
	return CORE::readlink($_[0]->resolveVirt($_[1]));
}
sub resolveVirt  {
	return $CACHE{$_[0]}{$_[1]}{resolveVirt} || ($CACHE{$_[0]}{$_[1]}{resolveVirt} = $_[0]->getVirtualLinkTarget($_[1]));
}
sub resolve {
	return $CACHE{$_[0]}{$_[1]}{resolve} || ($CACHE{$_[0]}{$_[1]}{resolve} = File::Spec::Link->full_resolve($_[1]));
}

sub getFileContent {
        my ($self,$fn) = @_;
        my $content="";
        if ($self->exists($fn) && !$self->isDir($fn) && open(F,"<".$self->resolveVirt($fn))) {
                $content = join("",<F>);
                close(F);
        }
        return $content;
}
sub hasSetUidBit {
	return -u $_[0]->resolveVirt($_[1]); 
}
sub hasSetGidBit {
	return -g $_[0]->resolveVirt($_[1]);
}
sub hasStickyBit {
	return -k $_[0]->resolveVirt($_[1]);
}
sub getLocalFilename {
	return $_[0]->resolveVirt($_[1]);
}

sub printFile {
	my ($self, $file, $to) =@_;
	$to = \*STDOUT unless defined $to;
	if (open(my $fh, $self->resolveVirt($file))) {
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
	delete $CACHE{$_[0]}{$_[1]};
	delete $CACHE{$_[0]}{$_[2]};
	return 0 if $_[0]->isVirtualLink($_[1]) || $_[0]->isVirtualLink($_[2]);
	return CORE::rename($_[0]->resolveVirt($_[1]),$_[0]->resolveVirt($_[2]));
}
sub getQuota {
	my ($self, $fn) = @_;
	require Quota;
	my @quota =  Quota::query(Quota::getqcarg($self->resolveVirt($self->isDir($fn)?$fn:$self->getParent($fn))));
	return @quota ? ( $quota[2] * 1024, $quota[0] * 1024 ) : (0, 0);
}
sub copy {
	my ($self, $src, $dst) = @_;
	delete $CACHE{$self}{$dst};

	if (open(my $srcfh,"<".$self->resolveVirt($src,1)) && open(my $dstfh, ">".$self->resolveVirt($dst,1))) {
		while (read($srcfh, my $buffer, $main::BUFSIZE || 1048576)) {
			syswrite($dstfh, $buffer);
		}
		close($srcfh);
		close($dstfh);
		return 1;
	}
	return 0;
}
sub isVirtualLink {
	my ($self, $fn) = @_;
	return exists $main::BACKEND_CONFIG{$main::BACKEND}{fsvlink}{$self->dirname($fn).'/'} && exists $main::BACKEND_CONFIG{$main::BACKEND}{fsvlink}{$self->dirname($fn).'/'}{$self->basename($fn)};
}
sub getVirtualLinkTarget {
	my ($self, $src) = @_;
	my $target = $src;
	if (!exists $CACHE{$self}{$src}{getVirtualLinkTarget}{sortedkeys}) {
		my @fslinkkeys = sort { $b cmp $a } keys %{$main::BACKEND_CONFIG{$main::BACKEND}{fsvlink}};
		$CACHE{$self}{$src}{getVirtualLinkTarget}{sortedkeys} = \@fslinkkeys;
	}

	foreach my $linkdir ( @{$CACHE{$self}{$src}{getVirtualLinkTarget}{sortedkeys}}) {
		if (!exists $CACHE{$self}{$src}{getVirtualLinkTarget}{$linkdir}) {
			my @linkdirkeys =  keys %{$main::BACKEND_CONFIG{$main::BACKEND}{fsvlink}{$linkdir}} ;
			$CACHE{$self}{$src}{getVirtualLinkTarget}{$linkdir} = \@linkdirkeys;
		}
		foreach my $link ( @{$CACHE{$self}{$src}{getVirtualLinkTarget}{$linkdir}} ) { 
			$target=~s /^\Q$linkdir$link\E(\/?|\/.+)?$/$main::BACKEND_CONFIG{$main::BACKEND}{fsvlink}{$linkdir}{$link}$1/ && last;
		}
	}
	return $target;
}
	
1;

