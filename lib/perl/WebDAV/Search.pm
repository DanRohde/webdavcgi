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

package WebDAV::Search;

use strict;
use warnings;

our $VERSION = '2.0';

use CGI::Carp;
use Date::Parse;
use List::MoreUtils qw( any );
use English qw ( -no_match_vars );

use FileUtils;
use CacheManager;

use base qw( WebDAV::Common );

use vars qw( %SEARCH_PROPTYPES %SEARCH_SPECIALCONV %SEARCH_SPECIALOPS );

BEGIN {

    %SEARCH_PROPTYPES = (
        default                                                   => 'string',
        '{DAV:}getlastmodified'                                   => 'dateTime',
        '{DAV:}lastaccessed'                                      => 'dateTime',
        '{DAV:}getcontentlength'                                  => 'int',
        '{DAV:}creationdate'                                      => 'dateTime',
        '{urn:schemas-microsoft-com:}Win32CreationTime'           => 'dateTime',
        '{urn:schemas-microsoft-com:}Win32LastAccessTime'         => 'dateTime',
        '{urn:schemas-microsoft-com:}Win32LastModifiedTime'       => 'dateTime',
        '{DAV:}childcount'                                        => 'int',
        '{DAV:}objectcount'                                       => 'int',
        '{DAV:}visiblecount'                                      => 'int',
        '{DAV:}acl'                                               => 'xml',
        '{DAV:}acl-restrictions'                                  => 'xml',
        '{urn:ietf:params:xml:ns:carddav}addressbook-home-set'    => 'xml',
        '{urn:ietf:params:xml:ns:caldav}calendar-home-set'        => 'xml',
        '{DAV:}current-user-principal}'                           => 'xml',
        '{DAV:}current-user-privilege-set'                        => 'xml',
        '{DAV:}group'                                             => 'xml',
        '{DAV:}owner'                                             => 'xml',
        '{urn:ietf:params:xml:ns:carddav}principal-address'       => 'xml',
        '{DAV:}principal-collection-set'                          => 'xml',
        '{DAV:}principal-URL'                                     => 'xml',
        '{DAV:}resourcetype'                                      => 'xml',
        '{urn:ietf:params:xml:ns:caldav}schedule-calendar-transp' => 'xml',
        '{urn:ietf:params:xml:ns:caldav}schedule-inbox-URL'       => 'xml',
        '{urn:ietf:params:xml:ns:caldav}schedule-outbox-URL'      => 'xml',
        '{DAV:}source'                                            => 'xml',
        '{urn:ietf:params:xml:ns:carddav}supported-address-data'  => 'xml',
        '{urn:ietf:params:xml:ns:caldav}supported-calendar-component-set' =>
          'xml',
        '{urn:ietf:params:xml:ns:caldav}supported-calendar-data' => 'xml',
        '{DAV:}supported-method-set'                             => 'xml',
        '{DAV:}supported-privilege-set'                          => 'xml',
        '{DAV:}supported-report-set'                             => 'xml',
        '{DAV:}supportedlock'                                    => 'xml',
    );
    %SEARCH_SPECIALCONV = ( dateTime => 'str2time', xml => 'xml2str' );
    %SEARCH_SPECIALOPS = (
        int => {
            eq  => q{==},
            gt  => q{>},
            lt  => q{<},
            gte => q{>=},
            lte => q{<=},
            cmp => q{<=>},
        },
        dateTime => {
            eq  => q{==},
            gt  => q{>},
            lt  => q{<},
            gte => q{>=},
            lte => q{<=},
            cmp => q{<=>},
        },
        string => { lte => 'le', gte => 'ge' },
    );

}

sub new {
    my $this  = shift;
    my $class = ref($this) || $this;
    my $self  = {};
    bless $self, $class;
    $self->{config} = shift;
    $self->{cache}  = CacheManager::getinstance();
    $self->initialize();
    return $self;
}

sub get_schema_discovery {
    my ( $self, $ru, $resps ) = @_;
    push @{$resps},
      {
        href           => $ru,
        status         => '207 Multistatus',
        'query-schema' => {
            basicsearchschema => {
                properties => {
                    propdesc => [
                        {
                            'any-other-property' => undef,
                            searchable           => undef,
                            selectable           => undef,
                            caseless             => undef,
                            sortable             => undef
                        }
                    ]
                },
                operators => {
                    'opdesc allow-pcdata="yes"' => [
                        {
                            like               => undef,
                            'operand-property' => undef,
                            'operand-literal'  => undef
                        },
                        { contains => undef }
                    ]
                }
            }
        }
      };
    return $resps;
}

