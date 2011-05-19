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

package Backend::DBB::Driver;

use strict;
use Data::Dumper;

use Backend::FS::Driver;
our @ISA = qw( Backend::FS::Driver );

our $VERSION = 0.1;

use DBI qw( :sql_types );

use File::Basename;
use File::Temp qw( tempfile tempdir );

use constant {
	TYPE_DIR => 1,
	TYPE_FILE => 2,
	TYPE_LINK => 4,
};

use constant TYPES => qw ( TYPE_DIR TYPE_FILE TYPE_LINK );

sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;
	$self->initialize();
	return $self;
}

sub initialize {
	my ($self) = @_;
	$self->{_dbh} = DBI->connect(
				$main::DBB{dsn} || 'dbi:SQLite:dbname=/tmp/webdavcgi-dbdbackend-'.$ENV{REMOTE_USER}.'.db', 
				$main::DBB{user} || "", 
				$main::DBB{password} || "", 
				{ RaiseError=>0, AutoCommit=>0 }
	);
	if (defined $self->{_dbh}) {
		my $sth = $self->{_dbh}->prepare('SELECT name FROM objects');
		if (!defined $sth) {
			$sth = $self->{_dbh}->prepare('CREATE TABLE objects (name varchar(255) NOT NULL, parent varchar(255) NOT NULL, type int NOT NULL, owner VARCHAR(255) NOT NULL, created timestamp NOT NULL, modified NOT NULL, size int NOT NULL, permissions int NOT NULL, data blob)'); 
			$sth->execute();
			$self->{_dbh}->commit();
		}
	}
}

sub readDir {
	my($self, $fn) = @_;
	my @list;
	my $sth = $self->{_dbh}->prepare("SELECT name FROM objects WHERE parent = ?");
	if ($sth && $sth->execute($self->normalize($fn))) {
		my $data = $sth->fetchall_arrayref();
		foreach my $e (@${data}) {
			push @list, $$e[0];
		}
	}
	return \@list;
}
sub unlinkFile {
	my ($self, $fn) = @_;
	$fn = $self->normalize($fn);
	my $sth = $$self{_dbh}->prepare("DELETE FROM objects WHERE name = ? AND parent = ?");
	if ($sth && $sth->execute(basename($fn),dirname($fn))) {
		$$self{_dbh}->commit();
		return 1;
	} 
	return 0;
}
sub deltree {
	my ($self, $fn) = @_;
	$fn = $self->normalize($fn);
	print STDERR "deltree($fn)";
	my $sth = $$self{_dbh}->prepare("DELETE FROM objects WHERE parent = ? OR parent like ?");
	if ($sth && $sth->execute($fn,$fn.'/%')) {
		$sth = $$self{_dbh}->prepare("DELETE FROM objects WHERE name = ? AND parent = ?");
		$sth->execute(basename($fn), dirname($fn)) if $sth;
		if ($sth && !$sth->err) {
			$$self{_dbh}->commit();
			return 1;
		}
	}
	$$self{_dbh}->rollback();
	return 0;
}
sub isLink {
	return $_[0]->_getDBValue($_[1], 'type', -1) == TYPE_LINK;
}
sub isDir {
	return $_[0]->_isRoot($_[1]) || $_[0]->_getDBValue($_[1], 'type', -1) == TYPE_DIR;
}
sub isFile {
	return !$_[0]->_isRoot($_[1]) && $_[0]->_getDBValue($_[1], 'type', -1) == TYPE_FILE;
}

sub rename { 
	my ($self, $on, $nn) = @_;
	$on=$self->normalize($on);
	$nn=$self->normalize($nn);
	return 0 if $self->isDir($on) && scalar($self->readDir($on))>0;
	my $sth = $$self{_dbh}->prepare('UPDATE objects SET name = ?, parent = ? WHERE name = ? AND parent = ?');
	$self->unlinkFile($nn);
	if ($sth && $sth->execute(basename($nn),dirname($nn),basename($on),dirname($on))) {
		$$self{_dbh}->commit();
		return 1;
	}
	return 0; 
}
sub copy {
	my ($self, $src, $dst) = @_;
	$src = $self->normalize($src);
	$dst = $self->normalize($dst);
	my $v = $self->_getDBEntry($src,1);
	return $self->exists($dst) ?  $self->_changeDBEntry($dst, $$v{basename($src)}{data}) : $self->_addDBEntry($dst, TYPE_FILE, $$v{basename($src)}{data});
}

