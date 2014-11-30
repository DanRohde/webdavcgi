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
#   hidegroups - sets a list of groups to hide (default: ['ExifTool'])

package WebInterface::Extension::ImageInfo;

use strict;

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension  );

use Image::ExifTool;

sub init { 
	my($self, $hookreg) = @_; 
	my @hooks = ('css','locales','javascript', 'posthandler', 'fileactionpopup','fileattr');
	$hookreg->register(\@hooks, $self);
	
	my %ig = map { $_=>1 } @{$self->config('hidegroups', ['ExifTool'])};
	$$self{hidegroups} = \%ig;
}
sub handle { 
	my ($self, $hook, $config, $params) = @_;
	my $ret = $self->SUPER::handle($hook, $config, $params);
	return $ret if $ret;
	
	if ($hook eq 'fileattr') {
		$ret = { ext_classes => $$self{backend}->isReadable($$params{path}) && main::getMIMEType($$params{path}) =~ /^(image|video)\//i ? 'imageinfo-show' : 'imageinfo-hide' };
	} elsif ($hook eq 'fileactionpopup') {
		$ret = { action=>'imageinfo', disabled=>!$$self{backend}->isReadable($main::PATH_TRANSLATED), label=>'imageinfo', type=>'li'};
	} elsif ($hook eq 'posthandler') {
		my $file = $$self{cgi}->param('file');
		main::printHeaderAndContent('200 OK','text/html', $self->renderImageInfo($file, $self->getImageInfo($$self{backend}->getLocalFilename($main::PATH_TRANSLATED.$file))));
		$ret=1;	
	}
	 
	return $ret;
}
sub renderImageInfo {
	my ($self, $file, $ii) = @_;
	my $c = $$self{cgi};
	
	my $pt = $main::PATH_TRANSLATED;
	my $ru = $main::REQUEST_URI;
	
	my $tmppath = $$ii{_tmppath_};
	my $tmpfile = $$self{backend}->basename($tmppath);
	my $tmpdir = $$self{backend}->dirname($tmppath);
	
	my $dialogtmpl = $self->readTemplate('imageinfo');
	my $groupcontenttmpl = $self->readTemplate('groupcontent');
	my $grouptmpl = $self->readTemplate('group');
	my $proptmpl = $self->readTemplate('prop');
	
	my $groups ="";
	my $groupcontent = "";
	
	foreach my $gr ( @{$$ii{_groups_}}) {
		next if $$self{hidegroups}{$gr};
		$groups.= $self->renderTemplate($pt, $ru, $grouptmpl, { group=>$gr});
		my $props = "";
		foreach my $pr (sort keys %{$$ii{$gr}}) {
			my $val = $$ii{$gr}{$pr};
			$val=~s/\Q$tmpfile\E/$file/g;
			$val=~s/\Q$tmpdir\E/$main::REQUEST_URI/g;
			$props.= $self->renderTemplate($pt, $ru, $proptmpl, { propname=>$c->escapeHTML($pr), propvalue=>$c->escapeHTML($val)});
		}
		$groupcontent .= $self->renderTemplate($pt, $ru, $groupcontenttmpl, { group=>$gr, props => $props })
	}
	
	return $self->renderTemplate($pt, $ru, $dialogtmpl, { dialogtitle=> sprintf($self->tl('imageinfo.dialogtitle'), $c->escapeHTML($file)), groups=>$groups, groupcontent=>$groupcontent});
}
sub getImageInfo {
	my ($self, $file) = @_;
	my %ret = (_tmppath_ => $file);
	my $et = new Image::ExifTool();
	$et->Options(Unknown=>1, Charset=>'UTF8');
	my $info = $et->ImageInfo($file);
	my $group = '';
	foreach my $tag ($et->GetFoundTags('Group0')) {
		if ($et->GetGroup($tag) ne $group) {
			$group = $et->GetGroup($tag);
			push @{$ret{_groups_}}, $group;
		} 
		my $val = $$info{$tag};
		if (ref $val eq 'SCALAR') {
			if ($$val =~ /^Binary data/) {
				$val = "($$val)";	
			} else {
				my $len = length($$val);
				$val = "(Binary data $len bytes)";
			}
		}
		$ret{$group}{$et->GetDescription($tag)} = $val;
	}
	return \%ret;
}
1;