sub _handle_expr_array {
    my ( $self, $xmlref, $op, $superop ) = @_;
    my $expr = q{};
    foreach my $oo ( @{$xmlref} ) {
        my ( $ne, $nt ) =
          $self->_build_expr_from_basic_search_where_clause( $op, $oo,
            $superop );
        my ( $nes, $nts ) =
          $self->_build_expr_from_basic_search_where_clause( $superop,
            undef, $superop );
        $expr .= $expr ne q{} ? $nes : q{};
        $expr .= "($ne)";
    }
    return $expr;

}

sub _build_expr_from_basic_search_where_clause {
    my ( $self, $op, $xmlref, $superop ) = @_;
    my ( $expr, $type ) = ( q{}, q{} );
    my $ns = '{DAV:}';
    if ( !defined $op ) {
        my @ops = keys %{$xmlref};
        return $self->_build_expr_from_basic_search_where_clause( $ops[0],
            ${$xmlref}{ $ops[0] } );
    }

    $op =~ s/\Q$ns\E//xms;
    $type = 'bool';

    if ( ref($xmlref) eq 'ARRAY' ) {
        return $self->_handle_expr_array( $xmlref, $op, $superop );
    }

    study $op;
    if ( $op =~ /^(and|or)$/xms ) {
        if ( ref($xmlref) eq 'HASH' ) {
            foreach my $o ( keys %{$xmlref} ) {
                if ( $expr ne q{} ) { $expr .= $op eq 'and' ? ' && ' : ' || '; }
                my ( $ne, $nt ) =
                  $self->_build_expr_from_basic_search_where_clause( $o,
                    ${$xmlref}{$o}, $op );
                $expr .= "($ne)";
            }
        }
        else {
            return $op eq 'and' ? ' && ' : ' || ';
        }
    }
    elsif ( $op eq 'not' ) {
        my @k = keys %{$xmlref};
        my ( $ne, $nt ) =
          $self->_build_expr_from_basic_search_where_clause( $k[0],
            ${$xmlref}{ $k[0] } );
        $expr = "!($ne)";
    }
    elsif ( $op eq 'is-collection' ) {
        $expr =
q{get_prop_value($self,'{DAV:}iscollection',$filename,$request_uri)==1};
    }
    elsif ( $op eq 'is-defined' ) {
        my ( $ne, $nt ) =
          $self->_build_expr_from_basic_search_where_clause( '{DAV:}prop',
            ${$xmlref}{'{DAV:}prop'} );
        $expr = "$ne ne '__undef__'";
    }
    elsif ( $op =~ /^(language-defined|language-matches)$/xms ) {
        $expr = '0!=0';
    }
    elsif ( $op =~ /^(eq|lt|gt|lte|gte)$/xms ) {
        my $o = $op;
        my ( $ne1, $nt1 ) =
          $self->_build_expr_from_basic_search_where_clause( '{DAV:}prop',
            ${$xmlref}{'{DAV:}prop'} );
        my ( $ne2, $nt2 ) =
          $self->_build_expr_from_basic_search_where_clause( '{DAV:}literal',
            ${$xmlref}{'{DAV:}literal'} );
        $ne2 =~ s/'/\\'/xmsg;
        $ne2 =
            $SEARCH_SPECIALCONV{$nt1}
          ? $SEARCH_SPECIALCONV{$nt1} . "('$ne2')"
          : "'$ne2'";
        my $cl =
          ${$xmlref}{'caseless'} || ${$xmlref}{'{DAV:}caseless'} || 'yes';
        $expr =
            ( ( $nt1 =~ /(string|xml)/xms && $cl ne 'no' ) ? "lc($ne1)" : $ne1 )
          . q{ }
          . ( $SEARCH_SPECIALOPS{$nt1}{$o} || $o ) . q{ }
          . (
            ( $nt1 =~ /(string|xml)/xms && $cl ne 'no' )
            ? "lc($ne2)"
            : $ne2
          );
    }
    elsif ( $op eq 'like' ) {
        my ( $ne1, $nt1 ) =
          $self->_build_expr_from_basic_search_where_clause( '{DAV:}prop',
            ${$xmlref}{'{DAV:}prop'} );
        my ( $ne2, $nt2 ) =
          $self->_build_expr_from_basic_search_where_clause( '{DAV:}literal',
            ${$xmlref}{'{DAV:}literal'} );
        $ne2 =~ s/\//\\\//xmgs;        ## quote slashes
        $ne2 =~ s/(?<!\\)_/./xmgs;     ## handle unescaped wildcard _ -> .
        $ne2 =~ s/(?<!\\)%/.*/xmgs;    ## handle unescaped wildcard % -> .*
        my $cl =
          ${$xmlref}{'caseless'} || ${$xmlref}{'{DAV:}caseless'} || 'yes';
        $expr = "$ne1 =~ /$ne2/s" . ( $cl eq 'no' ? q{} : 'i' );
    }
    elsif ( $op eq 'contains' ) {
        my $content = ref($xmlref) eq q{} ? $xmlref : ${$xmlref}{content};
        my $cl =
          ref($xmlref) eq q{}
          ? 'yes'
          : ( ${$xmlref}{caseless} || ${$xmlref}{'{DAV:}caseless'} || 'yes' );
        $content =~ s/\//\\\//xmsg;
        $expr =
"\Q${$self}{backend}\E->getFileContent(\$filename) =~ /\\Q$content\\E/s"
          . ( $cl eq 'no' ? q{} : 'i' );
    }
    elsif ( $op eq 'prop' ) {
        my @props = keys %{$xmlref};
        $props[0] =~ s/'/\\'/xmsg;
        $expr = "get_prop_value(\$self,'$props[0]',\$filename,\$request_uri)";
        $type = $SEARCH_PROPTYPES{ $props[0] }
          || $SEARCH_PROPTYPES{default};
        if ( exists $SEARCH_SPECIALCONV{$type} ) {
            $expr = $SEARCH_SPECIALCONV{$type} . "($expr)";
        }

    }
    elsif ( $op eq 'literal' ) {
        $expr = ref($xmlref) ne q{} ? xml2str($xmlref) : $xmlref;
        $type = $op;
    }
    else {
        $expr = $xmlref;
        $type = $op;
    }

    return ( $expr, $type );
}

