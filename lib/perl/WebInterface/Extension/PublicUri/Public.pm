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

package WebInterface::Extension::PublicUri::Public;

use strict;
use warnings;
our $VERSION = '2.0';

use base qw( WebInterface::Extension::PublicUri::Common );

use Digest::MD5 qw(md5 md5_hex md5_base64);

use DefaultConfig
  qw( $DOCUMENT_ROOT $PATH_TRANSLATED $REQUEST_URI $VIRTUAL_BASE );
use HTTPHelper qw( print_header_and_content print_file_header );
use FileUtils qw( get_error_document );

sub init {
    my ( $self, $hookreg ) = @_;

    $hookreg->register( [ 'posthandler', 'gethandler' ], $self );

    $self->init_defaults();
    return $self;
}

sub handle {
    my ( $self, $hook, $config, $params ) = @_;
    $self->SUPER::handle( $hook, $config, $params );
    if ( $hook eq 'posthandler' ) {
        return $self->handle_public_uri_access()
          if $self->{cgi}->param('action') =~ /$self->{allowedpostactions}/xms;
        print_header_and_content( get_error_document('404 Not Found') );
        return 1;
    }
    elsif ( $hook eq 'gethandler' ) {
        return $self->handle_public_uri_access();
    }
    return 0;    #not handled
}

sub handle_public_uri_access {
    my ($self) = @_;
    if ( $PATH_TRANSLATED =~ /^$DOCUMENT_ROOT([^\/]+)(.*)?$/xms ) {
        my ( $code, $path ) = ( $1, $2 );
        my $fn = $self->get_file_from_code($code);
        if ( !$fn || !$self->is_public_uri( $fn, $code, $self->get_seed($fn) ) )
        {
            print_header_and_content( get_error_document('404 Not Found') );
            return 1;
        }

        $DOCUMENT_ROOT = $fn;
        $DOCUMENT_ROOT .= $DOCUMENT_ROOT !~ /\/$/xms ? q{/} : q{};
        $PATH_TRANSLATED = $fn . $path;
        $VIRTUAL_BASE    = $self->{virtualbase} . $code . q{/?};

        if ( $self->{backend}->isDir($PATH_TRANSLATED) ) {
            $PATH_TRANSLATED .= $PATH_TRANSLATED !~ /\/$/xms ? q{/} : q{};
            $REQUEST_URI     .= $REQUEST_URI !~ /\/$/xms     ? q{/} : q{};
        }
        elsif (( !$path || $path eq q{} )
            && ( $self->{backend}->isReadable($fn) ) )
        {
            my $bfn = $self->{backend}->basename($fn);
            $bfn =~ s/"/_/xmsg;
            print_file_header(
                $fn,
                {
                    'Content-Disposition' =>
                      sprintf 'attachment; filename="%s"',
                    $bfn
                }
            );
            $self->{backend}->printFile( $fn, \*STDOUT );
            return 1;
        }

        return 0;
    }
    else {
        print_header_and_content( get_error_document('404 Not Found') )
          ;
        return 1;
    }
}

1;
