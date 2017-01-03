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
# sizelimit - file size limit (default: 2097152 (=2MB))
# chunksize - chunk size (bytes in a row, default: 16)

package WebInterface::Extension::HexDump;

use strict;
use warnings;
our $VERSION = '2.0';

use base qw( WebInterface::Extension  );

use CGI::Carp;

use DefaultConfig qw( $PATH_TRANSLATED );
use HTTPHelper qw( print_compressed_header_and_content );

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = qw(css locales javascript posthandler fileactionpopup appsmenu);
    $hookreg->register( \@hooks, $self );

    $self->{sizelimit} = $self->config( 'sizelimit', 2_097_152 );
    $self->{chunksize} = $self->config( 'chunksize', 16 );
    return $self;
}

sub handle_hook_fileactionpopup {
    my ( $self, $config, $params ) = @_;
    return {
        action  => 'hexdump',
        label   => 'hexdump',
        classes => 'access-readable',
        type    => 'li',
    };
}
sub handle_hook_appsmenu {
    my ( $self, $config, $params ) = @_;
    return {
        action  => 'hexdump',
        label   => 'hexdump',
        classes => 'access-readable sel-one sel-file hideit',
        type    => 'li',
    };
}

sub handle_hook_posthandler {
    my ( $self, $config, $params ) = @_;
    my $cgi = $self->{cgi};
    my $action = $cgi->param('action') // q{};
    if ( $action eq 'hexdump' ) {
        my $content = $cgi->div(
            { title => $self->tl('hexdump') },
            $cgi->div(
                { class => 'hexdump filename' },
                $self->quote_ws(
                    $cgi->escapeHTML( scalar $cgi->param('file') )
                )
              )
              . $cgi->pre(
                { class => 'hexdump' },
                $cgi->escapeHTML(
                    $self->_render_hex_dump( scalar $cgi->param('file') )
                )
              )
        );
        print_compressed_header_and_content( '200 OK', 'text/html',
            $content, 'Cache-Control: no-cache, no-store' );
        return 1;
    }
    return 0;
}

sub _render_hex_dump {
    my ( $self, $filename ) = @_;
    my $chunksize = $self->{chunksize};
    my $hexstrlen = $chunksize * 2 + $chunksize / 2 - 1;
    my $content   = q{};
    my $file =
      $self->{backend}->getLocalFilename( $PATH_TRANSLATED . $filename );
    if ( open my $fh, '<', $file ) {
        binmode $fh;
        my $buffer;
        my $counter = 0;
        while ( my $bytesread = read $fh, $buffer, $chunksize ) {
            my @unpacked = unpack "W[$bytesread]", $buffer;
            my $hexmap = join q{}, map { sprintf '%02x', $_ } @unpacked;
            $content .= sprintf
              "\%07x: \%-${hexstrlen}s  \%s\n",
              $counter++ * $chunksize,
              join( q{ }, ( $hexmap =~ /(....)/xmsg ) ),
              join q{},
              map { chr =~ /([[:print:]])/xms ? $1 : q{.} } @unpacked;
            if ( $counter * $chunksize > $self->{sizelimit} ) {
                last;
            }
        }
        close($fh) || carp("Cannot close $filename.");
    }
    return $content;
}

1;
