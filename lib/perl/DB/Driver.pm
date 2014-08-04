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
package DB::Driver;

use strict;

use vars qw( %CACHE $PREFIX);

$PREFIX = '///-/';

use DBI;

sub new {
	my $this = shift;
	my $class = ref($this) || $this;
	my $self = {};
	bless $self, $class;
	return $self;
}
sub finalize {
	my $self = shift;
	%CACHE = ();
	if (!$main::DBI_PERSISTENT && $$self{DBI_INIT}) {
		$$self{DBI_INIT}->disconnect();
		delete $$self{DBI_INIT};
	}
}
sub db_handleUpdates {
	my ($self, $dbh, $sth) = @_;
	if ($sth->err) {
		warn($sth->errstr);
		$dbh->rollback();
	} else {
		$dbh->commit();
	}
}
sub db_isRootFolder {
        my ($self, $fn, $token) = @_;
        my $rows =  [];
        my $dbh = $self->db_init();
        my $sth = $dbh->prepare('SELECT basefn,fn,type,scope,token,depth,timeout,owner,timestamp FROM webdav_locks WHERE fn = ? AND basefn = ? AND token = ?');
        if (defined $sth) {
                $sth->execute($fn, $fn, $token);
                $rows = $sth->fetchall_arrayref();
        }
        return $#{$rows}>-1;
}

