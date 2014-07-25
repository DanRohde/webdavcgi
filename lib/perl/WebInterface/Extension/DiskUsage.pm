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
# disable_apps - disables sidebar menu entry
# 

package WebInterface::Extension::DiskUsage;

use strict;

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension  );

use JSON;

sub init { 
	my($self, $hookreg) = @_; 
	my @hooks = ('css','javascript','locales','posthandler');
	push @hooks,'fileaction' unless $main::EXTENSION_CONFIG{DiskUsage}{disable_fileaction};
	push @hooks,'fileactionpopup' unless $main::EXTENSION_CONFIG{DiskUsage}{disable_fileactionpopup};
	push @hooks,'apps' unless $main::EXTENSION_CONFIG{DiskUsage}{disable_apps};
	$hookreg->register(\@hooks, $self);
}

sub handle { 
	my ($self, $hook, $config, $params) = @_;

	my $suret = $self->SUPER::handle($hook, $config, $params);
	
	if ($hook eq 'javascript') {
		$suret .= q@<script src="@.$self->getExtensionUri('DiskUsage', 'htdocs/contrib/jquery.ui.treemap.min.js').q@"></script>@;	
	}
	return $suret if $suret;
	
	if ($hook eq 'fileaction') {
		return { action=>'diskusage', disabled=>!$$self{backend}->isDir($$params{path})||!$$self{backend}->isReadable($$params{path}), label=>'du_diskusage', path=>$$params{path}};
	} elsif( $hook eq 'fileactionpopup') {
		return { action=>'diskusage', disabled=>!$$self{backend}->isDir($$params{path})||!$$self{backend}->isReadable($$params{path}), label=>'du_diskusage', path=>$$params{path}, type=>'li', classes=>'listaction sel-noneormulti sel-dir' };
	} elsif ($hook eq 'apps') {
		return $self->handleAppsHook($$self{cgi},'listaction diskusage sel-noneormulti sel-dir disabled','du_diskusage_short','du_diskusage'); 
	} elsif ( $hook eq 'posthandler' && $$config{cgi}->param('action') eq 'diskusage') {
		my $suffixes = {};
		my $content = $self->renderDiskUsage($suffixes);
		main::printCompressedHeaderAndContent('200 OK', 'text/html', $content, 'Cache-Control: no-cache, no-store');
		return 1;
	}
	return 0; 
}
sub gs {
	my ($v) = @_;
	my $r = sprintf('%.2f',$v);
	$r=~s/\,/\./;
	return $r;
}
sub renderDiskUsage {
	my ($self, $suffixes) = @_;
	my $text =""; 
	my $completedu = 0;
	my $statfstring = sprintf('%s %%d, %s %%d, %s %%d',$self->tl('statfiles'),$self->tl('statfolders'),$self->tl('statsum'));
	my $json = new JSON();
	my $cgi = $$self{cgi};
	foreach my $file ($cgi->param('file')) {
		my ($dudetails, $fcdetails) = ({},{});
		my $filename = $file eq '' ? '.' : $file;
		my $du = $self->getDiskUsage($main::PATH_TRANSLATED,$file,$dudetails,$fcdetails,$suffixes);
		my @bv = $self->renderByteValue($du);
		my %mapdata = (  id => $filename, uri=>$cgi->escape($file), size=>[0,0], children=> [ { id=>$filename, uri=>$cgi->escape($file),color=>[1,1], size=>[1,1], children=>[] } ] );
		my $label = sprintf($self->tl('du_diskusagefor'), $filename);
		my $dutext = "$label: " . $cgi->span({-title=>$bv[1]},$bv[0]);
		my $fullstat = sprintf($statfstring, $$fcdetails{$file}{files}, $$fcdetails{$file}{folders}, $$fcdetails{$file}{sum});	
		$completedu+=$du;

		if (keys %{$dudetails} > 0) {
			my $details = "";
			$details .= $cgi->div($fullstat); 
			$details .= $cgi->start_table({-class=>'diskusage details'});
			$details .= $cgi->Tr({},$cgi->th({-class=>'diskusage filename'},$self->tl('name')).$cgi->th({-class=>'diskusage size',-title=>$bv[1]},$self->tl('size')));
			foreach my $p (sort { $$dudetails{$b} <=> $$dudetails{$a} || $b cmp $a } keys %{$dudetails}) {
				my @pbv = $self->renderByteValue($$dudetails{$p});
				my $perc =  $du > 0 ? 100*$$dudetails{$p}/$du : 0;
				my $percsum = $$fcdetails{$file}{sum} >0 ? $$fcdetails{$p}{sum}/$$fcdetails{$file}{sum} : 0;
				my $uri = $self->getURI($p);
				my $title = sprintf('%.2f%%, '.$statfstring,$perc,$$fcdetails{$p}{files},$$fcdetails{$p}{folders},$$fcdetails{$p}{sum});
				
				push @{$mapdata{children}[0]{children}}, { uri=>$uri, title=>$title, val=>$pbv[0], id=>$p, size=>[gs($perc/100),gs($percsum)],color=>[gs($perc/100),gs($percsum)]};
				
				$details.=$cgi->Tr({-class=>'diskusage entry'}, 
					$cgi->td({-class=>'diskusage filename',-title=>$title},
						$cgi->div({-class=>'diskusage perc',-style=>sprintf('width: %.0f%%;',$perc)},
							$cgi->a({-class=>'action changeuri',-href=>$main::REQUEST_URI.$uri},$cgi->escapeHTML($p))))
					.$cgi->td({-title=>$pbv[1], -class=>'diskusage size'}, $pbv[0]));
			}
			$details.=$cgi->end_table();
			$dutext.=$cgi->div({-class=>'diskusage accordion'}, $cgi->h3($self->tl('du_details')).$cgi->div($details));
			
			$dutext.=$cgi->div({-class=>'diskusage treemap accordion'}, $cgi->h3($self->tl('du_treemap')).
					$cgi->div( 
					  $cgi->div({-class=>'treemappanel',-data_mapdata=>$json->encode(\%mapdata)})
					. $cgi->div({-class=>'diskusage treemap switch'},
						 $cgi->div({-class=>'diskusage treemap bysize'},$self->tl('du_treemap_bysize'))
						.$cgi->div({-class=>'diskusage treemap byfilecount'}, $self->tl('du_treemap_byfilecount'))
					))
						);
		} else {
			$dutext .= $cgi->div( $fullstat );
		}
		$text .= $cgi->div($dutext);
	}
	return $cgi->div({-title=>$self->tl('du_diskusage').': '.($self->renderByteValue($completedu))[0]},$text);
}
sub getURI { 
	my ($self, $relpath) = @_;
	return join('/',map({ $$self{cgi}->escape($_) } split(/\//,$relpath)));
}
sub getDiskUsage {
	my ($self,$path,$file,$sizes,$fcounts,$suffixes) = @_;
	my $backend = $$self{backend};
	my $size = 0;
	foreach my $f (@{$$self{backend}->readDir("$path$file")}) {
		my $nf = "$file$f";
		my $np = "$path$nf";
		if ($backend->isDir($np)&&!$backend->isLink($np)) {
			$nf.='/';
			$$sizes{$nf}=$self->getDiskUsage($path,$nf,$sizes,$fcounts,$suffixes); ## + ($backend->stat("$path$nf"))[7]; # folders have sometimes a size but is not relevant
			$size+=$$sizes{$nf};
			$$fcounts{$file}{folders}++;
			$$fcounts{$file}{folders}+=$$fcounts{$nf}{folders};
			$$fcounts{$file}{files}+=$$fcounts{$nf}{files};
			$$fcounts{$file}{sum}+=$$fcounts{$nf}{sum};
		} else {
			my $fsize = ($backend->stat($np))[7];
			$size+=$fsize;
			$$fcounts{$file}{files}++;
			if ($f=~/(\.[^.]+)$/) {
				$$suffixes{count}{$1}++;
				$$suffixes{sizes}{$1}+=$fsize;
			};
		}
		$$fcounts{$file}{sum}++;
	}
	return $size;
}
1;