sub mkcol {
	return $_[0]->exists($_[1]) ? 0 : $_[0]->_addDBEntry($_[1], TYPE_DIR);
}

sub isReadable { return 1;}
sub isWriteable { return 1;}
sub isExecutable{ return $_[0]->isDir($_[1]);}

sub getLinkSrc { return $_[1]; }
sub hasSetUidBit { return 0; }
sub hasSetGidBit { return 0; }
sub changeMod { return 0; }
sub createSymLink { return 0; }
sub isBlockDevice { return 0; }
sub isCharDevice { return 0; }
sub readlink { $!='not supported'; return undef; }
sub symlink { return 0; }
sub hasStickyBit { return 0; }


sub exists {
	my ($self, $fn) = @_;
	$fn = $self->normalize($fn);
	my $h =$self->_getDBEntry($fn);
	return defined $h && exists $$h{basename($fn)};
}
sub stat {
	my ($self,$fn) =@_;
	return (0,0,$main::UMASK,0,0,0,0,0,0,0,0,0,0) if $self->_isRoot($fn);
	$fn=$self->normalize($fn);
	my $val = $self->_getDBEntry($fn);
	return CORE::stat($fn) unless defined $val;
	$fn = basename($fn);
	return (0,0,$$val{$fn}{permissions},0,0,0,0,$$val{$fn}{size},0,$$val{$fn}{modified},$$val{$fn}{created},0,0);
}


sub _getDBValue {
	my ($self, $fn, $attr, $default) = @_;
	$fn = $self->normalize($fn);
	my $dbv = $self->_getDBEntry($fn, $attr eq 'data');
	return defined $dbv ?  $$dbv{basename($fn)}{$attr} : $default;
}
sub _addDBEntry {
	my ($self, $name, $type) = @_;
	my $parent = dirname($name);
	my $created = time();
	$name = basename($name);

	my $sth = $self->{_dbh}->prepare('INSERT INTO objects (name, parent, type, owner, size, created, modified, permissions,data) VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?)');
	$sth->bind_param(1,$name);
	$sth->bind_param(2,$parent);
	$sth->bind_param(3,$type);
	$sth->bind_param(4,$ENV{REMOTE_USER});
	$sth->bind_param(5,defined $_[3] ? length($_[3]) : 0);
	$sth->bind_param(6,$created);
	$sth->bind_param(7,$created);
	$sth->bind_param(8,07777 ^ $main::UMASK);
	$sth->bind_param(9,$_[3],SQL_BLOB) if defined $_[3];
	my $ret  = $sth->execute();
	print STDERR "_addDBEntry($name,$type) parent=$parent";
	if (!$self->_isRoot($parent) && $ret) {
		$ret &= $self->_changeDBEntry($parent);
	}
	if ($ret) { 
		$self->{_dbh}->commit();
		return $ret;
	}
	$self->{_dbh}->rollback();
	return $ret;
}
sub _changeDBEntry {
	my ($self, $name) = @_;
	$name = $self->normalize($name);
	my $sel = 'UPDATE objects SET modified = ?';
	$sel.=', data = ?' if defined $_[2];
	$sel.=', size = ?' if defined $_[2];
	$sel.=' WHERE name = ? AND parent = ?';
	my $sth = $$self{_dbh}->prepare($sel);
	my $i = 0;
	$sth->bind_param(++$i,time());
	$sth->bind_param(++$i,$_[2],SQL_BLOB) if defined $_[2];
	$sth->bind_param(++$i,length($_[2])) if defined $_[2];
	$sth->bind_param(++$i,basename($name));
	$sth->bind_param(++$i,dirname($name));
	if ($sth->execute()) {
		$$self{_dbh}->commit();
		return 1;
	}
	return 0;
}
sub _getDBEntry {
	my ($self, $fn, $withdata) = @_;
	my $sel = 'SELECT name, parent, type, created, modified, size, permissions, owner';
	$sel.=',data' if $withdata;
	$sel.=' FROM objects WHERE name = ? AND parent = ?';
	my $sth = $self->{_dbh}->prepare($sel);
	$sth->execute(basename($self->normalize($fn)), dirname($self->normalize($fn)));
	return !$sth->err ? $sth->fetchall_hashref('name') : undef;
}

