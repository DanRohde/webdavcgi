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

require Exporter;
our @ISA = qw(Exporter);
our $VERSION = 0.1;
our @EXPORT = qw(new);
our @EXPORT_OK = qw(exists isDir isWriteable isReadable isExecutable isFile isLink isBlockDevice isCharDevice isEmpty getParent rcopy rmove mkcol unlinkFile readDir stat lstat deltree changeFilePermissions saveData saveStream uncompressArchive compressFiles moveToTrash changeMod createSymLink resolve getFileContent hasSetUidBit hasSetGidBit hasStickyBit getLocalFilename openFileHandle closeFileHandle);


use File::Basename;
use File::Spec::Link;
use Fcntl qw(:flock);

use File::Spec::Link;

use Archive::Zip;

sub new {
	my $class = shift;
	my $self = {};
	return bless $self, $class;
}

sub exists {
	shift;
	return -e shift;
}
sub isDir {
	shift;
	return -d shift;
}
sub isFile {
	return !isDir(@_);
}
sub isLink {
	shift;
	return -l shift;
}
sub isBlockDevice {
	shift;
	return -b shift;
}
sub isCharDevice {
	shift;
	return -c shift;
}
sub isEmpty {
	shift;
	return -z shift;
}
sub isReadable {
	shift;
	return -r shift;
}
sub isWriteable {
	shift;
	return -w shift;
}
sub isExecutable {
	shift;
	return -x shift;
}
sub getParent {
	shift;
	return dirname(shift);
}
sub rcopy {
        my ($self,$src,$dst,$move,$depth) = @_;

	main::debug("rcopy: src=$src, dst=$dst, move=$move, depth=$depth");

        $depth=0 unless defined $depth;

        return 0 if defined $main::LIMIT_FOLDER_DEPTH && $main::LIMIT_FOLDER_DEPTH > 0 && $depth > $main::LIMIT_FOLDER_DEPTH;

        # src == dst ?
        return 0 if $src eq $dst;

        # src in dst?
        return 0 if -d $src && $dst =~ /^\Q$src\E/;

        # src exists and readable?
        return 0 if ! -e $src || (!$main::IGNOREFILEPERMISSIONS && !-r $src);

        # dst writeable?
        return 0 if -e $dst && (!$main::IGNOREFILEPERMISSIONS && !-w $dst);

        my $nsrc = $src;
        $nsrc =~ s/\/$//; ## remove trailing slash for link test (-l)

        if ( -l $nsrc) { # link
                if (!$move || !rename($nsrc, $dst)) {
                        my $orig = readlink($nsrc);
                        return 0 if ( !$move || unlink($nsrc) ) && !symlink($orig,$dst);
                }
        } elsif ( -f $src ) { # file
                if (-d $dst) {
                        $dst.='/' if $dst !~/\/$/;
                        $dst.=basename($src);
                }
                if (!$move || !rename($src,$dst)) {
                        return 0 unless open(SRC,"<$src");
                        return 0 unless open(DST,">$dst");
                        my $buffer;
                        while (read(SRC,$buffer,$main::BUFSIZE || 1048576)>0) {
                                print DST $buffer;
                        }

                        close(SRC);
                        close(DST);
                        if ($move) {
                                return 0 if !$main::IGNOREFILEPERMISSIONS && !-w $src;
                                return 0 unless unlink($src);
                        }
                }
        } elsif ( -d $src ) {
                # cannot write folders to files:
                return 0 if -f $dst;

                $dst.='/' if $dst !~ /\/$/;
                $src.='/' if $src !~ /\/$/;

                if (!$move || getDirInfo($self, $src,'realchildcount')>0 || !rename($src,$dst)) {
                        mkdir $dst unless -e $dst;

                        return 0 unless opendir(SRC,$src);
                        my $rret = 1;
                        foreach my $filename (grep { !/^\.{1,2}$/ } readdir(SRC)) {
                                $rret = $rret && rcopy($self,$src.$filename, $dst.$filename, $move, $depth+1);
                        }
                        closedir(SRC);
                        if ($move) {
                                return 0 if !$main::IGNOREFILEPERMISSIONS && !-w $src;
                                return 0 unless $rret && rmdir($src);
                        }
                }
        } else {
                return 0;
        }

        return 1;
}
sub rmove {
        return rcopy(@_, 1);
}

