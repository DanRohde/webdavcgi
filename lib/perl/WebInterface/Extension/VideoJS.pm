#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2015 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
# disable_fileactionpopup - disables file action entry in popup menu
# disable_fileaction - disables file action
# template - viewerjs template filename 

package WebInterface::Extension::VideoJS;

use strict;

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension  );

use vars qw( $ACTION );

$ACTION='videojs';

sub init { 
	my($self, $hookreg) = @_; 
	my @hooks = ('css','locales','javascript','posthandler');
	push @hooks, 'fileactionpopup' unless $main::EXTENSION_CONFIG{VideoJS}{disable_fileactionpopup};
	push @hooks, 'fileaction' unless $main::EXTENSION_CONFIG{VideoJS}{disable_fileaction};
	$hookreg->register(\@hooks, $self);
}
sub handle { 
	my ($self, $hook, $config, $params) = @_;
	my $ret = 0;
	if ($ret = $self->SUPER::handle($hook, $config, $params)) {
		return $ret;
	} elsif ($hook eq 'fileactionpopup') {
		$ret ={ action=>$ACTION, label=>$ACTION, path=>$$params{path}, type=>'li'};
	} elsif ($hook eq 'fileaction') {
		$ret = { action=>$ACTION, label=>$ACTION, path=>$$params{path}, classes=>'access-readable'};
	} elsif ($hook eq 'posthandler' && $$self{cgi}->param('action') eq 'videojs') {
		$ret = $self->renderViewerJS(scalar $$self{cgi}->param('file'));
	}
	return $ret;
}
sub renderViewerJS {
	my ($self, $filename) =  @_;
	my $vars = { filename => $main::REQUEST_URI.$filename, mime => main::get_mime_type($filename), lang => $main::LANG eq 'default' ? 'en' : $main::LANG };
	my $content = $self->render_template($main::PATH_TRANSLATED,$main::REQUEST_URI,$self->read_template($self->config('template','videojs')), $vars);
	main::print_compressed_header_and_content('200 OK', 'text/html', $content);
	return 1;
}
1;