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
# disable_fileaction - disables fileaction entry
# disable_fileactionpopup - disables fileaction entry in popup menu
# enable_apps - enables sidebar menu entry
# disable_binarydownload - sets the right MIME type 
# 

package WebInterface::Extension::Download;

use strict;

use base qw( WebInterface::Extension  );

use FileUtils qw( is_hidden );

sub init { 
	my($self, $hookreg) = @_; 
	
	$self->setExtension('Download');
	
	my @hooks = ('css','locales','javascript');
	push @hooks,'fileaction' unless $main::EXTENSION_CONFIG{Download}{disable_fileaction};
	push @hooks,'fileactionpopup' unless $main::EXTENSION_CONFIG{Download}{disable_fileactionpopup};
	push @hooks,'apps' if $main::EXTENSION_CONFIG{Download}{enable_apps};
	push @hooks,'gethandler' unless $main::EXTENSION_CONFIG{Download}{disable_binarydownload};
	$hookreg->register(\@hooks, $self);
}

sub handle { 
	my ($self, $hook, $config, $params) = @_;
	my $ret = $self->SUPER::handle($hook, $config, $params);
	return $ret if $ret;
	
	my $add_classes = $main::EXTENSION_CONFIG{Download}{disable_binarydownload} ? 'disablebinarydownload' : '';
	if ($hook eq 'fileaction') {
		$ret = { action=>'dwnload',label=>'dwnload', path=>$$params{path}, classes=>'access-readable is-file '.$add_classes};
	} elsif ($hook eq 'fileactionpopup') {
		$ret = { accesskey=>'s', action=>'dwnload', label=>'dwnload', path=>$$params{path}, type=>'li', classes=>$add_classes};	
	} elsif ($hook eq 'apps') {
		$ret = $self->handleAppsHook($$self{cgi},'listaction dwnload sel-one sel-file disabled '.$add_classes,'dwnload','dwnload'); 		
	} elsif ($hook eq 'gethandler' && $$self{cgi}->param('action') eq 'dwnload') {
		my $fn = $$self{cgi}->param('file');
		my $file = $main::PATH_TRANSLATED.$fn;
		if ( $$self{backend}->exists($file) && !is_hidden($file) ) {
			if (!$$self{backend}->isReadable($file)) {
				main::print_header_and_content(main::get_error_document('403 Forbidden','text/plain', '403 Forbidden'));
			} else {
				my $qfn = $fn;
				$qfn=~s/"/\\"/gs;
				main::print_file_header($file, {-Content_Disposition=>'attachment; filename="'.$qfn.'"', -type=>'application/octet-stream'});
				$$self{backend}->printFile($file,\*STDOUT);
			}
		} else {
			main::print_header_and_content(main::get_error_document('404 Not Found','text/plain','404 - FILE NOT FOUND'));
		}
		$ret = 1;
	}
	return $ret;
}

1;