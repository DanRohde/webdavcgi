#########################################################################
# (C) ssystems, Harald Strack
# Written 2012 by Harald Strack <hstrack@ssystems.de>
# Modified 2013,2014 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package WebInterface::Extension::PublicUri::Private;
use strict;
use warnings;

our $VERSION = '2.0';

use base qw( WebInterface::Extension::PublicUri::Common );

use JSON;

use DefaultConfig qw( $PATH_TRANSLATED $REQUEST_URI );
use HTTPHelper qw( print_compressed_header_and_content );

sub set_public_uri {
    my ( $self, $fn, $code, $seed ) = @_;
    my $rfn = ${$self}{backend}->resolveVirt($fn);
    ${$self}{db}->db_insertProperty( $rfn, $self->get_property_name(), $code );
    ${$self}{db}->db_insertProperty( $rfn, $self->get_seed_name(),     $seed );
    ${$self}{db}->db_insertProperty( $rfn, $self->get_orig_name(),     $fn );
    return;
}

sub get_public_uri {
    my ( $self, $fn ) = @_;
    return ${$self}{db}->db_getProperty( ${$self}{backend}->resolveVirt($fn),
        $self->get_property_name() );
}

sub unset_public_uri {
    my ( $self, $fn ) = @_;
    return ${$self}{db}->db_removeProperty( ${$self}{backend}->resolveVirt($fn),
        $self->get_property_name() )
      && ${$self}{db}->db_removeProperty( $fn, $self->get_seed_name() )
      && ${$self}{db}->db_removeProperty( $fn, $self->get_orig_name() );
}

sub resolve_file {
    my ( $self, $file ) = @_;
    return ${$self}{backend}->resolve( $PATH_TRANSLATED . $file );
}

sub init {
    my ( $self, $hookreg ) = @_;

    $hookreg->register(
        [
            'css',                'javascript',
            'locales',            'templates',
            'fileattr',           'fileactionpopup',
            'posthandler',        'fileaction',
            'fileactionpopupnew', 'fileprop',
            'column',             'columnhead'
        ],
        $self
    );

    $self->init_defaults();

    ${$self}{json} = JSON->new();
    return;
}

sub handle_hook_fileattr {
    my ( $self, $config, $params ) = @_;
    my $prop = $self->get_public_uri( ${$params}{path} );
    my ( $attr, $classes );
    if ( !defined $prop ) {
        ( $classes, $attr ) = qw( unshared no );
    }
    else {
        ( $classes, $attr ) = ( 'shared', $prop );
    }
    return {
        ext_classes    => $classes,
        ext_attributes => sprintf 'data-puri="%s"',
        ${$self}{cgi}->escapeHTML($attr),
    };

}

sub handle_hook_prop {
    my ( $self, $config, $params ) = @_;
    my $publicuridigest = $self->get_public_uri( ${$params}{path} ) || q{};
    my $publicuri =
      ${$self}{cgi}->escapeHTML( ${$self}{uribase} . $publicuridigest );
    return {
        publicuridigest => $publicuridigest,
        publicurititle  => $publicuri,
        publicuri       => $publicuri
    };
}

sub handle_hook_posthandler {
    my ( $self, $config, $params ) = @_;

    #handle actions
    if ( ${$self}{cgi}->param('puri') ) {
        enable_puri($self);
    }
    elsif ( ${$self}{cgi}->param('depuri') ) {
        disable_puri($self);
    }
    elsif ( ${$self}{cgi}->param('spuri') ) {
        show_puri($self);
    }
    else {
        return 0;    #not handled
    }

    return 1;
}

sub handle_hook_fileaction {
    my ( $self, $config, $params ) = @_;
    return [
        {
            action   => 'puri',
            disabled => !${$self}{backend}->isReadable( ${$params}{path} ),
            label    => 'purifilesbutton',
            path     => ${$params}{path}
        },
        {
            action   => 'spuri',
            disabled => !${$self}{backend}->isReadable( ${$params}{path} ),
            label    => 'spurifilesbutton',
            path     => ${$params}{path}
        },
        {
            action   => 'depuri',
            disabled => !${$self}{backend}->isReadable( ${$params}{path} ),
            label    => 'depurifilesbutton',
            path     => ${$params}{path}
        },
    ];

}

sub handle_hook_fileactionpopup {
    my ( $self, $config, $params ) = @_;
    return [
        {
            action   => 'puri',
            disabled => !${$self}{backend}->isReadable( ${$params}{path} ),
            label    => 'purifilesbutton',
            path     => ${$params}{path},
            type     => 'li'
        },
        {
            action   => 'spuri',
            disabled => !${$self}{backend}->isReadable( ${$params}{path} ),
            label    => 'spurifilesbutton',
            path     => ${$params}{path},
            type     => 'li'
        },
        {
            action   => 'depuri',
            disabled => !${$self}{backend}->isReadable( ${$params}{path} ),
            label    => 'depurifilesbutton',
            path     => ${$params}{path},
            type     => 'li'
        },
    ];
}

