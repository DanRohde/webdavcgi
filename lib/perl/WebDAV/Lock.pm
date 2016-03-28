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

package WebDAV::Lock;

use strict;
use warnings;

use base qw( WebDAV::Common );

our $VERSION = '2.0';

use Date::Parse;
use UUID::Tiny;

use DefaultConfig
  qw( $DBI_SRC $PATH_TRANSLATED $DEFAULT_LOCK_OWNER $DEFAULT_LOCK_TIMEOUT $DBI_TIMEZONE );
use FileUtils qw( filter get_file_limit );
use WebDAV::XMLHelper qw( create_xml );

sub _lock_dir {
    my ( $self, @args ) = @_;
    my (
        $fn,    $ru,   $xmldata, $depth,   $timeout,
        $token, $base, $visited, $respref, $propref
    ) = @args;
    if ( ${$self}{backend}->isReadable($fn) ) {
        foreach my $f (
            @{
                ${$self}{backend}->readDir( $fn, get_file_limit($fn), \&filter )
            }
          )
        {
            my $nru = $ru . $f;
            my $nfn = $fn . $f;
            $nru .= ${$self}{backend}->isDir($nfn) ? q{/} : q{};
            $nfn .= ${$self}{backend}->isDir($nfn) ? q{/} : q{};
            my $subreqresp = $self->lock_resource(
                $nfn,
                $nru,
                $xmldata,
                lc($depth) eq 'infinity' ? $depth : $depth - 1,
                $timeout,
                $token,
                defined $base ? $base : $fn,
                $visited
            );
            if ( defined ${$subreqresp}{multistatus} ) {
                push @{ ${$respref}{multistatus}{response} },
                  @{ ${$subreqresp}{multistatus}{response} };
            }
            else {
                if ( exists ${$subreqresp}{prop} ) {
                    push @{$propref}, @{ ${$subreqresp}{prop}{lockdiscovery} };
                }
            }
        }
    }
    else {
        push @{ ${$respref}{multistatus}{response} },
          { href => $ru, status => 'HTTP/1.1 403 Forbidden' };
    }
    return;
}

sub lock_resource {
    my ( $self, @args ) = @_;
    my ( $fn, $ru, $xmldata, $depth, $timeout, $token, $base, $visited ) =
      @args;
    my %resp = ();
    my @prop = ();

    my %activelock = ();
    my @locktypes  = keys %{ ${$xmldata}{'{DAV:}locktype'} };
    my @lockscopes = keys %{ ${$xmldata}{'{DAV:}lockscope'} };
    my $locktype   = $#locktypes >= 0 ? $locktypes[0] : undef;
    my $lockscope  = $#lockscopes >= 0 ? $lockscopes[0] : undef;
    my $owner      = create_xml(
        defined ${$xmldata}{'{DAV:}owner'}
        ? ${$xmldata}{'{DAV:}owner'}
        : $DEFAULT_LOCK_OWNER,
        0, 1
    );
    if ($locktype)  { $locktype =~ s/{[^}]+}//xms; }
    if ($lockscope) { $lockscope =~ s/{[^}]+}//xms; }

    if ($locktype)  { $activelock{locktype}{$locktype}   = undef; }
    if ($lockscope) { $activelock{lockscope}{$lockscope} = undef; }
    $activelock{locktoken}{href} = $token;
    $activelock{depth}           = $depth;
    $activelock{lockroot}        = $ru;

    my $rfn = $self->resolve($fn);
    my $rbase = $self->resolve( $base ? $base : $fn );

# save lock to database (structure: basefn, fn, type, scope, token, timeout(null), owner(null)):
    if (
        ${$self}{db}->db_insert(
            $rbase, $rfn,   $locktype, $lockscope,
            $token, $depth, $timeout,  $owner
        )
      )
    {
        push @prop, { activelock => \%activelock };
    }
    elsif ( ${$self}{db}->db_update( $rbase, $rfn, $timeout ) ) {
        push @prop, { activelock => \%activelock };
    }
    else {
        push @{ $resp{multistatus}{response} },
          {
            href   => $ru,
            status => 'HTTP/1.1 403 Forbidden (db update failed)'
          };
    }
    my $resfn = ${$self}{backend}->resolve($fn);
    return \%resp if exists ${$visited}{$resfn};
    ${$visited}{$resfn} = 1;

    if ( ${$self}{backend}->isDir($fn)
        && ( lc($depth) eq 'infinity' || $depth > 0 ) )
    {
        $self->_lock_dir(
            $fn,    $ru,   $xmldata, $depth, $timeout,
            $token, $base, $visited, \%resp, \@prop
        );
    }
    if ( exists $resp{multistatus} && $#prop >= 0 ) {
        push @{ $resp{multistatus}{response} },
          { propstat => { prop => { lockdiscovery => \@prop } } };
    }

    if ( !defined $resp{multistatus} ) {
        $resp{prop}{lockdiscovery} = \@prop;
    }

    return \%resp;
}

