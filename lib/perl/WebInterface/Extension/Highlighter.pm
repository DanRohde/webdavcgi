#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2014 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
# Simple CSS highlighting for file list entries
# SETUP:
# namespace - XML namespace for attributes (default: {http://webdavcgi.sf.net/extension/Highlighter/$main::REMOTE_USER})
# attributes - CSS attributes to change for a file list entry

package WebInterface::Extension::Highlighter;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( WebInterface::Extension );

use JSON;

use vars qw(%CACHE);

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks
        = qw(css locales javascript posthandler fileattr fileactionpopup);

    $hookreg->register( \@hooks, $self );

    ${$self}{namespace} = $self->config( 'namespace',
              '{http://webdavcgi.sf.net/extension/Highlighter/'
            . $main::REMOTE_USER
            . '}' );
    ${$self}{attributes} = $self->config(
        'attributes',
        {   'color' => {
                values      => '#FF0000,#008000,#0000FF,#FFA500,#800080',
                labelstyle  => 'background-color',
                colorpicker => 1,
                order       => 2
            },
            'background-color' => {
                values      => '#F08080,#ADFF2f,#ADD8E6,#FFFF00,#DDA0DD',
                labelstyle  => 'background-color',
                colorpicker => 1,
                order       => 1
            },

#'font-weight' => { values=>'lighter,bold,bolder', label=>'highlighter.font-weight', labelstyle=>'font-weight', order=>3 },
        }
    );
    ${$self}{json} = JSON->new();
    return;
}

sub handle {
    my ( $self, $hook, $config, $params ) = @_;
    if ( $hook eq 'fileattr' ) {
        return $self->get_file_attributes($params);
    }
    my $ret = $self->SUPER::handle( $hook, $config, $params );
    if ( $hook eq 'javascript' ) {
        $ret
            .= $self->handleJavascriptHook( 'Highlighter',
            'htdocs/contrib/iris.min.js' );
        return $ret;
    }
    if ( $hook eq 'fileactionpopup' ) {
        my @popups = ();
        foreach my $attribute (
            sort {
                ${$self}{attributes}{$a}{order}
                    <=> ${$self}{attributes}{$b}{order}
            } keys %{ ${$self}{attributes} }
            )
        {
            my @subpopup = map {
                {   action => 'mark',
                    attr   => {
                        style =>
                            "${$self}{attributes}{$attribute}{labelstyle}: $_;"
                    },
                    data  => { value => $_, style => $attribute },
                    label => sprintf(
                        $self->tl( ${$self}{attributes}{$attribute}{label} ),
                        $_
                    ),
                    title => $self->tl( "highlighter.$attribute.$_", $_ ),
                    type  => 'li'
                }
            } split( /,/xms, ${$self}{attributes}{$attribute}{values} );
            if ( ${$self}{attributes}{$attribute}{colorpicker} ) {
                push @subpopup,
                    {
                    action  => 'markcolorpicker',
                    data    => { value => $_, style => $attribute },
                    label   => $self->tl('highlighter.colorpicker'),
                    classes => 'sep',
                    type    => 'li'
                    };
            }
            push @subpopup,
                {
                action  => 'removemark',
                data    => { style => $attribute },
                label   => $self->tl("highlighter.remove.$attribute"),
                type    => 'li',
                classes => 'sep'
                };

            push @popups,
                {
                title        => $self->tl("highlighter.$attribute"),
                subpopupmenu => \@subpopup,
                classes      => "highlighter $attribute"
                };
        }

        $ret = {
            title        => $self->tl('highlighter'),
            subpopupmenu => \@popups,
            classes      => 'highlighter-popup'
        };
    }
    elsif ( $hook eq 'posthandler' ) {
        my $action = ${$self}{cgi}->param('action');
        if ( $action eq 'mark' ) {
            $ret = $self->save_property();
        }
        elsif ( $action eq 'removemark' ) {
            $ret = $self->remove_property();
        }
    }
    return $ret;
}

sub get_file_attributes {
    my ( $self, $params ) = @_;

    my $path   = ${$self}{backend}->resolveVirt( ${$params}{path} );
    my $parent = ${$self}{backend}->getParent($path);
    if ( !exists $CACHE{$self}{$parent} ) {
        ${$self}{db}->db_getProperties($parent);    ## fills the cache
    }
    $CACHE{$self}{$parent} = 1;
    my %jsondata = ();
    foreach my $prop ( keys %{ ${$self}{attributes} } ) {
        if ( my $val
            = ${$self}{db}
            ->db_getPropertyFromCache( $path, ${$self}{namespace} . $prop ) )
        {
            use Data::Dumper;
            print STDERR sprintf ("get_file_attributes: %s:%s\n", $prop, Dumper($val));
            $jsondata{$prop} = $val;
        }
    }

    return scalar( keys %jsondata ) > 0
        ? {
        'ext_classes'    => 'highlighter-highlighted',
        'ext_attributes' => 'data-highlighter="'
            . ${$self}{cgi}
            ->escapeHTML( ${$self}{json}->encode( \%jsondata ) ) . q{"}
        }
        : {};
}

sub remove_property {
    my ($self) = @_;
    my %jsondata = ();
    foreach my $file ( ${$self}{cgi}->param('files') ) {
        ${$self}{db}->db_removeProperty(
            ${$self}{backend}->resolveVirt(
                $main::PATH_TRANSLATED . $self->strip_slash($file)
            ),
            ${$self}{namespace} . ${$self}{cgi}->param('style')
        );
    }

    main::print_compressed_header_and_content(
        '200 OK', 'application/json',
        ${$self}{json}->encode( \%jsondata ),
        'Cache-Control: no-cache, no-store'
    );
    return 1;
}

sub save_property {
    my ($self)   = @_;
    my %jsondata = ();
    my $db       = ${$self}{db};
    my $cgi      = ${$self}{cgi};
    my $style = $cgi->param('style') || 'color';
    my $value = $cgi->param('value') || 'black';
    my $propname = ${$self}{namespace} . $style;

    foreach my $file ( $cgi->param('files') ) {
        my $full = ${$self}{backend}->resolveVirt(
            $main::PATH_TRANSLATED . $self->strip_slash($file) );
        my $result
            = $db->db_getProperty( $full, $propname )
            ? $db->db_updateProperty( $full, $propname, $value )
            : $db->db_insertProperty( $full, $propname, $value );
        if ( !$result ) {
            $jsondata{error}
                = sprintf $self->tl('highlighter.highlightingfailed'),
                $file;
            last;
        }
    }

    main::print_compressed_header_and_content(
        '200 OK', 'application/json',
        ${$self}{json}->encode( \%jsondata ),
        'Cache-Control: no-cache, no-store'
    );
    return 1;
}

sub strip_slash {
    my ( $self, $file ) = @_;
    $file =~ s/\/$//xms;
    return $file;
}
1;
