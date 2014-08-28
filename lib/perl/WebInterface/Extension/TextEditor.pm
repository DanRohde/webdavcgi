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
# editablefiles - list of regular expressions to identify text files
# editablecategories - regular expression of categories (default: (text|soruce|shell|config))
# disableckeditor - disables CKEditor for HTML editing
# sizelimit - size limit for text files in bytes (default: 2097152 (=2MB))
# template - template file (default: editform)


package WebInterface::Extension::TextEditor;

use strict;

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension  );

use JSON;

sub init { 
	my($self, $hookreg) = @_; 
	my @hooks = ('css','locales','javascript', 'gethandler', 'posthandler','fileactionpopup','fileaction', 'settings', 'fileattr');
	$hookreg->register(\@hooks, $self);
	
	$$self{editablefiles} = $self->config('editablefiles', 
		[ '\.(txt|php|s?html?|tex|inc|cc?|java|hh?|ini|pl|pm|py|css|js|inc|csh|sh|tcl|tk|tex|ltx|sty|cls|vcs|vcf|ics|csv|mml|asc|text|pot|brf|asp|p|pas|diff|patch|log|conf|cfg|sgml|xml|xslt|bat|cmd|wsf|cgi|sql)$', 
 		  '^(\.ht|readme|changelog|todo|license|gpl|install|manifest\.mf|author|makefile|configure|notice)' ]
 	);
 	$$self{editablefilesregex} = '(' . join('|', @{$$self{editablefiles}}) .')';
 	$$self{editablecategories} = $self->config('editablecategories','(text|source|shell|config)');
	$$self{template} = $self->config('template','editform');
	$$self{sizelimit} = $self->config('sizelimit',2097152 );
	$$self{json} = new JSON();
}
sub handle { 
	my ($self, $hook, $config, $params) = @_;
	my $ret = $self->SUPER::handle($hook, $config, $params);
	return $ret if $ret;
	
	if ($hook eq 'settings') {
		$ret = $self->handleSettingsHook('confirm.save') . $self->handleSettingsHook('texteditor.backup');
	} elsif ($hook eq 'fileaction') {
		$ret = { action=>'edit', classes=>'access-readable', label=>'editbutton' };
	} elsif ($hook eq 'fileactionpopup') {
		$ret = { action=>'edit', classes=>'access-readable', label=>'editbutton', type=>'li'};
	} elsif ($hook eq 'fileattr') {
		my $isEditable = $self->isEditable($$params{path});
		$ret = { ext_classes=>'iseditable-'. ( $isEditable ? 'yes' : 'no'), ext_iconclasses=> $isEditable ?  'category-text' : '' };
	} elsif ($hook eq 'gethandler' && $$self{cgi}->param('action') eq 'edit') {
		$ret = $self->getEditForm(); 
	} elsif ($hook eq 'posthandler' && $$self{cgi}->param('action') eq 'savetextdata') {
		$ret = $self->saveTextData();
	}
	return $ret;
}
sub getEditForm {
	my ($self) = @_;
	my $filename = $$self{cgi}->param('filename');
	my $full = "$main::PATH_TRANSLATED$filename";
	my ($contenttype, $content) = ('text/plain', '' );
	if ( ($$self{backend}->stat($full))[7] >$$self{sizelimit}) {
		$content = $$self{json}-encode({ error=>sprintf($self->tl('msg_sizelimitexceeded'), $$self{cgi}->escapeHTML($filename), ($self->renderByteValue($$self{sizelimit}))[0])});
		$contenttype='application/json';
	} else {
		$content = $self->renderTemplate($main::PATH_TRANSLATED,$main::REQUEST_URI, $self->readTemplate($$self{template}), { filename=>$$self{cgi}->escapeHTML($filename), textdata=>$$self{cgi}->escapeHTML($$self{backend}->getFileContent($full)), mime=>main::getMIMEType($full)});
	}
	main::printHeaderAndContent('200 OK',$contenttype, $content,'Cache-Control: no-cache, no-store');
	return 1;
}
sub makeBackupCopy {
	my ($self, $full) = @_;
	return $$self{cgi}->cookie('settings.texteditor.backup') eq 'no' || ($$self{backend}->stat($full))[7] == 0 || main::rcopy($full, "$full.backup");
}
sub saveTextData {
	my ($self) = @_;
	my $filename = $$self{cgi}->param('filename');
	my $full = $main::PATH_TRANSLATED . $filename;
	my $efilename = $$self{cgi}->escapeHTML($filename);
	my %jsondata = ();
	if (main::isLocked($full)) {
		$jsondata{error} = sprintf($self->tl('msg_locked'), $efilename);	
	} elsif ( $$self{backend}->isFile($full) && $$self{backend}->isWriteable($full) && $self->makeBackupCopy($full) && $$self{backend}->saveData($full, $$self{cgi}->param('textdata') ) ) {
		$jsondata{message} = sprintf($self->tl('msg_textsaved'), $efilename);
	} else {
		$jsondata{error} = sprintf($self->tl('msg_savetexterr'), $efilename);
	}
	main::printHeaderAndContent('200 OK', 'application/json', $$self{json}->encode(\%jsondata), 'Cache-Control: no-cache, no-store');
	return 1;
}
sub isEditable {
	my ($self,$fn) = @_;
	my $suffix = $fn=~/\.(\w+)$/ ? lc($1) : '___unknown___';
	return ($$self{backend}->basename($fn) =~/$$self{editablefilesregex}/i || $main::FILETYPES =~/^$$self{editablecategories}\s+.*\b\Q$suffix\E\b/m) 
		&& $$self{backend}->isFile($fn) && $$self{backend}->isReadable($fn) && $$self{backend}->isWriteable($fn);
}

1;