sub mkcol {
	shift;
	mkdir(shift);
}
sub unlinkFile {
	shift;
	unlink(shift);
}
sub getDirInfo {
        my ($self, $fn, $prop, $filter, $limit, $max) = @_;
        return $main::CACHE{getDirInfo}{$fn}{$prop} if defined $main::CACHE{getDirInfo}{$fn}{$prop};
        my %counter = ( childcount=>0, visiblecount=>0, objectcount=>0, hassubs=>0 );
        if (opendir(DIR,$fn)) {
                foreach my $f ( grep { !/^\.{1,2}$/ } readdir(DIR)) {
                        $counter{realchildcount}++;
                        if (!main::is_hidden("$fn/$f")) {
                                next if defined $filter && defined $$filter{$fn} && $f !~ $$filter{$fn};
                                $counter{childcount}++;
                                last if (defined $limit && defined $$limit{$fn} && $counter{childcount} >= $$limit{$fn}) || (!defined $$limit{$fn} && defined $max && $counter{childcount} >= $max);
                                $counter{visiblecount}++ if !-d "$fn/$f" && $f !~/^\./;
                                $counter{objectcount}++ if !-d "$fn/$f";
                        }
                }
                closedir(DIR);
        }
        $counter{hassubs} = ($counter{childcount}-$counter{objectcount} > 0 )? 1:0;

        foreach my $k (keys %counter) {
                $main::CACHE{getDirInfo}{$fn}{$k}=$counter{$k};
        }
        return $counter{$prop};
}
sub readDir {
        my ($self, $dirname) = @_;
        my @files;
        if ((!defined $main::FILECOUNTPERDIRLIMIT{$dirname} || $main::FILECOUNTPERDIRLIMIT{$dirname} >0 ) && opendir(my $dir,$dirname)) {
                while (my $file = readdir($dir)) {
                        next if $file =~ /^\.{1,2}$/;
                        next if main::is_hidden("$dirname/$file");
                        next if defined $main::FILEFILTERPERDIR{$dirname} && $file !~ $main::FILEFILTERPERDIR{$dirname};
                        last if (defined $main::FILECOUNTPERDIRLIMIT{$dirname} && $#files+1 >= $main::FILECOUNTPERDIRLIMIT{$dirname})
                                || (!defined $main::FILECOUNTPERDIRLIMIT{$dirname} && defined $main::FILECOUNTLIMIT && $#files+1 > $main::FILECOUNTLIMIT);
                        push @files, $file;
                }
                closedir(DIR);
        }
        return \@files;
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
                debug("Cannot delete $f: not allowed");
                push(@$errRef, { $f => "Cannot delete $f" });
        } elsif (-l $nf) {
                if (unlink($nf)) {
                        $count++;
                        main::db_deleteProperties($f);
                        mani::db_delete($f);
                } else {
                        push(@$errRef, { $f => "Cannot delete '$f': $!" });
                }
        } elsif (-d $f) {
                if (opendir(DIR,$f)) {
                        foreach my $sf (grep { !/^\.{1,2}$/ } readdir(DIR)) {
                                my $full = $f.$sf;
                                $full.='/' if -d $full && $full!~/\/$/;
                                $count+=deltree($self,$full,$errRef);
                        }
                        closedir(DIR);
                        if (rmdir $f) {
                                $count++;
                                $f.='/' if $f!~/\/$/;
                                main::db_deleteProperties($f);
                                main::db_delete($f);
                        } else {
                                push(@$errRef, { $f => "Cannot delete '$f': $!" });
                        }
                } else {
                        push(@$errRef, { $f => "Cannot open '$f': $!" });
                }
        } elsif (-e $f) {
                if (unlink($f)) {
                        $count++;
                        main::db_deleteProperties($f);
                        main::db_delete($f);
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
        my $nfn = File::Spec::Link->full_resolve($fn);
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

	if (($ret = open(F, "${mode}${file}"))) {
		print F $data;
		close(F);
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
	my $zip = Archive::Zip->new();
	my $status = $zip->read($zipfile);
	$ret = $status eq $zip->AZ_OK;
	$zip->extractTree(undef, $destination) if $ret;
	return $ret;
}

sub compressFiles {
	my ($self, $desthandle, $basepath, @files) = @_;

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

sub moveToTrash  {
        my ($self,$fn) = @_;

        my $ret = 0;
        my $etag = main::getETag($fn); ## get a unique name for trash folder
        $etag=~s/\"//g;
        my $trash = "$main::TRASH_FOLDER$etag/";

        if ($fn =~ /^\Q$main::TRASH_FOLDER\E/) { ## delete within trash
                my @err;
                deltree($self,$fn, \@err);
                $ret = 1 if $#err == -1;
        } elsif (-e $main::TRASH_FOLDER || mkdir($main::TRASH_FOLDER)) {
                if (-e $trash) {
                        my $i=0;
                        while (-e $trash) { ## find unused trash folder
                                $trash="$main::TRASH_FOLDER$etag".($i++).'/';
                        }
                }
                $ret = 1 if mkdir($trash) && rmove($self, $fn, $trash.basename($fn));
        }
        return $ret;
}
sub changeMod {
	chmod($_[1], $_[2]);
}
sub createSymLink {
	return symlink($_[1],$_[2]);
}
sub getLinkSrc {
	return readlink($_[1]);
}
sub resolve {
	return File::Spec::Link->full_resolve($_[1]);
}

sub getFileContent {
        my ($self,$fn) = @_;
        main::debug("getFileContent($fn)");
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

sub openFileHandle {
	return open($_[1],"<$_[2]");
}
sub closeFileHandle {
	return close($_[1]);
}
	
1;

