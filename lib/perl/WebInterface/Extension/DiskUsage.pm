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
# enable_fileaction - disables fileaction entry
# disable_fileactionpopup - disables fileaction entry in popup menu
# disable_apps - disables sidebar menu entry
# timeout - timeout in seconds (default: 60)
# filelimit - limits file count for treemap (default: 50)
# folderlimit - limits folder count for details and treemap (default: 50)
# template - dialog template (default: diskusage)
# followsymlinks - follows sym links (default: 1 (on))

package WebInterface::Extension::DiskUsage;

use strict;

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension  );

use JSON;
use POSIX qw(floor ceil);

sub init { 
	my($self, $hookreg) = @_; 
	my @hooks = ('css','javascript','locales','posthandler');
	push @hooks,'fileaction' if $self->config('enable_fileaction',0);
	push @hooks,'fileactionpopup' unless $self->config('disable_fileactionpopup',0);
	push @hooks,'apps' unless $self->config('disable_apps',0);
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
		my $content = $self->renderDiskUsageTemplate();
		main::printCompressedHeaderAndContent('200 OK', 'text/html', $content, 'Cache-Control: no-cache, no-store') if $content;
		return 1;
	}
	return 0; 
}

sub renderDiskUsageTemplate {
	my ($self) = @_;
	
	my $cgi = $$self{cgi};
	my $counter = { start => time() };
	my $json = new JSON();
	
	$$self{counter}=$counter;
	$$self{json}=$json;
	
	foreach my $file ($cgi->param('file')) {
		$self->getDiskUsage($main::PATH_TRANSLATED,$file,$counter);		
	}
	if (time() - $$counter{start} > $self->config('timeout',60)) {
		main::printCompressedHeaderAndContent('200 OK', 'application/json', $json->encode({error=>$cgi->escapeHTML(sprintf($self->tl('du_timeout'),$self->config('timeout',60)))}), 'Cache-Control: no-cache, no-store');
		return;		
	}; 
	
	
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
	$$self{folders} = \@folders;
	$$self{sizeall} = $sizeall;
	$$self{filecountall} = $filecountall;
	$$self{maxfilesizesum} = $maxfilesizesum;
	
	
	
	my @pbvsum = $self->renderByteValue($$counter{size}{all});
	my $filenamelist = join(', ',$cgi->param('file'));
	$filenamelist='.' if $filenamelist eq "";
	$filenamelist=substr($filenamelist,0,100).'...' if length($filenamelist)>100;
	my $vars = {
		diskusageof => $cgi->escapeHTML(sprintf($self->tl('du_diskusageof'),$filenamelist)),
		files=>$$counter{count}{all}{files} || 0,
		folders=>$$counter{count}{all}{folders} || 0,
		sum=>$$counter{count}{all}{sum} || 0,
		size=>$pbvsum[0],
		sizetitle=>$pbvsum[1],
		bytesize => $$counter{size}{all},
		time=>time(),
	};
	
	my $content = $self->renderTemplate($main::PATH_TRANSLATED,$main::REQUEST_URI,$self->readTemplate($self->config('template','diskusage')), $vars);
	
	return $content;
	
}
sub renderDiskUsageDetails {
	my ($self, $template) = @_;
	my $tmpl = $template=~/^'(.*)'$/ ? $1 : $self->readTemplate($template) ;
	my $counter = $$self{counter};
	my $statfstring = sprintf('%s %%d, %s %%d, %s %%d',$self->tl('statfiles'),$self->tl('statfolders'),$self->tl('statsum'));
	my $details = "";
	my $cgi=$$self{cgi};
	
	return "[]" if $$counter{size}{all} == 0;
	
	foreach my $folder (@{$$self{folders}}) {
		my $perc = $$counter{size}{all} >0 ? 100*$$counter{size}{path}{$folder}/$$counter{size}{all} : 0;
		my $title = sprintf('%.2f%%, '.$statfstring,$perc,$$counter{count}{files}{$folder},$$counter{count}{folders}{$folder},$$counter{count}{sum}{$folder});
		my @pbv = $self->renderByteValue($$counter{size}{path}{$folder});
		my $foldername = $self->_getFolderName($folder);
		my $uri = $self->getURI($foldername);
		
		my $vars = {
			foldername=>$cgi->escapeHTML($foldername),
			folderuri=> $main::REQUEST_URI.$uri,
			foldersize=>$pbv[0],
			foldersizetitle=>$pbv[1],
			filecount=>$$counter{count}{files}{$folder} || 0,
			foldercount=>$$counter{count}{folders}{$folder} || 0,
			sumcount=>$$counter{count}{sum}{$folder} || 0,
			percstyle=>sprintf('width: %.0f%%;',$perc),
		};
		
		$details.= $self->renderTemplate($main::PATH_TRANSLATED,$main::REQUEST_URI, $tmpl, $vars);
	}
	return $details;
}
sub execTemplateFunction {
	my ($self, $fn, $ru, $func, $param) = @_;
	my $content;
	$content = $self->renderDiskUsageDetails($param) if $func eq 'details';
	$content = $self->collectTreemapData() if $func eq 'json' && $param eq 'treemapdata';
	$content = $self->collectSuffixData('count') if $func eq 'json' && $param eq 'suffixesbycount';
	$content = $self->collectSuffixData('size') if $func eq 'json' && $param eq 'suffixesbysize';
	#$content = $self->collectHistoByFileSizeData() if $func eq 'json' && $param eq 'histobyfilesize';
	#$content = $self->collectHistoByFolderSizeData() if $func eq 'json' && $param eq 'histobyfoldersize';
	$content = $self->SUPER::execTemplateFunction($fn,$ru,$func,$param) unless defined $content;
	return $content;
}
sub collectHistoByFileSizeData() {
	my ($self) = @_;
	my $counter = $$self{counter};
	my @data = ();
	
	my @sizes = keys %{$$counter{size}{histo}{sizes}};
	
	my @buckets = ();
	my $bucketcount = 10;
	my $filemax = $$counter{size}{histo}{filemax};
	my $deccount = floor(log($filemax) / log(10));
	my $byteexp = floor($deccount*log(10)/log(1024));
	my $bval = 1024 ** $byteexp;
	my $bucketmax = ceil( $filemax / (10**$deccount) + 1) * $bval;
	my $bucketsize = $bucketmax / $bucketcount;
	$bucketsize=1 if $bucketsize == 0;
	#print STDERR "filemax=$filemax,  deccount=$deccount, byteexp=$byteexp, bval=$bval, bucketmax=$bucketmax, bucketsize=$bucketsize\n";

	foreach my $size (@sizes) {
		$buckets[ floor($size/$bucketsize) ] ++;
	}
	
	@data = map {  [  ($self->renderByteValue($_ * $bucketsize,1))[0], $buckets[$_] || 0  ] } 0 .. $bucketcount-1;
	
	return $$self{cgi}->escapeHTML($$self{json}->encode({data=>\@data}));
}
sub _min {
	return $_[0] < $_[1] ? $_[0] : $_[1]; 
}
sub _max {
	return $_[0] > $_[1] ? $_[0] : $_[1];
} 

