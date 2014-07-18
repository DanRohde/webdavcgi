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
# disable_fileactionpopup - disables fileaction entry in popup menu
# disable_apps - disables sidebar menu entry
# allow_contentsearch - allowes search file content
# sizelimit - sets size limit for content search (default: 2097152 (=2MB))


package WebInterface::Extension::Search;

use strict;

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension  );

use JSON;
use Time::HiRes qw(time);

use vars qw( %CACHE );
sub init { 
	my($self, $hookreg) = @_; 
	my @hooks = ('css','locales','javascript', 'gethandler','posthandler');
	push @hooks,'fileactionpopup' unless $main::EXTENSION_CONFIG{Search}{disable_fileactionpopup};
	push @hooks,'apps' unless $main::EXTENSION_CONFIG{Search}{disable_apps};	
	$hookreg->register(\@hooks, $self);
}
sub handle { 
	my ($self, $hook, $config, $params) = @_;
	my $ret = $self->SUPER::handle($hook, $config, $params);
	return $ret if $ret;
	
	if( $hook eq 'fileactionpopup') {
		$ret = { action=>'search', label=>'search', path=>$$params{path}, type=>'li', classes=>'access-readable sel-dir' };
	} elsif ($hook eq 'apps') {
		$ret = $self->handleAppsHook($$self{cgi},'search access-readable ','search','search'); 
	} elsif ($hook eq 'gethandler') {
		my $ajax = $$self{cgi}->param('ajax');
		if ($ajax eq 'getSearchForm') {
			$ret = $self->getSearchForm();
		} elsif ($ajax eq 'getSearchResult') {
			$ret = $self->getSearchResult();
		}
	} elsif ($hook eq 'posthandler') {
		if ($$self{cgi}->param('ajax') eq 'search') {
			$ret = $self->handleSearch();
		}
	}
	return $ret;
}
sub getSearchForm {
	my ($self) = @_;
	my $content = $self->renderTemplate($main::PATH_TRANSLATED,$main::REQUEST_URI,$self->readTemplate($self->config('template','search')));
	main::printCompressedHeaderAndContent('200 OK','text/html', $content,'Cache-Control: no-cache, no-store');	
	return 1;
}
sub getTempFilename {
	my ($self,$type) = @_;
	my $searchid = $$self{cgi}->param('searchid');
	return "/tmp/webdavcgi-search-$main::REMOTE_USER-$searchid.$type";
}
sub getResultTemplate {
	my($self) = @_;
	return $CACHE{$self}{resulttemplate} ||= $self->readTemplate($self->config('resulttemplate', 'result'));
}
sub addSearchResult {
	my ($self, $base, $file, $counter) = @_;
	if (open(my $fh,">>", $self->getTempFilename('result'))) {
		my $filename = $file eq "" ? "." : $$self{cgi}->escapeHTML($file);
		my $full = $base.$file;
		my $uri = $main::REQUEST_URI.$file;
		my $mime = $$self{backend}->isDir($full)?'<folder>':main::getMIMEType($full);
		print $fh $self->renderTemplate($main::PATH_TRANSLATED, $main::REQUEST_URI, $self->getResultTemplate(), 
			{ fileuri=>$$self{cgi}->escapeHTML($uri), 
				filename=>$filename,
				dirname=>$$self{cgi}->escapeHTML($$self{backend}->dirname($uri)),
				iconurl=>$$self{backend}->isDir($full) ? $self->getIcon($mime) : $self->canCreateThumbnail($full)? $$self{cgi}->escapeHTML($uri).'?action=thumb' : $self->getIcon($mime),
				iconclass=>$self->canCreateThumbnail($full) ? 'icon thumbnail' : 'icon',
				mime => $$self{cgi}->escapeHTML($mime),
				type=> $mime eq '<folder>' ? 'folder' : 'file', 
			});
		$$counter{results}++;
		close($fh);
	}
}
sub filterFiles {
	my ($self, $base, $file) = @_;
	my $ret = 0;
	my $query = $$self{cgi}->param('query');
	my $size = $$self{cgi}->param('size');
	my $searchin = $$self{cgi}->param('searchin') || 'filename';
	my $full = $base.$file;
	 
	$ret = 1 if  $query && $searchin eq 'filename' && $$self{backend}->basename($file) !~ /\Q$query\E/i;
	$ret = 1 if  $query && $self->config('allow_contentsearch',0) && $searchin eq 'content' 
			&& (	!$$self{backend}->isReadable($full)  
				|| !$$self{backend}->isFile($full)
				|| ($$self{backend}->stat($full))[7] > $self->config('sizelimit', 2097152) 
				|| $$self{backend}->getFileContent($$full) !~/\Q$query\E/i
			);
		
	$ret |= 1 if !$$self{cgi}->param('filetype') && $$self{backend}->isFile($full) && !$$self{backend}->isLink($full);
	$ret |= 1 if !$$self{cgi}->param('foldertype') && $$self{backend}->isDir($full);
	$ret |= 1 if !$$self{cgi}->param('linktype') && $$self{backend}->isLink($full);
	
	if (defined $size && $size=~/^\d+$/) {
		my $sizecomparator = $$self{cgi}->param('sizecomparator');
		$sizecomparator = '==' if $sizecomparator eq '=';
		if ($sizecomparator =~ /^[<>=]{1,2}$/) { 
			my $filesize = ($$self{backend}->stat($full))[7];
			my $realsize = $size * ( $$self{BYTEUNITS}{$$self{cgi}->param('sizeunits')} || 1);
			$ret |= ! eval "$filesize $sizecomparator $realsize";
		}
	}
	return $ret;
}
sub doSearch {
	my ($self, $base, $file, $counter) = @_;
	my $backend = $$self{backend};
	my $full = $base.$file;
	
	$self->addSearchResult($base, $file, $counter) unless $self->filterFiles($base,$file);
	
	if ($backend->isDir($full) && !$backend->isLink($full)) {
		$$counter{folders}++;
		foreach my $f ( sort @{ $backend->readDir($full, main::getFileLimit($full)) } ) {
			$f.='/' if $backend->isDir($full.$f);
			$self->doSearch($base, "$file$f", $counter);
		}
	} else {
		$$counter{files}++;
	}	
}
sub handleSearch {
	my ($self) = @_;
	
	my @files = $$self{cgi}->param('files');
	@files = ( '' ) if scalar(@files) == 0;
	my @results = ();
	unlink $self->getTempFilename('result');
	my %counter;
	foreach my $file (@files) {
		$self->doSearch($main::PATH_TRANSLATED, $file,\%counter);
	}
	my $status = sprintf($self->tl('search.completed'),$counter{results} || '0',$counter{files} || '0' ,$counter{folders} || '0');
	my $data = !$counter{results} ? $$self{cgi}->div($self->tl('search.noresult')) : undef; 
	$self->getSearchResult($status, $data);
	unlink $self->getTempFilename('result');
	return 1;
}
sub getSearchResult {
	my ($self, $status, $data) = @_;
	my %jsondata = ();
	my $tmpfn = $self->getTempFilename('result');
	$jsondata{status} = $status || $self->tl('search.inprogress');
	if ($data) {
		$jsondata{data} = $data;
	} else {
		if (open(my $fh, "<", $tmpfn)) {
			$jsondata{data} = $$self{cgi}->div(join('', <$fh>));
			close($fh);
		}
	} 	
	my $json = new JSON();
	main::printCompressedHeaderAndContent('200 OK','application/json', $json->encode(\%jsondata),'Cache-Control: no-cache, no-store');
	return 1;
}
sub renderSelectedFiles{
	my ($self, $format) = @_;
	my $ret = "";
	foreach my $file ($$self{cgi}->param('files')) {
		my $f = $format;
		$f=~s/\$v/$$self{cgi}->escapeHTML($file)/egs;
		$ret.=$f;
	}	
	return $ret;
}
sub execTemplateFunction {
	my ($self, $fn, $ru, $func, $param) = @_;
	my $content;
	$content = $self->renderSelectedFiles($param) if $func eq 'renderSelectedFiles';
	$content = time() if $func eq 'getSearchId';
	$content = $self->SUPER::execTemplateFunction($fn,$ru,$func,$param) unless defined $content;
	return $content;
}
1;