sub get_prop_value {
    my ( $self, $prop, $fn, $uri ) = @_;
    my ( %r200, %r404 );

    if ( ${$self}{cache}->exists_entry( [ $fn, $prop ] ) ) {
        return ${$self}{cache}->get_entry( [ $fn, $prop ] );
    }

    my $propname = $prop;
    $propname =~ s/^{[^}]*}//xms;

    my $propval =
      !any { /^\Q$propname\E$/xms }
    @main::PROTECTED_PROPS
      ? ${$self}{db}->db_getProperty( $fn, $prop )
      : undef;

    if ( !defined $propval ) {
        main::getPropertyModule()
          ->get_property( $fn, $uri, $propname, undef, \%r200, \%r404 );
        $propval = $r200{prop}{$propname};
    }

    $propval //= '__undef__';

    return ${$self}{cache}->set_entry( [ $fn, $prop ], $propval );
}

sub xml2str {
    my ($xml) = @_;
    return defined $xml ? lc( main::create_xml( $xml, 1 ) ) : $xml;
}

sub _do_basic_search {
    my ( $self, $expr, $base, $href, $depth, $limit, $matches, $visited ) = @_;
    return if defined $limit && $limit > 0 && $#{$matches} + 1 >= $limit;

    return if defined $depth && $depth ne 'infinity' && $depth < 0;

    $base .= ${$self}{backend}->isDir($base) && $base !~ /\/$/xms ? q{/} : q{};
    $href .= ${$self}{backend}->isDir($base) && $href !~ /\/$/xms ? q{/} : q{};

    my $filename    = $base;
    my $request_uri = $href;

    my $res = eval $expr;
    if ($EVAL_ERROR) {
        carp("_do_basic_search: problem in $expr: $EVAL_ERROR");
    }
    elsif ($res) {
        push @{$matches}, { fn => $base, href => $href };
    }
    my $_nbase = ${$self}{backend}->resolve($base);
    return
      if exists ${$visited}{$_nbase} && ( $depth eq 'infinity' || $depth < 0 );
    ${$visited}{$_nbase} = 1;

    if (   ${$self}{backend}->isDir($base)
        && ${$self}{backend}->isReadable($base) )
    {
        foreach my $sf (
            @{
                ${$self}{backend}->readDir( $base, main::getFileLimit($base),
                    \&FileUtils::filter )
            }
          )
        {
            my $nbase = $base . $sf;
            my $nhref = $href . $sf;
            $self->_do_basic_search(
                $expr,
                $base . $sf,
                $href . $sf,
                defined $depth && $depth ne 'infinity' ? $depth - 1 : $depth,
                $limit, $matches, $visited
            );
        }
    }
    return;
}

