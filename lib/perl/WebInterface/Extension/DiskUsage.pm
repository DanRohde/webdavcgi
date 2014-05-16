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
# disable_app - disables sidebar menu entry
# 

package WebInterface::Extension::DiskUsage;

use strict;

use WebInterface::Extension;
use WebInterface::Renderer;
our @ISA = qw( WebInterface::Extension WebInterface::Renderer );

sub new {
        my $this = shift;
        my $class = ref($this) || $this;
        my $self = { };
        bless $self, $class;
        $self->init(shift);
        return $self;
}

sub init { 
	my($self, $hookreg) = @_; 
	$hookreg->register('fileaction', $self) unless $main::EXTENSION_CONFIG{DiskUsage}{disable_fileaction};
	$hookreg->register('fileactionpopup', $self) unless $main::EXTENSION_CONFIG{DiskUsage}{disable_fileactionpopup};
	$hookreg->register('css', $self);
	$hookreg->register('javascript', $self);
	$hookreg->register('locales', $self);
	$hookreg->register('posthandler', $self);
	$hookreg->register('apps', $self) unless $main::EXTENSION_CONFIG{DiskUsage}{disable_app};
}

sub handle { 
	my ($self, $hook, $config, $params) = @_;
	$$self{cgi} = $$config{cgi};
	$$self{backend}=$$config{backend};
	$$self{config}=$config;
	$self->initialize(); ## Common::initialize to set correct LANG, ...
	$self->setLocale(); ## Common:setLocale to set right locale
	
	if ($hook eq 'fileaction') {
		return { action=>'diskusage', disabled=>!$$self{backend}->isDir($$params{path})||!$$self{backend}->isReadable($$params{path}), label=>'du_diskusage', path=>$$params{path}};
	} elsif( $hook eq 'fileactionpopup') {
		return { action=>'diskusage', disabled=>!$$self{backend}->isDir($$params{path})||!$$self{backend}->isReadable($$params{path}), label=>'du_diskusage', path=>$$params{path}, type=>'li', classes=>'listaction sel-noneormulti sel-dir' };
	} elsif ($hook eq 'apps') {
		return $$self{cgi}->li({-title=>$self->tl('du_diskusage')},$$self{cgi}->a({-class=>'action listaction diskusage sel-nonormulti sel-dir disabled', -href=>'#'},$self->tl('du_diskusage_short')));
	} elsif ( $hook eq 'css' ) {
		return q@<link rel="stylesheet" type="text/css" href="@.$self->getExtensionUri('DiskUsage','htdocs/style.min.css').q@">@;
	} elsif ( $hook eq 'javascript' ) {
		return q@<script src="@.$self->getExtensionUri('DiskUsage','htdocs/script.min.js').q@"></script>@;
	} elsif ( $hook eq 'locales') {
		return $self->getExtensionLocation('DiskUsage','locale/locale');
	} elsif ( $hook eq 'posthandler' && $$config{cgi}->param('action') eq 'diskusage') {
		my $text =""; 
		my $completedu = 0;
		my $statfstring = sprintf('%s %%d, %s %%d, %s %%d',$self->tl('statfiles'),$self->tl('statfolders'),$self->tl('statsum'));
		
		foreach my $file ($$config{cgi}->param('file')) {
			my ($dudetails, $fcdetails) = ({},{});
			my $du = $self->getDiskUsage($main::PATH_TRANSLATED,$file,$dudetails,$fcdetails);
			my @bv = $self->renderByteValue($du);
			my $label = sprintf($self->tl('du_diskusagefor'), $file eq '' ? '.' : $file);
			my $dutext = "$label: " . $$self{cgi}->span({-title=>$bv[1]},$bv[0]);
			my $fullstat = sprintf($statfstring, $$fcdetails{'//__STAT__//'}{files}, $$fcdetails{'//__STAT__//'}{folders}, $$fcdetails{'//__STAT__//'}{sum});	
			$completedu+=$du;
		
			if (keys %{$dudetails} > 0) {
				my $details = "";
				$details .= $$self{cgi}->div($fullstat); 
				$details .= $$self{cgi}->start_table({-class=>'diskusage details'});
				$details .= $$self{cgi}->Tr({},$$self{cgi}->th({-class=>'diskusage filename'},$self->tl('name')).$$self{cgi}->th({-class=>'diskusage size',-title=>$bv[1]},$self->tl('size')));
				foreach my $p (sort { $$dudetails{$b} <=> $$dudetails{$a} || $b cmp $a } keys %{$dudetails}) {
					my @pbv = $self->renderByteValue($$dudetails{$p});
					my $perc =  $du > 0 ? 100*$$dudetails{$p}/$du : 0;
					$details.=$$self{cgi}->Tr({-class=>'diskusage entry'}, 
						$$self{cgi}->td({-class=>'diskusage filename',-title=>sprintf('%.2f%%, '.$statfstring,$perc,$$fcdetails{$p}{files},$$fcdetails{$p}{folders},$$fcdetails{$p}{sum})},
							$$self{cgi}->div({-class=>'diskusage perc',-style=>sprintf('width: %.0f%%;',$perc)},
								$$self{cgi}->a({-class=>'action changeuri',-href=>$self->getURI($p)},$$self{cgi}->escapeHTML($p))))
						.$$self{cgi}->td({-title=>$pbv[1], -class=>'diskusage size'}, $pbv[0]));
				}
				$details.=$$self{cgi}->end_table();
				$dutext.=$$self{cgi}->div({-class=>'diskusage accordion'}, $$self{cgi}->h3($self->tl('du_details')).$$self{cgi}->div($details));
			} else {
				$dutext .= $$self{cgi}->div( $fullstat );
			}
			$text .= $$self{cgi}->div($dutext);
		}
		my $content=$$self{cgi}->div({-title=>$self->tl('du_diskusage').': '.($self->renderByteValue($completedu))[0]},$text);
		main::printCompressedHeaderAndContent('200 OK', 'text/html', $content, 'Cache-Control: no-cache, no-store');
		return 1;
	}
	return 0; 
}
sub getURI { 
	my ($self, $relpath) = @_;
	return $main::REQUEST_URI.join('/',map({ $$self{cgi}->escape($_) } split(/\//,$relpath)));
}
sub getDiskUsage {
	my ($self,$path,$file,$sizes,$fcounts) = @_;
	my $backend = $$self{backend};
	my $size = 0;
	foreach my $f (@{$$self{backend}->readDir("$path$file")}) {
		my $nf = "$file$f";
		my $np = "$path$nf";
		if ($backend->isDir($np)&&!$backend->isLink($np)) {
			$nf.='/';
			$$sizes{$nf}=$self->getDiskUsage($path,$nf,$sizes,$fcounts); ## + ($backend->stat("$path$nf"))[7]; # folders have sometimes a size but is not relevant
			$size+=$$sizes{$nf};
			$$fcounts{$file}{folders}++;
			$$fcounts{'//__STAT__//'}{folders}++;
		} else {
			$size+=($backend->stat($np))[7];
			$$fcounts{$file}{files}++;
			$$fcounts{'//__STAT__//'}{files}++;
		}
		$$fcounts{$file}{sum}++;
		$$fcounts{'//__STAT__//'}{sum}++;
	}
	return $size;
}
1;