sub unlock_resource {
    my ( $self, $fn, $token ) = @_;
    my $rfn = $self->resolve($fn);
    return ${$self}{db}->db_isRootFolder( $rfn, $token )
      && ${$self}{db}->db_delete( $rfn, $token );
}

sub _check_timed_out {
    my ( $self, $fn, $rows ) = @_;
    my $ret = 0;
    my $now = time;
    $DBI_TIMEZONE //=
      $DBI_SRC =~ /dbi:SQLite/xmsi ? 'GMT' : 'localtime';
    $DEFAULT_LOCK_TIMEOUT //= 3_600;
    while ( my $row = shift @{$rows} ) {
        my ( $token, $timeout, $timestamp ) = (
            ${$row}[4], ${$row}[6],
            int( str2time( ${$row}[8], $DBI_TIMEZONE ) ),
        );
        if ( !defined $timeout || $timeout =~ /^\s*$/xms ) {
            $timeout = "Second-$DEFAULT_LOCK_TIMEOUT";
        }
        $self->{debug}->(
"_check_timed_out($fn): token=$token, timeout=$timeout, timestamp=$timestamp"
        );
        if ( $timeout =~ /(\d+)$/xms ) {
            my $val  = $1;
            my $mult = 1;
            my %m    = (
                'second' => 1,
                'minute' => 60,
                'hour'   => 3_600,
                'day'    => 86_400,
                'week'   => 604_800,
            );
            if ( $timeout =~ /^([^\-]+)/xms ) {
                $mult = $m{ lc $1 } || 1;
            }
            $ret = $now - $timestamp - ( $mult * $val ) >= 0 ? 1 : 0;
            $self->{debug}->(
"_check_timed_out($fn): now=$now, mult=$mult, val=$val (now-timestamp)="
                  . ( $now - $timestamp )
                  . ": ret=$ret" );
            if ($ret) { ${$self}{db}->db_delete( $fn, $token ); }
        }
    }
    return $ret;
}

sub is_locked_recurse {
    my ( $self, $fn ) = @_;
    $fn //= $PATH_TRANSLATED;
    my $rfn  = $self->resolve($fn);
    my $rows = ${$self}{db}->db_getLike("$rfn\%");
    return $#{$rows} >= 0 && !$self->_check_timed_out( $rfn, $rows );
}