sub _build_sort_func {
    my ( $self, $xmldata, $matchcount ) = @_;
    my $sortfunc = q{};
    if ( exists ${$xmldata}{'{DAV:}orderby'} && $matchcount > 0 ) {
        my @orders;
        if ( ref( ${$xmldata}{'{DAV:}orderby'}{'{DAV:}order'} ) eq 'ARRAY' ) {
            push @orders, @{ ${$xmldata}{'{DAV:}orderby'}{'{DAV:}order'} };
        }
        elsif ( ref( ${$xmldata}{'{DAV:}orderby'}{'{DAV:}order'} ) eq 'HASH' ) {
            push @orders, ${$xmldata}{'{DAV:}orderby'}{'{DAV:}order'};
        }
        foreach my $order (@orders) {
            my @props    = keys %{ ${$order}{'{DAV:}prop'} };
            my $prop     = $props[0] || '{DAV:}displayname';
            my $proptype = $SEARCH_PROPTYPES{$prop}
              || $SEARCH_PROPTYPES{default};
            my $collation =
              ${$order}{'{DAV:}descending'} ? 'descending' : 'ascending';
            my ( $ta, $tb, $cmp );
            $ta = "get_prop_value(\$self,'$prop',\$\$a{fn},\$\$a{href})";
            $tb = "get_prop_value(\$self,'$prop',\$\$b{fn},\$\$b{href})";
            if ( $SEARCH_SPECIALCONV{$proptype} ) {
                $ta = $SEARCH_SPECIALCONV{$proptype} . "($ta)";
                $tb = $SEARCH_SPECIALCONV{$proptype} . "($tb)";
            }
            $cmp = $SEARCH_SPECIALOPS{$proptype}{cmp} || 'cmp';
            $sortfunc .= $sortfunc ne q{}           ? q{ || }        : q{};
            $sortfunc .= $collation eq 'ascending'  ? "$ta $cmp $tb" : q{};
            $sortfunc .= $collation eq 'descending' ? "$tb $cmp $ta" : q{};
        }
    }
    if ( $sortfunc eq q{} ) { $sortfunc = 'return $$a{fn} cmp $$b{fn} '; }
    return $sortfunc;
}

sub handle_basic_search {
    my ( $self, $xmldata, $resps, $error ) = @_;

    # select > (allprop | prop)
    my ( $propsref, $all, $noval ) =
      main::handlePropFindElement( ${$xmldata}{'{DAV:}select'} );

    # where > op > (prop,literal)
    my ( $expr, $type ) =
      $self->_build_expr_from_basic_search_where_clause( undef,
        ${$xmldata}{'{DAV:}where'} );

    # from > scope+ > (href, depth, include-versions?)
    my @scopes;
    if ( ref( ${$xmldata}{'{DAV:}from'}{'{DAV:}scope'} ) eq 'HASH' ) {
        push @scopes, ${$xmldata}{'{DAV:}from'}{'{DAV:}scope'};
    }
    elsif ( ref( ${$xmldata}{'{DAV:}from'}{'{DAV:}scope'} ) eq 'ARRAY' ) {
        push @scopes, @{ ${$xmldata}{'{DAV:}from'}{'{DAV:}scope'} };
    }
    else {
        push @scopes,
          {
            '{DAV:}href'  => $main::REQUEST_URI,
            '{DAV:}depth' => 'infinity'
          };
    }

    # limit > nresults
    my $limit = ${$xmldata}{'{DAV:}limit'}{'{DAV:}nresults'};

    my $host = ${$self}{cgi}->http('Host');
    my @matches;
    foreach my $scope (@scopes) {
        my $depth = ${$scope}{'{DAV:}depth'};
        my $href  = ${$scope}{'{DAV:}href'};
        my $base  = $href;
        $base =~
          s{^(https?://([^\@]+\@)?\Q$host\E(:\d+)?)?$main::VIRTUAL_BASE}{}xms;
        $base = $main::DOCUMENT_ROOT
          . main::uri_unescape( main::uri_unescape($base) );

        if ( !${$self}{backend}->exists($base) ) {
            push @{$error},
              {
                'search-scope-valid' => {
                    response =>
                      { href => $href, status => 'HTTP/1.1 404 Not Found' }
                }
              };
            return;
        }
        $self->_do_basic_search( $expr, $base, $href, $depth, $limit,
            \@matches );
    }

   # orderby > order+ (caseless=(yes|no))> (prop|score), (ascending|descending)?
    my $sortfunc = $self->_build_sort_func( $xmldata, $#matches );
    foreach my $match ( sort { eval $sortfunc } @matches ) {
        push @{$resps},
          {
            href     => ${$match}{href},
            propstat => main::getPropStat(
                ${$match}{fn}, ${$match}{href}, $propsref, $all, $noval
            )
          };
    }
    return;
}

1;
