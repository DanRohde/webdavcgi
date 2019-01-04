########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2016 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package Requests::WebDAVRequest;

use strict;
use warnings;

our $VERSION = '1.0';

use base qw( Requests::Request );

use List::MoreUtils qw( any );

use DefaultConfig qw( $ENABLE_BIND %FILECOUNTPERDIRLIMIT );
use WebDAV::XMLHelper qw( get_namespace_uri %NAMESPACES );
use WebDAV::WebDAVProps
  qw(@KNOWN_COLL_LIVE_PROPS @KNOWN_FILE_LIVE_PROPS %UNSUPPORTED_PROPS_HASH
  @PROTECTED_PROPS %KNOWN_COLL_PROPS_HASH %KNOWN_FILE_PROPS_HASH);
use FileUtils qw( is_hidden get_file_limit );

sub init {
    my ( $self, $config ) = @_;
    $self->SUPER::init($config);
    WebDAV::WebDAVProps::init_webdav_props();
    return $self;
}

sub free {
    my ($self) = @_;
    WebDAV::WebDAVProps::free();
    return $self->SUPER::free();
}

sub handle_property_request {
    my ( $self, $xml, $dataref, $resp_200, $resp_403 ) = @_;
    my $pm = $self->get_property_module();
    if ( ref( $dataref->{'{DAV:}remove'} ) eq 'ARRAY' ) {
        foreach my $remove ( @{ $dataref->{'{DAV:}remove'} } ) {
            foreach my $propname ( keys %{ $remove->{'{DAV:}prop'} } ) {
                $pm->remove_property( $propname, $remove->{'{DAV:}prop'},
                    $resp_200, $resp_403 );
            }
        }
    }
    elsif ( ref( $dataref->{'{DAV:}remove'} ) eq 'HASH' ) {
        foreach
          my $propname ( keys %{ $dataref->{'{DAV:}remove'}{'{DAV:}prop'} } )
        {
            $pm->remove_property( $propname,
                $dataref->{'{DAV:}remove'}{'{DAV:}prop'},
                $resp_200, $resp_403 );
        }
    }
    if ( ref( $dataref->{'{DAV:}set'} ) eq 'ARRAY' ) {
        foreach my $set ( @{ $dataref->{'{DAV:}set'} } ) {
            foreach my $propname ( keys %{ $set->{'{DAV:}prop'} } ) {
                $pm->set_property( $propname, $set->{'{DAV:}prop'}, $resp_200,
                    $resp_403 );
            }
        }
    }
    elsif ( ref( $dataref->{'{DAV:}set'} ) eq 'HASH' ) {
        my $lastmodifiedprocessed = 0;
        foreach my $propname ( keys %{ $dataref->{'{DAV:}set'}{'{DAV:}prop'} } )
        {
            if (   $propname eq '{DAV:}getlastmodified'
                || $propname eq
                '{urn:schemas-microsoft-com:}Win32LastModifiedTime' )
            {
                next if $lastmodifiedprocessed;
                $lastmodifiedprocessed = 1;
            }
            $pm->set_property( $propname, $dataref->{'{DAV:}set'}{'{DAV:}prop'},
                $resp_200, $resp_403 );
        }
    }
    if ( $xml =~ /<([^:]+:)?set[\s>]+.*<([^:]+:)?remove[\s>]+/xms )
    {    ## fix parser bug: set/remove|remove/set of the same prop
        if ( ref( $dataref->{'{DAV:}remove'} ) eq 'ARRAY' ) {
            foreach my $remove ( @{ $dataref->{'{DAV:}remove'} } ) {
                foreach my $propname ( keys %{ $remove->{'{DAV:}prop'} } ) {
                    $pm->remove_property( $propname, $remove->{'{DAV:}prop'},
                        $resp_200, $resp_403 );
                }
            }
        }
        elsif ( ref( $dataref->{'{DAV:}remove'} ) eq 'HASH' ) {
            foreach my $propname (
                keys %{ $dataref->{'{DAV:}remove'}{'{DAV:}prop'} } )
            {
                $pm->remove_property( $propname,
                    $dataref->{'{DAV:}remove'}{'{DAV:}prop'},
                    $resp_200, $resp_403 );
            }
        }
    }
    return;
}

