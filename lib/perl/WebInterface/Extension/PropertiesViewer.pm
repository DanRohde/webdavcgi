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

package WebInterface::Extension::PropertiesViewer;

use strict;
use warnings;
our $VERSION = '2.0';

use base 'WebInterface::Extension';

use DefaultConfig
  qw( $ENABLE_THUMBNAIL $PATH_TRANSLATED $REQUEST_URI $SIGNATURE $THUMBNAIL_WIDTH $TITLEPREFIX );
use HTTPHelper
  qw( get_mime_type print_compressed_header_and_content get_parent_uri get_base_uri_frag );
use WebDAV::XMLHelper
  qw( create_xml nonamespace get_namespace_uri %NAMESPACEELEMENTS );
use WebDAV::Properties;
use WebDAV::WebDAVProps
  qw( @KNOWN_COLL_PROPS @KNOWN_FILE_PROPS init_webdav_props );

sub init {
    my ( $self, $hookreg ) = @_;
    $hookreg->register(
        [qw(javascript css posthandler fileaction fileactionpopup appsmenu)],
        $self
    );
    init_webdav_props();
    return $self;
}

sub handle_hook_posthandler {
    my ( $self, $config, $params ) = @_;
    if (   $self->{cgi}->param('action')
        && $self->{cgi}->param('action') eq 'props' )
    {
        return $self->_render_viewer(
            $PATH_TRANSLATED . $self->{cgi}->param('file'),
            $REQUEST_URI . $self->{cgi}->param('file')
        );
    }
    return 0;
}
sub handle_hook_appsmenu {
    my ( $self, $config, $params ) = @_;
    return {
        action => 'props',
        classes => 'access-readable sel-one hideit  info-icon',
        label => $self->tl('showproperties'),
        type => 'li',
    };
}
sub handle_hook_fileaction {
    my ( $self, $config, $params ) = @_;
    return {
        action   => 'props',
        classes  => ' info-icon',
        disabled => !$self->{backend}->isReadable( $params->{path} ),
        label    => 'showproperties',
        path     => $params->{path},
        type => 'li',
    };
}

sub handle_hook_fileactionpopup {
    my ( $self, $config, $params ) = @_;
    return {
        action   => 'props',
        disabled => !$self->{backend}->isReadable( $params->{path} ),
        label    => 'showproperties',
        path     => $params->{path},
        type     => 'li',
        classes  => 'sel-noneorone action  info-icon'
    };
}

sub _render_viewer {
    my ( $self, $fn, $ru ) = @_;
    $self->set_locale();
    my $content    = q{};
    my $fullparent = get_parent_uri($ru) . q{/};
    if ( $fullparent eq q{//} || $fullparent eq q{} ) { $fullparent = q{/}; }
    $content .= $self->{cgi}->h2(
        { -class => 'foldername' },
        (
              $self->{backend}->isDir($fn)
            ? $fn
            : $self->{backend}->getParent($fn) . q{/} . q{ }
              . $self->{cgi}->a( { -href => $ru }, get_base_uri_frag($ru) )
          )
          . $self->tl('properties')
    );
    $content .=
        $self->has_thumb_support( get_mime_type($fn) )
      ? $self->{cgi}->br()
      . $self->{cgi}->a(
        { href => $ru, title => $self->tl('clickforfullsize') },
        $self->{cgi}->img(
            {
                -src => $ru . ( $ENABLE_THUMBNAIL ? '?action=thumb' : q{} ),
                -alt => 'image',
                -class => 'thumb',
                -style => 'width:'
                  . ( $ENABLE_THUMBNAIL ? $THUMBNAIL_WIDTH : 200 )
            }
        )
      )
      : q{};
    my $table = $self->{cgi}->start_table( { -class => 'props' } );
    local %NAMESPACEELEMENTS = %NAMESPACEELEMENTS;
    my $dbprops =
      $self->{db}->db_getProperties( $self->{backend}->resolveVirt($fn) );
    my @bgstyleclasses = qw( tr_odd tr_even );
    my (%visited);
    $table .= $self->{cgi}->Tr(
        { -class => 'trhead' },
        $self->{cgi}->th( { -class => 'thname' },  $self->tl('propertyname') ),
        $self->{cgi}->th( { -class => 'thvalue' }, $self->tl('propertyvalue') )
    );
    my $pm = WebDAV::Properties->new( $self->{config} );

    foreach my $prop (
        sort { nonamespace( lc $a ) cmp nonamespace( lc $b ) }
        keys %{$dbprops},
        $self->{backend}->isDir($fn)
        ? @KNOWN_COLL_PROPS
        : @KNOWN_FILE_PROPS
      )
    {
        my (%r200);
        next
          if exists $visited{$prop}
          || exists $visited{ '{' . get_namespace_uri($prop) . '}' . $prop };
        if ( exists $dbprops->{$prop} ) {
            $r200{prop}{$prop} = $dbprops->{$prop};
        }
        else {
            $pm->get_property( $fn, $ru, $prop, undef, \%r200, \my %r404 );
        }
        $visited{$prop} = 1;
        $NAMESPACEELEMENTS{ nonamespace($prop) } = 1;
        my $title = create_xml( $r200{prop},        1 );
        my $value = create_xml( $r200{prop}{$prop}, 1 );
        my $namespace = get_namespace_uri($prop);
        if ( $prop =~ /^[{]([^}]*)[}]/xms ) {
            $namespace = $1;
        }
        push @bgstyleclasses, shift @bgstyleclasses;
        $table .= $self->{cgi}->Tr(
            { -class => $bgstyleclasses[0] },
            $self->{cgi}->td( { -title => $namespace, -class => 'tdname' },
                nonamespace($prop) )
              . $self->{cgi}->td(
                { -title => $title, -class => 'tdvalue' },
                $self->{cgi}->pre( $self->{cgi}->escapeHTML($value) )
              )
        );
    }
    $table .= $self->{cgi}->end_table();
    $content .=
      $self->{cgi}->div( { -class => 'props content' }, $table );
    $content .=
      defined $SIGNATURE
      ? $self->{cgi}->hr()
      . $self->{cgi}
      ->div( { -class => 'signature' }, $self->replace_vars($SIGNATURE) )
      : q{};
    $content =
      $self->{cgi}
      ->div( { -title => "$TITLEPREFIX $ru properties", -class => 'props' },
        $content );
    print_compressed_header_and_content( '200 OK', 'text/html', $content,
        'Cache-Control: no-cache, no-store' );
    return 1;
}
sub free {
    my ($self) = @_;
    WebDAVProps::free();
    return $self->SUPER::free();
}
1;