sub _isRoot {
	return $_[1] eq $main::DOCUMENT_ROOT;
}

sub normalize {
	my ($self, $fn) = @_;
	$fn=~s/([^\/]*)\/\.\.(\/?.*)/$1/;
	$fn=~s/(.+)\/$/$1/;
	return $fn;
}

sub isEmpty {
	my @stat = $_[0]->stat($_[1]);
	return $stat[7] == 0;
}
sub saveData {
	#my ($self, $path, $data, $append) = @_;
	my $fn = $_[0]->normalize($_[1]);
	my $data;
	if ($_[0]->exists($_[1])) {
		if ($_[3]) {
			my $v = _getDBEntry($fn,1);
			$data = $$v{basename($fn)}{data}.$_[2];
			return $_[0]->_changeDBEntry($fn,$$v{basename($fn)}{data}.$_[2]);
		}
		return $_[0]->_changeDBEntry($fn,$_[2]);
	} 
	return $_[0]->_addDBEntry($_[1],TYPE_FILE,$_[2]);
}
sub saveStream {
	my ($self, $fn, $fh) = @_;
	$fn = $self->normalize($fn);
	my $blob;
	while (read($fh, my $buffer, $main::BUFSIZE || 1048576)) {
		$blob.=$buffer;
	}
	return $self->exists($fn) ? $self->_changeDBEntry($fn,$blob) : $self->_addDBEntry($fn,TYPE_FILE,$blob);
}

sub printFile {
	my ($self, $fn, $fh) = @_;
	$fn=$self->normalize($fn);
	my $v = $self->_getDBEntry($fn,1);
	print $fh $$v{basename($fn)}{data}
}
sub getLocalFilename {
	my ($self, $fn) = @_;
	$fn=~/(\.[^\.]+)$/;
	my $suffix=$1;
	my ($fh, $filename) = tempfile(TEMPLATE=>'/tmp/webdavcgiXXXXX', CLEANUP=>1, SUFFIX=>$suffix);
	$self->printFile($fn, $fh);
	return $filename;
}
sub _copytolocal {
	my ($self, $dir, $file) = @_;

	my $nn = "$dir".basename($file);
	if ($self->isFile($file) && open(my $f, ">$nn")) {
		my $e = $self->_getDBEntry($file,1);
		print $f $$e{basename($file)}{data};
		close($f);
	} elsif ($self->isDir($file)) {
		mkdir($nn);
		$file.='/' unless $file =~ /\/$/;
		foreach my $f (@{$self->readDir($file)}) {
			$self->_copytolocal("$nn/", "$file$f"); 
		}
	}
	my @stat = $self->stat($file);
	utime($stat[8], $stat[9], $nn);
}
sub compressFiles {
	my ($self, $desthandle, $basepath, @files) = @_;
        my $tempdir = tempdir(CLEANUP => 1);
	foreach my $file (@files) {
		$self->_copytolocal("$tempdir/", "$basepath$file");
	}
	$self->SUPER::compressFiles($desthandle, "$tempdir/", @{$self->SUPER::readDir("$tempdir/")});
}
sub _copytodb {
	my ($self, $src, $dst) = @_;
	my $ret = 0;
	if (opendir(my $d, $src)) {
		$ret = 1;
		while (my $f = readdir($d)) {
			next if $f=~/^\.{1,2}$/;
			my $nn = "$src$f";
			my $nd = "$dst$f";
			if (-d $nn) {
				$self->mkcol($nd);
				$ret &= $self->_copytodb("$nn/", "$nd/");
			} else {
				if (open(my $fh,"<$nn")) {
					$self->saveStream($nd, $fh);
					close($fh);
				} else {
					$ret = 0;
				}
			}
		}
		closedir($d);
	}
	return $ret;
}
sub uncompressArchive {
	my ($self, $zipfile, $destination) = @_;
        my $tempdir = tempdir(CLEANUP => 1);
	return $self->SUPER::uncompressArchive($self->getLocalFilename($zipfile), "$tempdir/") && $self->_copytodb("$tempdir/",$destination);
}

1;
