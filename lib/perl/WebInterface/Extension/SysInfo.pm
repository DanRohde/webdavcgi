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

use WebInterface::Renderer;

our @ISA = qw( WebInterface::Renderer );

sub new {
        my $this = shift;
        my $class = ref($this) || $this;
        my $self = { };
        bless $self, $class;
	$self->init(shift);
        return $self;
}

sub init { 
	my ($self, $hookreg) = @_; 
	$hookreg->register('gethandler', $self);
}

sub handle { 
	my ($self, $hook, $config) = @_; 
	my $handled = 0;
	$$self{cgi} = $$config{cgi};

	if ($hook eq 'gethandler' && $$self{cgi}->request_uri() =~ /\/sysinfo.html$/) {
		$self->renderSysInfo();
		$handled = 1;
	}

	return $handled; 
}
sub renderSysInfo {
        my $self = shift;
        my $i = "";
        $i.= $self->start_html("$main::TITLEPREFIX SysInfo");

        $i.= $$self{cgi}->h1('WebDAV CGI SysInfo');
        $i.= $$self{cgi}->h2('Process - '.$0);
        $i.= $$self{cgi}->start_table()
             .$$self{cgi}->Tr($$self{cgi}->td('BASETIME').$$self{cgi}->td(''.localtime($^T)))
             .$$self{cgi}->Tr($$self{cgi}->td('OSNAME').$$self{cgi}->td($^O))
             .$$self{cgi}->Tr($$self{cgi}->td('PID').$$self{cgi}->td($$))
             .$$self{cgi}->Tr($$self{cgi}->td('REAL UID').$$self{cgi}->td($<))
             .$$self{cgi}->Tr($$self{cgi}->td('EFFECTIVE UID').$$self{cgi}->td($>))
             .$$self{cgi}->Tr($$self{cgi}->td('REAL GID').$$self{cgi}->td($())
             .$$self{cgi}->Tr($$self{cgi}->td('EFFECTIVE GID').$$self{cgi}->td($)))

             .$$self{cgi}->end_table();
        $i.= $$self{cgi}->h2('Perl');
        $i.= $$self{cgi}->start_table()
                .$$self{cgi}->Tr($$self{cgi}->td('version').$$self{cgi}->td(sprintf('%vd',$^V)))
                .$$self{cgi}->Tr($$self{cgi}->td('debugging').$$self{cgi}->td($^D))
                .$$self{cgi}->Tr($$self{cgi}->td('taint mode').$$self{cgi}->td(${^TAINT}))
                .$$self{cgi}->Tr($$self{cgi}->td('unicode').$$self{cgi}->td(${^UNICODE}))
                .$$self{cgi}->Tr($$self{cgi}->td('warning').$$self{cgi}->td($^W))
                .$$self{cgi}->Tr($$self{cgi}->td('executable name').$$self{cgi}->td($^X))
                .$$self{cgi}->end_table();
        $i.= $$self{cgi}->h2('Perl Variables');
        $i.= $$self{cgi}->start_table()
                .$$self{cgi}->Tr($$self{cgi}->td('@INC').$$self{cgi}->td(join(" ",@INC)))
                .$$self{cgi}->end_table();

        $i.= $$self{cgi}->h2('Includes');
        $i.= $$self{cgi}->start_table();
        foreach my $e (sort keys %INC) {
                $i.=$$self{cgi}->Tr($$self{cgi}->td($e).$$self{cgi}->td($ENV{$e}));
        }
        $i.= $$self{cgi}->end_table();

        $i.= $$self{cgi}->h2('System Times');
        my ($user,$system,$cuser,$csystem) = times;
        $i.=  $$self{cgi}->start_table()
             .$$self{cgi}->Tr($$self{cgi}->td('user (s)').$$self{cgi}->td($user))
             .$$self{cgi}->Tr($$self{cgi}->td('system (s)').$$self{cgi}->td($system))
             .$$self{cgi}->Tr($$self{cgi}->td('cuser (s)').$$self{cgi}->td($cuser))
             .$$self{cgi}->Tr($$self{cgi}->td('csystem (s)').$$self{cgi}->td($csystem))
             .$$self{cgi}->end_table();
        $i.= $$self{cgi}->h2('Environment');
        $i.= $$self{cgi}->start_table();
        foreach my $e (sort keys %ENV) {
                $i.=$$self{cgi}->Tr($$self{cgi}->td($e).$$self{cgi}->td($ENV{$e}));
        }
        $i.= $$self{cgi}->end_table();

        $i.=$$self{cgi}->end_html();

        main::printHeaderAndContent('200 OK', 'text/html', $i);
}

1;
