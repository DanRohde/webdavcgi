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

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension  );

use JSON;

sub init { 
	my($self, $hookreg) = @_; 
	my @hooks = ('css','locales','javascript','fileactionpopup','posthandler','fileattr');
	$hookreg->register(\@hooks, $self);
	
	my %sf = map { $_ => 1 } ( "bsh", "c", "cc", "cpp", "cs", "csh", "css", "cyc", "cv", "htm", "html", "java", "js", "m", "mxml", "perl", "pl", "pm", "py", "rb", "sh","xhtml", "xml", "xsl" );
	$$self{supportedsuffixes} = \%sf;
	$$self{sizelimit} = $self->config('sizelimit', 2097152);
	$$self{json} = new JSON();
}
sub getFileSuffix {
	my ($self,$fn) = @_;
	if ($fn=~/\.([^\.]+)$/) {
		return $1;
	}
	return '';
}
sub handle { 
	my ($self, $hook, $config, $params) = @_;
	my $ret = $self->SUPER::handle($hook, $config, $params);
	return $ret if $ret;
	if ($hook eq 'fileactionpopup') {
		return { action=>'scv', disabled=>!$$self{backend}->isReadable($main::PATH_TRANSLATED), label=>'scv', type=>'li'};
	} elsif ($hook eq 'fileattr' && $$self{backend}->isFile($$params{path})) {
		$ret = {ext_classes=> $$self{supportedsuffixes}{$self->getFileSuffix($$params{path})} ? 'scv-source' : 'scv-nosource'} ;
	} elsif ($hook eq 'posthandler' && $$self{cgi}->param('action') eq 'scv') {
		my $file = $$self{cgi}->param('files');
		if ( ($$self{backend}->stat("$main::PATH_TRANSLATED$file"))[7] > $$self{sizelimit}) {
			main::printHeaderAndContent('200 OK', 'application/json', $$self{json}->encode({ error=>sprintf($self->tl('scvsizelimitexceeded'), $$self{cgi}->escapeHTML($file), $self->renderByteValue($$self{sizelimit}))}));
		} elsif ($$self{supportedsuffixes}{$self->getFileSuffix($file)}) {
			main::printHeaderAndContent('200 OK', 'text/html',$self->renderTemplate($main::PATH_TRANSLATED,$main::REQUEST_URI, 
							$self->readTemplate('sourcecodeviewer'), { suffix=>$self->getFileSuffix($file), content=>$$self{cgi}->escapeHTML($$self{backend}->getFileContent("$main::PATH_TRANSLATED$file")) }));
		} else {
			main::printHeaderAndContent('200 OK', 'application/json', $$self{json}->encode({ error=>$self->tl('scvunsupportedfiletype') }));
		}
		$ret = 1;
	}
	return $ret;
}

1;