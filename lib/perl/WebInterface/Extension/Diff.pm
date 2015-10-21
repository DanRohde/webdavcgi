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
# diff - sets the path to GNU diff (default: /usr/bin/diff)
# disable_fileactionpopup - disables fileaction entry in popup menu
# enable_apps - enables sidebar menu entry
# files_only - disables folder comparision (neccassary for none-local filesystem backends like SMB, DB) 
# 

package WebInterface::Extension::Diff;

use strict;

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension  );

use JSON;
sub init { 
	my($self, $hookreg) = @_; 
	my @hooks = ('css','locales','javascript', 'posthandler');
	push @hooks,'fileactionpopup' unless $main::EXTENSION_CONFIG{Diff}{disable_fileactionpopup};
	push @hooks,'apps' if $main::EXTENSION_CONFIG{Diff}{enable_apps};
	$hookreg->register(\@hooks, $self);
}

sub handle { 
	my ($self, $hook, $config, $params) = @_;
	my $ret = $self->SUPER::handle($hook, $config, $params);
	return $ret if $ret;
	if ($hook eq 'fileactionpopup') {
		$ret ={ action=>'diff', label=>'diff', path=>$$params{path}, type=>'li',classes=>$self->config('files_only',0)?'sel-multi sel-file':'sel-multi'};	
	} elsif ($hook eq 'apps') {
		$ret = $self->handleAppsHook($$self{cgi},'listaction diff sel-oneormore disabled','diff_short','diff'); 
	} elsif ($hook eq 'posthandler' && $$self{cgi}->param('action') eq 'diff') {
		my %jsondata  = ();
		my ($content, $raw);
		my @files = $$self{cgi}->param('files');
		if (scalar(@files)==2) { 
			$content = $self->renderDiffOutput(@files) if $self->checkFilesOnly(@files);
		}
		if (!$content) {
			if (scalar(@files)!= 2) {
				$jsondata{error} = $self->tl('diff_msg_selecttwo');
			} else {
				$jsondata{error} = sprintf($self->tl('diff_msg_differror'),$$self{cgi}->param('files'));
			}
			
		} else {
			$jsondata{content} = $content;
		}
		my $json = new JSON();
		main::printCompressedHeaderAndContent('200 OK', 'application/json', $json->encode(\%jsondata), 'Cache-Control: no-cache, no-store');
		
		$ret=1;
	}
	return $ret;
}
sub checkFilesOnly {
	my $self = shift @_;
	return 1 unless $self->config('files_only',0);
	while (my $f = shift @_) {
		return 0 unless $$self{backend}->isFile($main::PATH_TRANSLATED.$f);
	} 
	return 1;
}
sub substBasepath {
	my($self,$f) = @_;
	$f=~s/\\"/"/g;
	$f=$$self{backend}->resolveVirt($f);
	$f=~s/^\Q$main::PATH_TRANSLATED\E//;
	return $f;
}
sub renderDiffOutput {
	my ($self,@files) = @_;
	my $ret = 0;
	my $cgi = $$self{cgi};
	my ($f1,$f2) = @files;
	my $raw = ""; 
	my $difftmpl = $self->readTemplate('diff');
	my $difflinetmpl = $self->readTemplate('diffline');
	my $diffsinglelinetmpl = $self->readTemplate('diffsingleline');
	my $difffilenamelinetmpl = $self->readTemplate('difffilenameline');
	my @fnstack;
	if (open(DIFF, '-|', $self->config('diff','/usr/bin/diff'), '-ru',$$self{backend}->getLocalFilename($main::PATH_TRANSLATED.$f1),$$self{backend}->getLocalFilename($main::PATH_TRANSLATED.$f2))) {
		my $t = "";
		my ($lr,$ll) = (0,0);
		my $diffcounter = 0;		
		while (<DIFF>) {
			$raw.=$_;
			chomp;
			my($tmpl, $text1, $text2, $text, $type, $linenumber1, $linenumber2);
			if (/^-{3}\s+"?(.*?)"?\s+\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+ ([\+\-]\d+)$/) {
				my $f = $self->substBasepath($1);
				push @fnstack, $f unless $f =~/^\s*\Q$f1\E\s*$/ || $f=~/^\/tmp\//;
				next;
			} elsif (/^\+{3}\s+"?(.*?)"?\s+\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+ ([\+\-]\d+)$/) {
				$text2 = $self->substBasepath($1);
				$text1 = pop @fnstack;
				$t.=$self->renderTemplate($main::PATH_TRANSLATED, $main::REQUEST_URI, $difffilenamelinetmpl,{ file1=>$cgi->escapeHTML($text1), file2=>$cgi->escapeHTML($text2)}) unless $text2=~/^\s*\Q$f2\E\s*$/ || $text2 =~/^\/tmp\//;
				next;
			} elsif (/^diff /) {
				next;
			} elsif (/^@@ -(\d+)(,(\d+))? \+(\d+)(,(\d+))? @@/) {
				($ll,$lr) = ($1,$4);
				next;
			}
			
			my $o =$_;
			$o=~s/^.//;
			if (/^\+/) {
				($type, $tmpl, $linenumber1, $text1, $linenumber2,$text2,$text) = ('added', $difflinetmpl, '', '', $lr, $o);
				$lr++; 
				$diffcounter++;
			} elsif (/^-/) {
				($type, $tmpl, $linenumber1, $text1, $linenumber2,$text2,$text) = ('removed', $difflinetmpl, $ll, $o, '', '');
				$ll++;
				$diffcounter++;
			} elsif (/^ /) {
				($type, $tmpl, $linenumber1, $text1, $linenumber2,$text2,$text) = ('unchanged', $difflinetmpl, $ll, $o, $lr, $o);
				$ll++; $lr++;
			} elsif (/^Binary files (.*?) and (.*?) differ/) {
				my ($ff1,$ff2) = $self->config('files_only',0) ?($f1,$f2): ($1,$2);
				($type, $tmpl, $linenumber1, $text1, $linenumber2,$text2,$text) = ('binary', $diffsinglelinetmpl, '','','','', sprintf($self->tl('diff_binary'),$self->substBasepath($ff1),$self->substBasepath($ff2)));
				$diffcounter++;
			} elsif (/^Only in (.*?): (.*)$/) {
				($type, $tmpl, $linenumber1, $text1, $linenumber2,$text2,$text) = ('onlyin', $diffsinglelinetmpl, '','','','', sprintf($self->tl('diff_onlyin'),$self->substBasepath($1),$self->substBasepath($2)));
				$diffcounter++;
			} elsif (/^\\\s*No newline at end of file/i) {
				($type, $tmpl, $linenumber1, $text1, $linenumber2,$text2,$text) = ('comment', $diffsinglelinetmpl, '','','','',$self->tl('diff_nonewline'));
			} elsif (/^\\ (.*)/ || /^(\w+.*)/) {
				($type, $tmpl, $linenumber1, $text1, $linenumber2,$text2,$text) = ('comment', $diffsinglelinetmpl, '','','','',$1);
			}
			$t.= $self->renderTemplate($main::PATH_TRANSLATED, $main::REQUEST_URI, $tmpl, { type=>$type, text1=>$cgi->escapeHTML($text1), text2=>$cgi->escapeHTML($text2), linenumber1=>$linenumber1, linenumber2=>$linenumber2, text=>$cgi->escapeHTML($text)});
		}
		close(DIFF);		
		$ret = $self->renderTemplate($main::PATH_TRANSLATED, $main::REQUEST_URI, $difftmpl, { difflines => $t, rawdifflines => $cgi->escapeHTML($raw), file1=> $cgi->escapeHTML($f1), file2=>$cgi->escapeHTML($f2), diffcounter=> sprintf($self->tl('diff_nomorediffs'),$diffcounter) });
		
	} 
	return $ret;
}
1;