sub handle_hook_fileactionpopupnew {
    my ( $self, $config, $params ) = @_;
    return {
        action   => 'puri',
        disabled => !${$self}{backend}->isReadable( ${$params}{path} ),
        label    => 'purifilesbutton',
        path     => ${$params}{path},
        type     => 'li'
    };

}

sub handle_hook_templates {
    my ( $self, $config, $params ) = @_;
    return
q{<div id="purifileconfirm"><div class="purifileconfirm">$tl(purifileconfirm)</div></div><div id="depurifileconfirm"><div class="depurifileconfirm">$tl(depurifileconfirm)</div></div>};
}

sub handle_hook_columnhead {
    my ( $self, $config, $params ) = @_;
    return
q{<!--TEMPLATE(publicuri)[<th id="headerPublicUri" data-name="publicuri" data-sort="data-puri" class="dragaccept -hidden">$tl(publicuri)</th>]-->};
}

sub handle_hook_column {
    my ( $self, $config, $params ) = @_;
    return
q{<!--TEMPLATE(publicuri)[<td class="publicuri -hidden"><a href="$publicuri" title="$publicurititle">$publicuridigest</a></td>]-->};
}

sub get_shared_message {
    my ( $self, $file, $url ) = @_;
    return $self->render_template(
        $PATH_TRANSLATED,
        $REQUEST_URI,
        $self->read_template('shared'),
        {
            file => ${$self}{cgi}->escapeHTML($file),
            puri => ${$self}{cgi}->escapeHTML($url)
        }
    );
}

#Publish URI and show message
sub enable_puri {
    my ($self) = @_;
    my %jsondata = ();
    if ( ${$self}{cgi}->param('file') ) {
        my $file   = $self->resolve_file( ${$self}{cgi}->param('file') );
        my $digest = $self->get_public_uri($file);
        my $seed   = $self->get_seed($file);
        if ( !$digest || $self->is_public_uri( $file, $digest, $seed ) ) {
            do {
                ( $digest, $seed ) = $self->gen_url_hash($file);
              } while (
                defined $self->get_file_from_code( ${$self}{prefix} . $digest )
              );
            $self->{config}->{debug}->( 'Creating public URI: ' . $digest );
            $self->unset_public_uri($file);
            $self->set_public_uri( $file, $digest, $seed );
        }
        $jsondata{message} =
          $self->get_shared_message( ${$self}{cgi}->param('file'),
            ${$self}{uribase} . $digest );
    }
    else {
        $jsondata{error} = $self->tl('foldernothingerr');
    }
    print_compressed_header_and_content(
        '200 OK', 'application/json',
        ${$self}{json}->encode( \%jsondata ),
        'Cache-Control: no-cache, no-store'
    );

    return 1;
}

sub show_puri {
    my ($self) = @_;
    my %jsondata = ();
    if ( ${$self}{cgi}->param('file') ) {
        my $file   = $self->resolve_file( ${$self}{cgi}->param('file') );
        my $digest = $self->get_public_uri($file);
        my $seed   = $self->get_seed($file);
        $self->{config}->{debug}->( 'Showing public URI: ' . $digest );
        my $url = ${$self}{cgi}->escapeHTML( ${$self}{uribase} . $digest );
        if ( $digest && $seed && $self->is_public_uri( $file, $digest, $seed ) )
        {
            $jsondata{message} =
              $self->get_shared_message( ${$self}{cgi}->param('file'), $url );
        }
        else {
            $self->disable_puri();
        }
    }
    else {
        $jsondata{error} = $self->tl('foldernothingerr');

    }
    print_compressed_header_and_content(
        '200 OK', 'application/json',
        ${$self}{json}->encode( \%jsondata ),
        'Cache-Control: no-cache, no-store'
    );
    return 1;
}

#Unpublish URI and show message
sub disable_puri {
    my ($self) = @_;
    my %jsondata = ();
    if ( ${$self}{cgi}->param('file') ) {
        my $file = $self->resolve_file( ${$self}{cgi}->param('file') );
        $self->{config}->{debug}->( 'Deleting public URI for file ' . $file );
        $self->unset_public_uri($file);
        $jsondata{message} = sprintf $self->tl('msg_disabledpuri'),
          ${$self}{cgi}->escapeHTML( ${$self}{cgi}->param('file') );
    }
    else {
        $jsondata{error} = $self->tl('foldernothingerr');
    }
    print_compressed_header_and_content(
        '200 OK', 'application/json',
        ${$self}{json}->encode( \%jsondata ),
        'Cache-Control: no-cache, no-store'
    );
    return 1;
}

1;