sub db_getLike {
        my ($self,$fn) = @_;
        my $rows;
        my $dbh = $self->db_init();
        my $sth = $dbh->prepare('SELECT basefn,fn,type,scope,token,depth,timeout,owner,timestamp FROM webdav_locks WHERE fn like ?');
        if (defined $sth) {
                $sth->execute($fn);
                $rows = $sth->fetchall_arrayref();
        }
        return $rows;
}
sub db_get {
        my ($self,$fn,$token) = @_;
        my $rows;
        my $dbh = $self->db_init();
        my $sel = 'SELECT basefn,fn,type,scope,token,depth,timeout,owner,timestamp FROM webdav_locks WHERE fn = ?';
        my @params;
        push @params, $fn;
        if (defined $token) {
                $sel .= ' AND token = ?';
                push @params, $token;
        }
        
        my $sth = $dbh->prepare($sel);
        if (defined $sth) {
                $sth->execute(@params);
                $rows = $sth->fetchall_arrayref();
        }
        return $rows;
}
sub db_insertProperty {
        my ($self,$fn, $propname, $value) = @_;
        my $ret = 0;
        my $dbh = $self->db_init();
        my $sth = $dbh->prepare('INSERT INTO webdav_props (fn, propname, value) VALUES ( ?,?,?)');
        if (defined  $sth) {
                $sth->execute($PREFIX.$fn, $propname, $value);
                $ret = ($sth->rows >0)?1:0;
                $self->db_handleUpdates($dbh,$sth);
                $CACHE{Properties}{$fn}{$propname}=$value;
        }
        return $ret;
}
sub db_updateProperty {
        my ($self,$fn, $propname, $value) = @_;
        my $ret = 0;
        my $dbh = $self->db_init();
        my $sth = $dbh->prepare('UPDATE webdav_props SET value = ? WHERE (fn = ? OR fn = ?) AND propname = ?');
        if (defined  $sth) {
                $sth->execute($value, $fn, $PREFIX.$fn, $propname);
                $ret=($sth->rows>0)?1:0;
                $self->db_handleUpdates($dbh,$sth);
                $CACHE{Properties}{$fn}{$propname}=$value;
        }
        return $ret;
}
sub db_moveProperties {
        my($self,$src,$dst) = @_;
        my $dbh = $self->db_init();
        my $sth = $dbh->prepare('UPDATE webdav_props SET fn = ? WHERE fn = ? OR fn = ?');
        my $ret = 0;
        if (defined $sth) {
                $sth->execute($PREFIX.$dst, $PREFIX.$src,$src);
                $ret = ($sth->rows>0)?1:0;
                $self->db_handleUpdates($dbh,$sth);
                delete $CACHE{Properties}{$src};
        }
        return $ret;
}
sub db_movePropertiesRecursive {
        my($self,$src,$dst) = @_;
        my $dbh = $self->db_init();
        my $sth = $dbh->prepare('UPDATE webdav_props SET fn = REPLACE(fn, ?, ?) WHERE fn = ? OR fn = ? OR fn LIKE ? OR fn LIKE ?');
        my $ret = 0;
        if (defined $sth) {
                $sth->execute($PREFIX.$src,$PREFIX.$dst,$src,$PREFIX.$src, "$src/\%","$PREFIX$src/\%");
                $ret = ($sth->rows>0)?1:0;
                $self->db_handleUpdates($dbh,$sth);
                delete $CACHE{Properties}{$src};
        }
        return $ret;
}
sub db_copyProperties {
        my($self,$src,$dst) = @_;
        my $dbh = $self->db_init();
        my $sth = $dbh->prepare('INSERT INTO webdav_props (fn,propname,value) SELECT ?, propname, value FROM webdav_props WHERE fn = ? OR fn = ?');
        my $ret = 0;
        if (defined $sth) {
                $sth->execute($dst,$src, $PREFIX.$src);
                $ret = ($sth->rows>0)?1:0;
                $self->db_handleUpdates($dbh,$sth);
        }
        return $ret;
}
sub db_deleteProperties {
        my($self,$fn) = @_;
        my $dbh = $self->db_init();
        my $sth = $dbh->prepare('DELETE FROM webdav_props WHERE fn = ? OR fn = ?');
        my $ret = 0;
        if (defined $sth) {
                $sth->execute($fn,$PREFIX.$fn);
                $self->db_handleUpdates($dbh,$sth);
                delete $CACHE{Properties}{$fn};
                $ret = 1; # bugfix by Harald Strack <hstrack@ssystems.de>
        }
        return $ret;
        
}
sub db_deletePropertiesRecursive {
        my($self,$fn) = @_;
        my $dbh = $self->db_init();
        my $sth = $dbh->prepare('DELETE FROM webdav_props WHERE fn = ? OR fn = ? OR fn like ? OR fn like ?');
        my $ret = 0;
        if (defined $sth) {
                $sth->execute($fn,$PREFIX.$fn,"$fn/\%","$PREFIX$fn/\%");
                $self->db_handleUpdates($dbh,$sth);
                delete $CACHE{Properties}{$fn};
                $ret = 1; # bugfix by Harald Strack <hstrack@ssystems.de>
        }
        return $ret;
        
}
sub db_getProperties {
        my ($self,$fn) = @_;
        return $CACHE{Properties}{$fn} if exists $CACHE{Properties}{$fn} || $CACHE{Properties_flag}{$fn}; 
        my $dbh = $self->db_init();
        my $sth = $dbh->prepare('SELECT REPLACE(fn,?,?), propname, value FROM webdav_props WHERE fn like ? OR fn like ?');
        if (defined $sth) {
                $sth->execute($PREFIX,'',"$fn\%","$PREFIX$fn\%");
                if (!$sth->err) {
                        my $rows = $sth->fetchall_arrayref();
                        foreach my $row (@{$rows}) {
                                $CACHE{Properties}{$$row[0]}{$$row[1]}=$$row[2];
                        }
                        $CACHE{Properties_flag}{$fn}=1;
                } else {
                	$dbh->rollback();
                }
        }
        return $CACHE{Properties}{$fn};
}
sub db_getProperty {
        my ($self,$fn,$propname) = @_;
        my $props = $self->db_getProperties($fn);
        return $$props{$propname};
}
sub db_removeProperty {
        my ($self, $fn, $propname) = @_;
        my $dbh = $self->db_init();
        my $sth = $dbh->prepare('DELETE FROM webdav_props WHERE (fn = ? OR fn = ?) AND propname = ?');
        my $ret = 0;
        if (defined $sth) {
                $sth->execute($fn, $PREFIX.$fn, $propname);
                $ret = ($sth->rows >0)?1:0;
                $self->db_handleUpdates($dbh,$sth);
                delete $CACHE{Properties}{$fn}{$propname};
        }
        return $ret;
}
sub db_getPropertyFnByValue {
        my ($self,$propname,$value) = @_;
        my $dbh = $self->db_init();
        my $sth = $dbh->prepare('SELECT REPLACE(fn,?,?) FROM webdav_props WHERE propname = ? and value = ?');
        if (defined $sth) {
                $sth->execute($PREFIX, '',$propname,$value);
                if (!$sth->err) {
                        my $rows = $sth->fetchall_arrayref();
                        return $$rows[0] if $rows;
                }
                $self->db_handleUpdates($dbh,$sth);
        }
        return undef;
}
sub db_insert {
        my ($self, $basefn, $fn, $type, $scope, $token, $depth, $timeout, $owner) = @_;
        my $ret = 0;
        my $dbh = $self->db_init();
        my $sth = $dbh->prepare('INSERT INTO webdav_locks (basefn, fn, type, scope, token, depth, timeout, owner) VALUES ( ?,?,?,?,?,?,?,?)');
        if (defined $sth) {
                $sth->execute($basefn,$fn,$type,$scope,$token,$depth,$timeout,$owner);
                $ret=($sth->rows>0)?1:0;
                $self->db_handleUpdates($dbh,$sth);
        }
        return $ret;
}
sub db_update {
        my ($self,$basefn, $fn, $timeout) = @_;
        my $ret = 0;
        my $dbh = $self->db_init();
        my $sth = $dbh->prepare('UPDATE webdav_locks SET timeout=? WHERE basefn = ? AND fn = ?' );
        if (defined $sth) {
                $sth->execute($timeout, $basefn, $fn);
                $ret = ($sth->rows>0)?1:0;
                $self->db_handleUpdates($dbh,$sth);
        }
        return $ret;
}
sub db_delete {
        my ($self,$fn,$token) = @_;
        my $ret = 0;
        my $dbh = $self->db_init();
        my $sel = 'DELETE FROM webdav_locks WHERE ( basefn = ? OR fn = ? )';
        my @params = ($fn, $fn);
        if (defined $token) {
                $sel.=' AND token = ?';
                push @params, $token;
        }
        my $sth = $dbh->prepare($sel);
        if (defined $sth) {
                $sth->execute(@params);
                $ret = $sth->rows>0?1:0;
                $self->db_handleUpdates($dbh,$sth);
        }
        
        return $ret;
}
sub db_init {
		my $self = shift;
        return $$self{DBI_INIT} if defined $$self{DBI_INIT};

        my $dbh = DBI->connect($main::DBI_SRC, $main::DBI_USER, $main::DBI_PASS, { RaiseError=>0, PrintError=>0, AutoCommit=>0 }) || die("You need a database (see \$DBI_SRC configuration)");
        if (defined $dbh && $main::CREATE_DB) {
                foreach my $query (@main::DB_SCHEMA) {
                        my $sth = $dbh->prepare($query);
                        if (defined $sth) {
                                $sth->execute();
                                if ($sth->err) {
                                	$dbh->rollback();
                                        $dbh=undef;
                                } else {
                                        $dbh->commit();
                                }       
                        } else {
                                warn("db_init: '$query' preparation failed!");
                        }
                }
        }
        $$self{DBI_INIT} = $dbh;
        return $dbh;
}
sub db_rollback($) {
        my ($self,$dbh) = @_;
        $dbh->rollback();
}
sub db_commit($) {
        my ($self,$dbh) = @_;
        $dbh->commit();
}
1;
