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

#use JSON;

use DefaultConfig qw( $PATH_TRANSLATED $REQUEST_URI );
use HTTPHelper qw( print_compressed_header_and_content );

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = qw(
      css         locales javascript fileactionpopup
      posthandler appsmenu
    );
    $hookreg->register( \@hooks, $self );

    $self->{suffixes} = [qw(
      bsh  c   cc   cpp  cs csh  css   cyc
      cv   htm html java js json m     mxml
      perl pl  pm   py   rb sh   xhtml xml
      xsl
    )];

    $self->{sizelimit} = $self->config( 'sizelimit', 2_097_152 );
    return $self;
}

sub _get_file_suffix {
    my ( $self, $fn ) = @_;
    return $fn =~ /[.]([^.]+)$/xms ? $1 : q{};
}

sub handle_hook_appsmenu {
    my ($self, $config, $params) = @_;
    return {
        action => 'scv',
        label => 'scv',
        classes=> 'sel-one-suffix access-readable hideit',
        data =>  { suffix => q{^(?:}.join(q{|}, @{$self->{suffixes}}).q{)$}  },
    };
}
sub handle_hook_fileactionpopup {
    my ($self) = @_;
    return $self->handle_hook_appsmenu();
}

sub handle_hook_posthandler {
    my ( $self, $config, $params ) = @_;
    if (   $self->{cgi}->param('action')
        && $self->{cgi}->param('action') eq 'scv' )
    {
        my $file = $self->{cgi}->param('files');
        if ( ( $self->{backend}->stat("$PATH_TRANSLATED$file") )[7] >
            $self->{sizelimit} )
        {
            require JSON;
            print_compressed_header_and_content(
                '200 OK',
                'application/json',
                JSON->new()->encode(
                    {
                        error => sprintf $self->tl('scvsizelimitexceeded'),
                        $self->{cgi}->escapeHTML($file),
                        $self->render_byte_val( $self->{sizelimit} )
                    }
                )
            );
        }
        print_compressed_header_and_content(
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
        return 1;
    }
    return 0;
}

1;