sub collectHistoByFolderSizeData() {
	my ($self) = @_;
	my $counter = $$self{counter};
	my @data = ();
	
	my @pathes = keys %{$$counter{size}{path}};
	
	my %buckets = ();
	my $bucketcount = _min(scalar(@pathes),20);
	my $pathmax = $$counter{size}{histo}{pathmax};
	my $logval = floor(log($pathmax)/log(10));
	my $bval = $logval > 3 ? 1024 ** ($logval-4) : 1;
	my $bucketmax = ceil( $pathmax / $bval + 1 ) * $bval ;
	my $bucketsize =  $bucketmax / $bucketcount;
	
	$bucketsize = 1 if $bucketsize == 0 ;
	foreach my $path (@pathes) {
		$buckets{  floor($$counter{size}{path}{$path} / $bucketsize) }+=$$counter{count}{files}{$path};		
	}
	@data = map { [ ($self->renderByteValue($_ *$bucketsize,1))[0], $buckets{$_} || 0 ] }  sort { $a <=> $b } keys %buckets;
	return $$self{cgi}->escapeHTML($$self{json}->encode({data=>\@data}));
}
sub collectSuffixData {
	my ($self, $key) = @_;
	my $counter = $$self{counter};
	my @data;
	
	## suffixes by file size:
	@data = map {[ $_, $$counter{suffixes}{$key}{$_} ] } sort { $$counter{suffixes}{$key}{$b} <=> $$counter{suffixes}{$key}{$a} || $a cmp $b } keys %{$$counter{suffixes}{$key}};
	if (scalar(@data)>10) {
		my @deleted = splice @data, 10;
		my $others = 0;
		foreach my $s (@deleted) { $others+= $$s[1]; };
		push @data , [ 'others', $others ];	
	}
	return $$self{cgi}->escapeHTML($$self{json}->encode({data=>\@data}));
}
sub collectTreemapData {
	my ($self) = @_;
	my $cgi = $$self{cgi};
	my $counter = $$self{counter};
	my %mapdata = (  id => $main::REQUEST_URI, uri=>$cgi->escape($main::REQUEST_URI), children=> [] );
	my $cc = 0;
	my $ccst = 1/5;
	my $statfstring = sprintf('%s %%d, %s %%d, %s %%d',$self->tl('statfiles'),$self->tl('statfolders'),$self->tl('statsum'));
	my ($filecountall, $sizeall, $maxfilesizesum) = ($$self{filecountall},$$self{sizeall},$$self{maxfilesizesum});
	
	return "[]" if $$counter{size}{all} == 0;
	
	foreach my $folder (@{$$self{folders}}) {
		# collect treemap data:
		my $files = $$counter{size}{files}{$folder};
		my @childmapdata = ();
		my $foldersize = $$counter{size}{path}{$folder};
		my @files = sort { $$files{$b} cmp $$files{$a} || $a cmp $b } keys %{$files};
		my $foldername = $self->_getFolderName($folder);
		my $uri = $self->getURI($foldername);
		my $perc = $$counter{size}{all} >0 ? 100*$$counter{size}{path}{$folder}/$$counter{size}{all} : 0;
		my $title = sprintf('%.2f%%, '.$statfstring,$perc,$$counter{count}{files}{$folder},$$counter{count}{folders}{$folder},$$counter{count}{sum}{$folder});
		my @pbv = $self->renderByteValue($$counter{size}{path}{$folder});
		
		
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
	return $cgi->escapeHTML($$self{json}->encode(\%mapdata));
}
sub gs {
	my ($v) = @_;
	my $r = sprintf('%.4f',$v);
	$r=~s/\,/\./;
	return $r;
}
sub _getFolderName {
	my ($self,$folder) = @_;
	my $foldername = $folder;
	$foldername=~s/^\Q$main::PATH_TRANSLATED\E//;
	$foldername='./' if $foldername eq "";
	return $foldername;
}

sub getURI { 
	my ($self, $relpath) = @_;
	return join('/',map({ $$self{cgi}->escape($_) } split(/\//,$relpath)));
}

sub getDiskUsage {
	my ($self, $path, $file, $counter) = @_;
	
	my $backend = $$self{backend};

	$file=~s/^\///;
	
	my $full = $path.$file;
	
	return if time() - $$counter{start} > $self->config('timeout',60);
	
	my $fullresolved = $backend->resolve($backend->resolveVirt($full));
	return if $$counter{visited}{$fullresolved};
	$$counter{visited}{$fullresolved} = 1;	
	 
	$$counter{count}{all}{sum}++;	
	$$counter{count}{sum}{$path}++;
	$$counter{count}{subdir}{sum}{$path}{$file}++ if $file ne "";
		
	if ($backend->isDir($full)) {
		$$counter{count}{all}{folders}++;
		$$counter{count}{folders}{$path}++; 
		
		return if !$self->config('followsymlinks',1) && $backend->isLink($full);
		
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
		
		$$counter{size}{histo}{filemax} = $fs if !$$counter{size}{histo}{filemax} || $fs > $$counter{size}{histo}{filemax};
	  	$$counter{size}{histo}{sizes}{$fs}++;
	  	
		$$counter{size}{files}{$path}{$file eq "" ? '.' : $file} = $fs;
		
		if ($file=~/(\.[^.]+)$/ && length($1)<5) {
			$$counter{suffixes}{size}{lc($1)}+=$fs;
			$$counter{suffixes}{count}{lc($1)}++;
		}
	}
	$$counter{size}{histo}{pathmax} = $$counter{size}{path}{$path} if !$$counter{size}{histo}{pathmax} || $$counter{size}{path}{$path} > $$counter{size}{histo}{pathmax};
}
1;