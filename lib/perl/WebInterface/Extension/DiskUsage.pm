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
# timeout - timeout in seconds (default: 60)
# filelimit - limits file count for treemap (default: 50)
# folderlimit - limits folder count for details and treemap (default: 50)

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
		#$suret .= q@<script src="@.$self->getExtensionUri('DiskUsage', 'htdocs/contrib/contrib.js').q@"></script>@;
		$suret .= $self->handleJavascriptHook('DiskUsage', 'htdocs/contrib/contrib.js');	
	} elsif ($hook eq 'css') {
		$suret .= $self->handleCssHook('DiskUsage','htdocs/contrib/contrib.css');
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
		my $content = $self->renderDiskUsage();
		main::printCompressedHeaderAndContent('200 OK', 'text/html', $content, 'Cache-Control: no-cache, no-store') if $content;
		return 1;
	}
	return 0; 
}
sub gs {
	my ($v) = @_;
	my $r = sprintf('%.4f',$v);
	$r=~s/\,/\./;
	return $r;
}
sub renderDiskUsage {
	my ($self) = @_;
	my $text =""; 
	my $statfstring = sprintf('%s %%d, %s %%d, %s %%d',$self->tl('statfiles'),$self->tl('statfolders'),$self->tl('statsum'));
	my $json = new JSON();
	my $cgi = $$self{cgi};
	my $counter = { start => time() };
	my %mapdata = (  id => $main::REQUEST_URI, uri=>$cgi->escape($main::REQUEST_URI), children=> [] );
	
	my $cc = 0;
	my $ccst = 1/5;

	
	foreach my $file ($cgi->param('file')) {
		$self->getDiskUsage($main::PATH_TRANSLATED,$file,$counter);		
	}	
	if (time() - $$counter{start} > $self->config('timeout',60)) {
		main::printCompressedHeaderAndContent('200 OK', 'application/json', $json->encode({error=>$cgi->escapeHTML(sprintf($self->tl('du_timeout'),$self->config('timeout',60)))}), 'Cache-Control: no-cache, no-store');
		return;		
	}; 
	# render dialog head:
	my @pbvsum = $self->renderByteValue($$counter{size}{all});
	my $filenamelist = join(', ',$cgi->param('file'));
	$filenamelist='.' if $filenamelist eq "";
	$filenamelist=substr($filenamelist,0,100).'...' if length($filenamelist)>100;
	$text.= $cgi->div({-title=>$pbvsum[1]}, sprintf($self->tl('du_diskusageof'), $filenamelist). ': '.$pbvsum[0])
		.$cgi->div(sprintf($statfstring,$$counter{count}{all}{files},$$counter{count}{all}{folders},$$counter{count}{all}{sum}));
	
	# render detail table
	my $sizeall =$$counter{size}{all};
	my $filecountall = $$counter{count}{all}{files};
	my @folders = sort {$$counter{size}{path}{$b} <=> $$counter{size}{path}{$a} || $a cmp $b} keys %{$$counter{size}{path}};
	
	my $maxfilesizesum = $$counter{size}{allmaxsum};
	# limit folders for view and fix sizeall,filecountall for treemap:
	if ($self->config('folderlimit',50) > 0 && scalar(@folders) > $self->config('folderlimit',50)) {
		splice @folders, $self->config('folderlimit',50);
		$sizeall = 0;
		$filecountall = 0;
		$maxfilesizesum = 0;
		foreach my $folder (@folders) {
			$sizeall+= $$counter{size}{path}{$folder};
			$filecountall+=$$counter{count}{files}{$folder};
			$maxfilesizesum+=$$counter{size}{pathmax}{$folder};
		}
	}
	
	my $table = $cgi->start_table({-class=>'diskusage details'})
			.$cgi->Tr({},$cgi->th({-class=>'diskusage filename'},$self->tl('name')).$cgi->th({-class=>'diskusage size', -title=>($self->renderByteValue($$counter{size}{all}))[1]},$self->tl('size')));
	foreach my $folder (@folders) {
		my $perc = 100*$$counter{size}{path}{$folder}/$$counter{size}{all};
		my $title = sprintf('%.2f%%, '.$statfstring,$perc,$$counter{count}{files}{$folder},$$counter{count}{folders}{$folder},$$counter{count}{sum}{$folder});
		my @pbv = $self->renderByteValue($$counter{size}{path}{$folder});
		my $foldername = $folder;
		$foldername=~s/^\Q$main::PATH_TRANSLATED\E//;
		$foldername='./' if $foldername eq "";
		my $uri = $self->getURI($foldername);
		$table.= $cgi->Tr({-class=>'diskusage entry'},
			$cgi->td({-class=>'diskusage filename',-title=>$title}, 
				$cgi->div({-class=>'diskusage perc',-style=>sprintf('width: %.0f%%;',$perc)},
							$cgi->a({-class=>'action changeuri',-href=>$main::REQUEST_URI.$uri},$cgi->escapeHTML($foldername))))
			.$cgi->td({-title=>$pbv[1], -class=>'diskusage size'}, $pbv[0])
		);
		
		# collect treemap data:
		my $files = $$counter{size}{files}{$folder};
		my @childmapdata = ();
		my $foldersize = $$counter{size}{path}{$folder};
		my @files = sort { $$files{$b} cmp $$files{$a} || $a cmp $b } keys %{$files};
		# limit files for treemap and fix foldersize:
		if ($self->config('filelimit',50)>0 && scalar(@files) > $self->config('filelimit',50)) {
			splice @files, $self->config('filelimit',50);
			$foldersize = 0;
			foreach my $file (@files) { $foldersize+=$$files{$file}; }
		}
		foreach my $file ( @files ) {
			my @pbvfile = $self->renderByteValue($$files{$file});
			my $perc = $foldersize > 0 ? $$files{$file} / $foldersize : 0;
			
			my $uri = $self->getURI($foldername);
			push @childmapdata, { uri=>$uri, title=>"<br/>$foldername: $pbv[0] $title", val=>$pbvfile[0], id=>$file, size=>[gs($perc),gs($perc),gs($perc)],color=>[gs($cc),gs($cc),gs($cc)]};
		}
		my $perccount = $filecountall >0 ? $$counter{count}{files}{$folder} / $filecountall : 0;
		my $percfolder = $sizeall > 0 ? $$counter{size}{path}{$folder}/$sizeall : 0;
		my $percfile  = $maxfilesizesum > 0 ? $$counter{size}{pathmax}{$folder} / $maxfilesizesum : 0;
		push @{$mapdata{children}}, { id=>$foldername, uri=>$uri, color=>[$cc,$cc,$cc], size=>[gs($percfolder), gs($perccount), gs($percfile)], children=>\@childmapdata };
		$cc = ($cc+$ccst >1) ? 0 : $cc+$ccst;
	}
	$table.=$cgi->end_table();
	# render treemap data:
	if (scalar(@{$mapdata{children}})>0) {
		$text.= $cgi->div({-class=>'diskusage accordion'}, $cgi->h3($self->tl('du_details')) . $cgi->div($table));
		$text.=$cgi->div({-class=>'diskusage treemap accordion'}, $cgi->h3($self->tl('du_treemap')).
						$cgi->div( 
						  $cgi->div({-class=>'treemappanel',-data_mapdata=>$json->encode(\%mapdata)})
						. $cgi->div({-class=>'diskusage treemap switch'},
							 $cgi->div({-class=>'diskusage treemap byfoldersize'},$self->tl('du_treemap_byfoldersize'))
							.$cgi->div({-class=>'diskusage treemap byfilesize'},$self->tl('du_treemap_byfilesize'))
							.$cgi->div({-class=>'diskusage treemap byfilecount'}, $self->tl('du_treemap_byfilecount'))
						))
							);
		$text.=$self->renderStatistics($counter, $json);
	}
	
	return $cgi->div({-title=>$self->tl('du_diskusage').': '.($self->renderByteValue($$counter{size}{all}))[0]}, $text);
}
sub renderStatistics {
	my ($self, $counter, $json) = @_;
	my $cgi = $$self{cgi};
	my $content = "";
	my @data;
	
	## suffixes by file size:
	@data = map {[ $_, $$counter{suffixes}{size}{$_} ] } sort { $$counter{suffixes}{size}{$b} <=> $$counter{suffixes}{size}{$a} || $a cmp $b } keys %{$$counter{suffixes}{size}};
	if (scalar(@data)>10) {
		my @deleted = splice @data, 10;
		my $others = 0;
		foreach my $s (@deleted) { $others+= $$s[1]; };
		push @data , [ 'others', $others ];	
	}
	
	$content.=$cgi->div({-class=>'diskusage statistics chart'}, 
					$cgi->div({class=>'diskusage statistics charttitle'},$self->tl('du_suffixesbysize')) 
					.$cgi->div({-class=>'diskusage statistics piechart', -id=>'piechart1-'.time(), -data_json=>$json->encode({data=>\@data})})) if (scalar(@data)>0);

	## suffixes by file count:
	@data = map { [ $_, $$counter{suffixes}{count}{$_} ]} sort { $$counter{suffixes}{count}{$b} <=> $$counter{suffixes}{count}{$a}} keys %{$$counter{suffixes}{count}};
	if (scalar(@data)>10) {
		my @deleted = splice @data, 10;
		my $others = 0;
		foreach my $s (@deleted) { $others+= $$s[1]; };
		push @data , [ 'others', $others ];	
	}
	
	$content.=$cgi->div({-class=>'diskusage statistics chart'}, 
					$cgi->div({class=>'diskusage statistics charttitle'}, $self->tl('du_suffixesbycount')) 
					.$cgi->div({-class=>'diskusage statistics piechart', -id=>'piechart2-'.time(),-data_json=>$json->encode({ data=>\@data})})) if (scalar(@data)>0);
	
	
	return $cgi->div({-class=>'diskusage statistics accordion'}, $cgi->h3($self->tl('du_statistics')).$cgi->div($content));
}
sub getURI { 
	my ($self, $relpath) = @_;
	return join('/',map({ $$self{cgi}->escape($_) } split(/\//,$relpath)));
}

sub getDiskUsage {
	my ($self, $path, $file, $counter) = @_;
	
	my $backend = $$self{backend};
	
	
	$file=~s/^\///;
	
	return if time() - $$counter{start} > $self->config('timeout',60); 
	
	$$counter{count}{all}{sum}++;	
	$$counter{count}{sum}{$path}++;
	$$counter{count}{subdir}{sum}{$path}{$file}++ if $file ne "";
	
	
	my $full = $path.$file;
	if ($backend->isDir($full) && !$backend->isLink($full)) {
		$$counter{count}{all}{folders}++;
		$$counter{count}{folders}{$path}++; 
		
		#$file.='/' unless $file=~/\/$/;
		foreach my $f (@{$backend->readDir($full)}) {
			$f.='/' if $backend->isDir($full.$f);
			$self->getDiskUsage($full,$f,$counter);
		}
	} else {
		my $fs  = ($$self{backend}->stat($path.$file))[7];		
		$$counter{count}{all}{files}++;
		$$counter{count}{files}{$path}++;
		
		$$counter{size}{all}+=$fs; 
		$$counter{size}{path}{$path}+=$fs; 
	
		if (!$$counter{size}{pathmax}{$path} || $fs > $$counter{size}{pathmax}{$path} ) {
			$$counter{size}{allmaxsum}-=$$counter{size}{pathmax}{$path} if $$counter{size}{pathmax}{$path};
			$$counter{size}{allmaxsum}+=$fs;
			$$counter{size}{pathmax}{$path} = $fs;		
		}
	  
		$$counter{size}{files}{$path}{$file eq "" ? '.' : $file}+=$fs;
		
		
		if ($file=~/(\.[^.]+)$/ && length($1)<5) {
			$$counter{suffixes}{size}{lc($1)}+=$fs;
			$$counter{suffixes}{count}{lc($1)}++;
		}
	}
	
}
1;