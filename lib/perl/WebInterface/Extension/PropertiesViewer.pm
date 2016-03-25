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

use base 'WebInterface::Extension';

use WebDAV::XMLHelper ( create_xml );

sub init {
    my ( $self, $hookreg ) = @_;
    $self->setExtension('PropertiesViewer');
    $hookreg->register(
        [   'javascript',  'css',
            'posthandler', 'fileaction',
            'fileactionpopup'
        ],
        $self
    );
}

sub handle {
    my ( $self, $hook, $config, $params ) = @_;
    my $ret = $self->SUPER::handle( $hook, $config, $params );
    return $ret if $ret;
    if ( $hook eq 'posthandler' && $$self{cgi}->param('action') eq 'props' ) {
        $ret = $self->renderPropertiesViewer(
            $main::PATH_TRANSLATED . $$self{cgi}->param('file'),
            $main::REQUEST_URI . $$self{cgi}->param('file')
        );
    }
    elsif ( $hook eq 'fileaction' ) {
        $ret = {
            action   => 'props',
            disabled => !$$self{backend}->isReadable( $$params{path} ),
            label    => 'showproperties',
            path     => $$params{path}
        };
    }
    elsif ( $hook eq 'fileactionpopup' ) {
        $ret = {
            action   => 'props',
            disabled => !$$self{backend}->isReadable( $$params{path} ),
            label    => 'showproperties',
            path     => $$params{path},
            type     => 'li',
            classes  => 'sel-noneorone listaction'
        };
    }
    return $ret;
}

sub renderPropertiesViewer {
    my ( $self, $fn, $ru ) = @_;
    $self->set_locale();
    my $content    = "";
    my $fullparent = main::getParentURI($ru) . '/';
    $fullparent = '/' if $fullparent eq '//' || $fullparent eq '';
    $content .= $$self{cgi}->h2(
        { -class => 'foldername' },
        (     $$self{backend}->isDir($fn)
            ? $fn
            : $$self{backend}->getParent($fn) . '/' . ' '
                . $$self{cgi}
                ->a( { -href => $ru }, main::getBaseURIFrag($ru) )
            )
            . $self->tl('properties')
    );
    $content .= $$self{cgi}->br()
        . $$self{cgi}->a(
        { href => $ru, title => $self->tl('clickforfullsize') },
        $$self{cgi}->img(
            {   -src => $ru
                    . ( $main::ENABLE_THUMBNAIL ? '?action=thumb' : '' ),
                -alt   => 'image',
                -class => 'thumb',
                -style => 'width:'
                    . (
                    $main::ENABLE_THUMBNAIL ? $main::THUMBNAIL_WIDTH : 200
                    )
            }
        )
        ) if $self->has_thumb_support( main::get_mime_type($fn) );
    my $table = $$self{cgi}->start_table( { -class => 'props' } );
    local (%WebDAV::XMLHelper::NAMESPACEELEMENTS) = %WebDAV::XMLHelper::NAMESPACEELEMENTS;
    my $dbprops
        = $$self{db}->db_getProperties( $$self{backend}->resolveVirt($fn) );
    my @bgstyleclasses = ( 'tr_odd', 'tr_even' );
    my (%visited);
    $table .= $$self{cgi}->Tr(
        { -class => 'trhead' },
        $$self{cgi}->th( { -class => 'thname' },  $self->tl('propertyname') ),
        $$self{cgi}->th( { -class => 'thvalue' }, $self->tl('propertyvalue') )
    );

    foreach my $prop (
        sort { main::nonamespace( lc($a) ) cmp main::nonamespace( lc($b) ) }
        keys %{$dbprops},
        $$self{backend}->isDir($fn)
        ? @main::KNOWN_COLL_PROPS
        : @main::KNOWN_FILE_PROPS
        )
    {
        my (%r200);
        next
            if exists $visited{$prop}
            || exists $visited{ '{'
                . main::get_namespace_uri($prop) . '}'
                . $prop };
        if ( exists $$dbprops{$prop} ) {
            $r200{prop}{$prop} = $$dbprops{$prop};
        }
        else {
            main::getPropertyModule()
                ->get_property( $fn, $ru, $prop, undef, \%r200, \my %r404 );
        }
        $visited{$prop} = 1;
        $WebDAV::XMLHelper::NAMESPACEELEMENTS{ main::nonamespace($prop) } = 1;
        my $title = create_xml( $r200{prop},        1 );
        my $value = create_xml( $r200{prop}{$prop}, 1 );
        my $namespace = main::get_namespace_uri($prop);
        if ( $prop =~ /^\{([^\}]*)\}/xms ) {
            $namespace = $1;
        }
        push @bgstyleclasses, shift @bgstyleclasses;
        $table .= $$self{cgi}->Tr(
            { -class => $bgstyleclasses[0] },
            $$self{cgi}->td( { -title => $namespace, -class => 'tdname' },
                main::nonamespace($prop) )
                . $$self{cgi}->td(
                { -title => $title, -class => 'tdvalue' },
                $$self{cgi}->pre( $$self{cgi}->escapeHTML($value) )
                )
        );
    }
    $table   .= $$self{cgi}->end_table();
    $content .= $$self{cgi}->div( { -class => "props content" }, $table );
    $content .= $$self{cgi}->hr()
        . $$self{cgi}->div( { -class => 'signature' },
        $self->replace_vars($main::SIGNATURE) )
        if defined $main::SIGNATURE;
    $content = $$self{cgi}->div(
        { -title => "$main::TITLEPREFIX $ru properties", -class => 'props' },
        $content
    );
    main::print_compressed_header_and_content( '200 OK', 'text/html', $content,
        'Cache-Control: no-cache, no-store' );
    return 1;
}
1;
