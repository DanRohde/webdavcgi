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

package WebInterface::Extension::SysInfo;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( WebInterface::Extension );

use English qw( -no_match_vars ) ;


use DefaultConfig qw{ $TITLEPREFIX };
use HTTPHelper qw( print_header_and_content );

sub init {
    my ( $self, $hookreg ) = @_;
    $hookreg->register( [qw( gethandler apps)], $self );
    return $self;
}

sub handle {
    my ( $self, $hook, $config, $params ) = @_;
    my $handled = $self->SUPER::handle( $hook, $config, $params );
    my $cgi = $self->{cgi};

    if ( $hook eq 'gethandler' && $cgi->request_uri() =~ /\/sysinfo.html$/xms )
    {
        $self->render_sys_info();
        $handled = 1;
    }
    elsif ( $hook eq 'apps' ) {
        return $cgi->li(
            { -title => $self->tl('SysInfo') },
            $cgi->a(
                { -class => 'action sysinfo', -href => 'sysinfo.html' },
                $self->tl('SysInfo')
            )
        );
    }

    return $handled;
}

sub render_sys_info {
    my ($self) = @_;
    my $i    = q{};


    require Data::Dumper;

    my $cgi = $self->{cgi};

    $i .= $cgi->start_html("$TITLEPREFIX SysInfo");

    $i .= $cgi->h1('WebDAV CGI SysInfo');
    $i .= $cgi->h2( 'Process - ' . $PROGRAM_NAME );
    $i .=
        $cgi->start_table()
      . $cgi->Tr( $cgi->td('BASETIME') . $cgi->td( q{} . localtime $BASETIME) )
      . $cgi->Tr( $cgi->td('OSNAME') . $cgi->td($OSNAME) )
      . $cgi->Tr( $cgi->td('PID') . $cgi->td($PID) )
      . $cgi->Tr( $cgi->td('REAL UID') . $cgi->td($UID) )
      . $cgi->Tr( $cgi->td('EFFECTIVE UID') . $cgi->td($EUID) )
      . $cgi->Tr( $cgi->td('REAL GID') . $cgi->td($GID) )
      . $cgi->Tr( $cgi->td('EFFECTIVE GID') . $cgi->td($EGID) )

      . $cgi->end_table();
    $i .= $cgi->h2('Perl');
    $i .=
        $cgi->start_table()
      . $cgi->Tr( $cgi->td('version') . $cgi->td( sprintf '%vd', $PERL_VERSION ) )
      . $cgi->Tr( $cgi->td('debugging') . $cgi->td($DEBUGGING) )
      . $cgi->Tr( $cgi->td('warning') . $cgi->td($WARNING) )
      . $cgi->Tr( $cgi->td('executable name') . $cgi->td($EXECUTABLE_NAME) )
      . $cgi->end_table();
    $i .= $cgi->h2('Perl Variables');
    $i .=
        $cgi->start_table()
      . $cgi->Tr( $cgi->td('INC') . $cgi->td( join q{ }, @INC ) )
      . $cgi->end_table();

    $i .= $cgi->h2('Includes');
    $i .= $cgi->start_table();
    foreach my $e ( sort keys %INC ) {
        $i .= $cgi->Tr( $cgi->td($e) . $cgi->td( $ENV{$e} ) );
    }
    $i .= $cgi->end_table();

    $i .= $cgi->h2('System Times');
    my ( $user, $system, $cuser, $csystem ) = times;
    $i .=
        $cgi->start_table()
      . $cgi->Tr( $cgi->td('user (s)') . $cgi->td($user) )
      . $cgi->Tr( $cgi->td('system (s)') . $cgi->td($system) )
      . $cgi->Tr( $cgi->td('cuser (s)') . $cgi->td($cuser) )
      . $cgi->Tr( $cgi->td('csystem (s)') . $cgi->td($csystem) )
      . $cgi->end_table();
    $i .= $cgi->h2('Environment');
    $i .= $cgi->start_table();
    foreach my $e ( sort keys %ENV ) {
        $i .= $cgi->Tr( $cgi->td($e) . $cgi->td( $ENV{$e} ) );
    }
    $i .= $cgi->end_table();

    $i .= $cgi->h2('WebDAV CGI setup') . $cgi->start_table();
    foreach my $cfg ( sort keys %DefaultConfig:: ) {
        my $val = $DefaultConfig::{$cfg};
        if ( $val !~ /DefaultConfig::/xms  || $cfg =~ /^(?:ARG|DBI_PASS|CGI|EXPORT_OK|EXPORT_TAGS|cgi|_.*)$/xms ) {
            next;
        }
        if (defined ${$val} ) {
            $i .= $cgi->Tr( $cgi->td($cfg) . $cgi->td( ${$val} ) );
        } elsif (@{$val}) {
            $i .= $cgi->Tr( $cgi->td($cfg) . $cgi->td( Data::Dumper::Dumper(\@{$val}) ) );
        } elsif (%{$val}) {
            $i .= $cgi->Tr( $cgi->td($cfg) . $cgi->td( Data::Dumper::Dumper(\%{$val}) ) );
        }
    }
    $i .= $cgi->end_table();

    $i .= $cgi->end_html();

    return print_header_and_content( '200 OK', 'text/html', $i );
}

1;