sub get_prop_stat {
    my ( $self, $fn, $uri, $props, $all, $noval ) = @_;
    my @propstat = ();

    my $backend = $self->{config}->{backend};

    $self->debug("get_prop_stat($fn,$uri,...)");

    my $is_readable = $backend->isReadable($fn);

    my $nfn = $is_readable ? $backend->resolve($fn) : $fn;

    my @stat = $is_readable ? $backend->stat($fn) : ();
    my %resp_200 = ( status => 'HTTP/1.1 200 OK' );
    my %resp_404 = ( status => 'HTTP/1.1 404 Not Found' );

    my $is_dir = $backend->isDir($nfn);

    $fn .= $is_dir && $fn !~ /\/$/xms ? q{/} : q{};
    foreach my $prop ( @{$props} ) {
        my ( $xmlnsuri, $propname ) = ( 'DAV:', $prop );
        if ( $prop =~ /^[{]([^}]*)[}](.*)$/xms ) {
            ( $xmlnsuri, $propname ) = ( $1, $2 );
        }

        #if (grep({$_=~/^\Q$propname\E$/} @UNSUPPORTED_PROPS) >0) {
        if ( exists $UNSUPPORTED_PROPS_HASH{$propname} ) {
            $self->debug("get_prop_stat: UNSUPPORTED: $propname");
            $resp_404{prop}{$prop} = undef;
            next;
        }
        elsif (
            (
                !defined $NAMESPACES{$xmlnsuri}
                || any { /^\Q$propname\E$/xms }
                ( $is_dir ? @KNOWN_COLL_LIVE_PROPS : @KNOWN_FILE_LIVE_PROPS )
            )
            && !any { /^\Q$propname\E$/xms } @PROTECTED_PROPS
          )
        {
            my $dbval = $self->{config}->{db}->db_getProperty(
                $self->get_property_module()->resolve($fn),
                $prop =~ /{[^}]*}/xms
                ? $prop
                : '{' . get_namespace_uri($prop) . "}$prop"
            );
            if ( defined $dbval ) {
                $resp_200{prop}{$prop} = $noval ? undef : $dbval;
                next;
            }
            elsif ( !any { /^\Q$propname\E$/xms }
                ( $is_dir ? @KNOWN_COLL_LIVE_PROPS : @KNOWN_FILE_LIVE_PROPS ) )
            {
                $self->debug(
                    "get_prop_stat: #1 NOT FOUND: $prop ($propname, $xmlnsuri)"
                );
                $resp_404{prop}{$prop} = undef;
            }
        }
        ##if (grep({$_=~/^\Q$propname\E$/} $is_dir ? @KNOWN_COLL_PROPS : @KNOWN_FILE_PROPS)>0) {
        if (
            (
                $is_dir
                ? exists $KNOWN_COLL_PROPS_HASH{$propname}
                : exists $KNOWN_FILE_PROPS_HASH{$propname}
            )
          )
        {
            if ($noval) {
                $resp_200{prop}{$prop} = undef;
            }
            else {
                $self->get_property_module()
                  ->get_property( $fn, $uri, $prop, \@stat, \%resp_200,
                    \%resp_404 );
            }
        }
        elsif ( !$all ) {
            $self->debug(
                "get_prop_stat: #2 NOT FOUND: $prop ($propname, $xmlnsuri)");
            $resp_404{prop}{$prop} = undef;
        }
    }    # foreach

    if ( exists $resp_200{prop} ) { push @propstat, \%resp_200; }
    if ( exists $resp_404{prop} ) { push @propstat, \%resp_404; }
    return \@propstat;
}

sub read_dir_recursive {
    my (
        $self, $fn,    $ru,    $resps_ref, $props,
        $all,  $noval, $depth, $noroot,    $visited
    ) = @_;
    my $backend = $self->{config}->{backend};

    return if is_hidden($fn);
    my $is_readable = $backend->isReadable($fn);
    my $nfn = $is_readable ? $backend->resolve($fn) : $fn;
    if ( !$noroot ) {
        my %response = ( href => $ru );
        $response{href} = $ru;
        $response{propstat} =
          $self->get_prop_stat( $nfn, $ru, $props, $all, $noval );
        if ( scalar @{ $response{propstat} } == 0 ) {
            $response{status} = 'HTTP/1.1 200 OK';
            delete $response{propstat};
        }
        else {
            if (   $ENABLE_BIND
                && $depth < 0
                && exists ${$visited}{$nfn} )
            {
                $response{propstat}[0]{status} =
                  'HTTP/1.1 208 Already Reported';
            }
        }
        push @{$resps_ref}, \%response;
    }
    return
         if exists ${$visited}{$nfn}
      && !$noroot
      && ( $depth eq 'infinity' || $depth < 0 );
    ${$visited}{$nfn} = 1;
    if ( $depth != 0 && $is_readable && $backend->isDir($nfn) ) {
        if ( !defined $FILECOUNTPERDIRLIMIT{$fn}
            || $FILECOUNTPERDIRLIMIT{$fn} > 0 )
        {
            foreach my $f (
                @{
                    $backend->readDir( $fn, get_file_limit($fn),
                        \&FileUtils::filter )
                }
              )
            {
                my $fru = $ru . CGI::escape($f);
                $is_readable = $backend->isReadable("$nfn/$f");
                my $nnfn =
                  $is_readable ? $backend->resolve("$nfn/$f") : "$nfn/$f";
                $fru .=
                     $is_readable
                  && $backend->isDir($nnfn)
                  && $fru !~ /\/$/xms ? q{/} : q{};
                $self->read_dir_recursive( $nnfn, $fru, $resps_ref, $props,
                    $all, $noval, $depth > 0 ? $depth - 1 : $depth,
                    0, $visited );
            }
        }
    }
    return;
}

sub get_property_module {
    my ($self) = @_;
    my $cache  = $self->{cache};
    my $pm     = $cache->get_entry('propertymodule');
    if ( !$pm ) {
        require WebDAV::Properties;
        $pm = WebDAV::Properties->new( $self->{config} );
        $cache->set_entry( 'propertymodule', $pm );
    }
    return $pm;
}
1;
