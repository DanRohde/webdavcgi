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
#
# SETUP:
# supportedsuffixes - list of supported file suffixes (without a dot)
# sizelimit - file size limit (deafult:  2097152 (=2MB))

package WebInterface::Extension::SourceCodeViewer;

use strict;
use warnings;
our $VERSION = '2.0';
use base qw( WebInterface::Extension  );

use JSON;

use DefaultConfig qw( $PATH_TRANSLATED $REQUEST_URI );
use HTTPHelper qw( print_header_and_content );

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = qw(
      css         locales javascript fileactionpopup
      posthandler fileattr
    );
    $hookreg->register( \@hooks, $self );

    my %sf = map { $_ => 1 } qw(
      bsh  c   cc   cpp  cs csh  css   cyc
      cv   htm html java js json m     mxml
      perl pl  pm   py   rb sh   xhtml xml
      xsl
    );
    $self->{supportedsuffixes} = \%sf;
    $self->{sizelimit}         = $self->config( 'sizelimit', 2_097_152 );
    $self->{json}              = JSON->new();
    return $self;
}

sub _get_file_suffix {
    my ( $self, $fn ) = @_;
    if ( $fn =~ /[.]([^.]+)$/xms ) {
        return $1;
    }
    return q{};
}

sub handle {
    my ( $self, $hook, $config, $params ) = @_;
    if ( $hook eq 'fileattr' && $self->{backend}->isFile( $params->{path} ) ) {
        return {
            ext_classes => $self->{supportedsuffixes}
              { $self->_get_file_suffix( $params->{path} ) }
            ? 'scv-source'
            : 'scv-nosource'
        };
    }
    if ( my $ret = $self->SUPER::handle( $hook, $config, $params ) ) {
        return $ret;
    }
    if ( $hook eq 'fileactionpopup' ) {
        return {
            action   => 'scv',
            disabled => !$self->{backend}->isReadable($PATH_TRANSLATED),
            label    => 'scv',
            type     => 'li'
        };
    }
    if ( $hook eq 'posthandler' && $self->{cgi}->param('action') eq 'scv' ) {
        my $file = $self->{cgi}->param('files');
        if ( ( $self->{backend}->stat("$PATH_TRANSLATED$file") )[7] >
            $self->{sizelimit} )
        {
            print_header_and_content(
                '200 OK',
                'application/json',
                $self->{json}->encode(
                    {
                        error => sprintf $self->tl('scvsizelimitexceeded'),
                        $self->{cgi}->escapeHTML($file),
                        $self->render_byte_val( $self->{sizelimit} )
                    }
                )
            );
        }
        if ( $self->{supportedsuffixes}{ $self->_get_file_suffix($file) } ) {
            print_header_and_content(
                '200 OK',
                'text/html',
                $self->render_template(
                    $PATH_TRANSLATED,
                    $REQUEST_URI,
                    $self->read_template('sourcecodeviewer'),
                    {
                        suffix   => $self->_get_file_suffix($file),
                        filename => $self->{cgi}->escapeHTML(
                            $self->{backend}
                              ->getDisplayName( $PATH_TRANSLATED . $file )
                        ),
                        content => $self->{cgi}->escapeHTML(
                            $self->{backend}
                              ->getFileContent("$PATH_TRANSLATED$file")
                        )
                    }
                )
            );
        }
        else {
            print_header_and_content(
                '200 OK',
                'application/json',
                $self->{json}
                  ->encode( { error => $self->tl('scvunsupportedfiletype') } )
            );
        }
        return 1;
    }
    return 0;
}

1;
