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
# namespace - XML namespace for attributes (default: {http://webdavcgi.sf.net/extension/Highlighter/$REMOTE_USER})
# attributes - CSS attributes to change for a file list entry

package WebInterface::Extension::Highlighter;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( WebInterface::Extension );

use JSON;

use DefaultConfig qw( $PATH_TRANSLATED $REMOTE_USER );
use HTTPHelper qw( print_compressed_header_and_content );

use vars qw(%_CACHE);

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = qw(css locales javascript posthandler fileattr fileactionpopup);

    $hookreg->register( \@hooks, $self );

    $self->{namespace} = $self->config( 'namespace',
            '{http://webdavcgi.sf.net/extension/Highlighter/'
          . $REMOTE_USER
          . '}' );
    $self->{attributes} = $self->config(
        'attributes',
        {
            'color' => {
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
        }
    );
    $self->{json} = JSON->new();
    return $self;
}


sub handle_hook_javascript {
    my ( $self, $config, $params ) = @_;
    if ( my $ret = $self->SUPER::handle( 'javascript', $config, $params ) ) {
        $ret .= $self->handle_javascript_hook( 'Highlighter',
            'htdocs/contrib/iris.min.js' );

        return $ret;
    }
    return 0;
}

sub handle_hook_posthandler {
    my ( $self, $config, $params ) = @_;
    my $action = $self->{cgi}->param('action') // q{};
    if ( $action eq 'mark' ) {
        return $self->_save_property();
    }
    elsif ( $action eq 'removemark' ) {
        return $self->_remove_property();
    }
    return 0;
}

sub handle_hook_fileactionpopup {
    my ( $self, $config, $params ) = @_;

    my @popups = ();
    foreach my $attribute (
        sort {
            $self->{attributes}{$a}{order} <=> $self->{attributes}{$b}{order}
        } keys %{ $self->{attributes} }
      )
    {
        my @subpopup = map {
            {
                action => 'mark',
                attr   => {
                    style => "$self->{attributes}{$attribute}{labelstyle}: $_;"
                },
                data  => { value => $_, style => $attribute },
                label => sprintf(
                    $self->tl( $self->{attributes}{$attribute}{label} // q{} ),
                    $_
                ),
                title => $self->tl( "highlighter.$attribute.$_", $_ ),
                type  => 'li'
            }
        } split( /,/xms, $self->{attributes}{$attribute}{values} );
        if ( $self->{attributes}{$attribute}{colorpicker} ) {
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

    return {
        title        => $self->tl('highlighter'),
        subpopupmenu => \@popups,
        classes      => 'highlighter-popup'
    };

}

sub handle_hook_fileattr {
    my ( $self, $config, $params ) = @_;

    my $path   = $self->{backend}->resolveVirt( ${$params}{path} );
    my $parent = $self->{backend}->getParent($path);
    if ( !exists $_CACHE{$self}{$parent} ) {
        $self->{db}->db_getProperties($parent);    ## fills the cache
    }
    $_CACHE{$self}{$parent} = 1;
    my %jsondata = ();
    foreach my $prop ( keys %{ $self->{attributes} } ) {
        if ( my $val =
            $self->{db}
            ->db_getPropertyFromCache( $path, $self->{namespace} . $prop ) )
        {
            $jsondata{$prop} = $val;
        }
    }

    return scalar( keys %jsondata ) > 0
      ? {
        'ext_classes'    => 'highlighter-highlighted',
        'ext_attributes' => 'data-highlighter="'
          . $self->{cgi}->escapeHTML( $self->{json}->encode( \%jsondata ) )
          . q{"}
      }
      : {};
}

sub _remove_property {
    my ($self) = @_;
    my %jsondata = ();
    foreach my $file ( $self->get_cgi_multi_param('files') ) {
        $self->{db}->db_removeProperty(
            $self->{backend}
              ->resolveVirt( $PATH_TRANSLATED . $self->_strip_slash($file) ),
            $self->{namespace} . $self->{cgi}->param('style')
        );
    }

    print_compressed_header_and_content(
        '200 OK', 'application/json',
        $self->{json}->encode( \%jsondata ),
        'Cache-Control: no-cache, no-store'
    );
    return 1;
}

sub _save_property {
    my ($self)   = @_;
    my %jsondata = ();
    my $db       = $self->{db};
    my $cgi      = $self->{cgi};
    my $style = $cgi->param('style') || 'color';
    my $value = $cgi->param('value') || 'black';
    my $propname = $self->{namespace} . $style;

    foreach my $file ( $self->get_cgi_multi_param('files') ) {
        my $full = $self->{backend}
          ->resolveVirt( $PATH_TRANSLATED . $self->_strip_slash($file) );
        my $result =
            $db->db_getProperty( $full, $propname )
          ? $db->db_updateProperty( $full, $propname, $value )
          : $db->db_insertProperty( $full, $propname, $value );
        if ( !$result ) {
            $jsondata{error}
              = sprintf $self->tl('highlighter.highlightingfailed'),
              $file;
            last;
        }
    }

    print_compressed_header_and_content(
        '200 OK', 'application/json',
        $self->{json}->encode( \%jsondata ),
        'Cache-Control: no-cache, no-store'
    );
    return 1;
}

sub _strip_slash {
    my ( $self, $file ) = @_;
    $file =~ s/\/$//xms;
    return $file;
}
1;