sub is_locked {
    my ( $self, $fn ) = @_;
    my $rfn = $self->resolve($fn);
    $rfn .= ${$self}{backend}->isDir($fn) && $rfn !~ /\/$/xms ? q{/} : q{};
    my $rows = ${$self}{db}->db_get($rfn);
    return ( $#{$rows} >= 0 ) && !$self->_check_timed_out( $rfn, $rows );
}

sub is_locked_cached {
    my ( $self, $fn ) = @_;
    my $rfn = $self->resolve($fn);
    $rfn .= ${$self}{backend}->isDir($fn) && $rfn !~ /\/$/xms ? q{/} : q{};
    my $rows = ${$self}{db}->db_getCached($rfn);
    return ( ( $#{$rows} >= 0 ) && !$self->_check_timed_out( $rfn, $rows ) )
      ? 1
      : 0;
}

sub is_lockable {    # check lock and exclusive
    my ( $self, $fn, $xmldata ) = @_;
    my $rfn        = $self->resolve($fn);
    my @lockscopes = keys %{ ${$xmldata}{'{DAV:}lockscope'} };
    my $lockscope =
      @lockscopes && $#lockscopes >= 0 ? $lockscopes[0] : 'exclusive';

    my $rowsref;
    if ( !${$self}{backend}->exists($fn) ) {
        $rowsref = ${$self}{db}->db_get(
            $self->resolve( ${$self}{backend}->getParent($fn) ) . q{/} );
    }
    elsif ( ${$self}{backend}->isDir($fn) ) {
        $rowsref = ${$self}{db}->db_getLike("$rfn\%");
    }
    else {
        $rowsref = ${$self}{db}->db_get($rfn);
    }
    my $ret = 0;
    if ( $#{$rowsref} >= 0 ) {
        my $row = ${$rowsref}[0];
        $ret = ( !defined ${$row}[3] || lc( ${$row}[3] ) ne 'exclusive' )
          && $lockscope ne '{DAV:}exclusive' ? 1 : 0;
    }
    else {
        $ret = 1;
    }
    return $ret;
}

sub get_lock_discovery {
    my ( $self, $fn ) = @_;
    my $rfn = $self->resolve($fn);
    $self->{debug}->("get_lock_discovery($fn) (rfn=$rfn)");
    my $rowsref = ${$self}{db}->db_get($rfn);

    my @resp = ();
    $self->{debug}->( 'get_lock_discovery: rowcount=' . $#{$rowsref} );
    if ( $#{$rowsref} >= 0 ) {
        foreach my $row ( @{$rowsref} )
        {    # basefn,fn,type,scope,token,depth,timeout,owner
            my %lock;
            if ( defined ${$row}[2] ) {
                $lock{locktype}{ ${$row}[2] } = undef;
            }
            if ( defined ${$row}[3] ) {
                $lock{lockscope}{ ${$row}[3] } = undef;
            }
            $lock{locktoken}{href} = ${$row}[4];
            $lock{depth} = ${$row}[5];
            $lock{timeout} = defined ${$row}[6] ? ${$row}[6] : 'Infinite';
            if ( defined ${$row}[7] ) { $lock{owner} = ${$row}[7]; }

            push @resp, { activelock => \%lock };
        }

    }
    $self->{debug}->( 'get_lock_discovery: resp count=' . $#resp );

    return $#resp > -1 ? \@resp : undef;
}

sub get_tokens {
    my ( $self, $fn, $recurse ) = @_;
    my $rfn = $self->resolve($fn);
    my $rowsref =
      $recurse
      ? ${$self}{db}->db_getLike("$rfn%")
      : ${$self}{db}->db_get($rfn);
    my @tokens = map { ${$_}[4] } @{$rowsref};
    return \@tokens;
}

sub inherit_lock {
    my ( $self, $fn, $check_content, $visited ) = @_;
    $fn //= $PATH_TRANSLATED;
    my $backend = ${$self}{backend};

    my $rfn = $self->resolve($fn);

    my $nfn = $backend->resolveVirt( $backend->resolve($fn) );
    return if exists ${$visited}{$nfn};
    ${$visited}{$nfn} = 1;

    my $bfn = $backend->getParent($fn) . q{/};

    $self->{debug}->("inherit_lock: check lock for $bfn ($fn)");
    my $db   = ${$self}{db};
    my $rows = $db->db_get( $self->resolve($bfn) );
    return if $#{$rows} == -1 && !$check_content;
    if ( $#{$rows} >= 0 ) { $self->{debug}->("inherit_lock: $bfn is locked"); }
    if ($check_content) {
        $rows = $db->db_get($rfn);
        return if $#{$rows} == -1;
        $self->{debug}->("inherit_lock: $fn is locked");
    }
    my $row = ${$rows}[0];
    if ( $backend->isDir($fn) ) {
        $self->{debug}->("inherit_lock: $fn is a collection");
        $db->db_insert(
            ${$row}[0], $rfn,       ${$row}[2], ${$row}[3],
            ${$row}[4], ${$row}[5], ${$row}[6], ${$row}[7]
        );
        if ( $backend->isReadable($fn) ) {
            foreach my $f (
                @{ $backend->readDir( $fn, get_file_limit($fn), \&filter ) } )
            {
                my $full = $fn . $f;
                $full .= $backend->isDir($full)
                  && $full !~ /\/$/xms ? q{/} : q{};
                $db->db_insert(
                    $self->resolve( ${$row}[0] ), ${$self}->resolve($full),
                    ${$row}[2],                   ${$row}[3],
                    ${$row}[4],                   ${$row}[5],
                    ${$row}[6],                   ${$row}[7]
                );
                $self->inherit_lock( $full, undef, $visited );
            }
        }
    }
    else {
        $db->db_insert( $self->resolve( ${$row}[0] ),
            $rfn, ${$row}[2], ${$row}[3], ${$row}[4], ${$row}[5], ${$row}[6],
            ${$row}[7] );
    }
    return;
}

sub getuuid {
    my ($fn) = @_;
    my $uuid_ns = create_UUID( UUID_V1, "opaquelocktoken:$fn" );
    my $uuid = create_UUID( UUID_V3, $uuid_ns, $fn . time );
    return UUID_to_string($uuid);
}
1;
