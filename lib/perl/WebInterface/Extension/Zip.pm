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
# disable_filelistaction - disables fileaction entry
# disable_fileactionpopup - disables fileaction entry in popup menu
# disable_new	-disables new menu entry
# enable_apps - enables sidebar menu entry


package WebInterface::Extension::Zip;

use strict;

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension  );

sub init { 
	my($self, $hookreg) = @_; 
	my @hooks = ('css','locales','javascript','posthandler','body','templates');
	push @hooks,'fileaction' unless $main::EXTENSION_CONFIG{Zip}{disable_fileaction};
	push @hooks,'filelistaction' unless $main::EXTENSION_CONFIG{Zip}{disable_filelistaction};
	push @hooks,'fileactionpopup' unless $main::EXTENSION_CONFIG{Zip}{disable_fileactionpopup};
	push @hooks,'fileactionpopupnew' unless $main::EXTENSION_CONFIG{Zip}{disable_fileactionpopup};
	push @hooks,'apps' if $main::EXTENSION_CONFIG{Zip}{enable_apps};
	push @hooks,'new' unless $main::EXTENSION_CONFIG{Zip}{disable_fnew};
	
	$hookreg->register(\@hooks, $self);
}

sub handle { 
	my ($self, $hook, $config, $params) = @_;
	my $ret = $self->SUPER::handle($hook, $config, $params);
	return $ret if $ret;
	
	if ($hook eq 'fileaction') {
		$ret = {  action=>'zipdwnload',accesskey=>'z', label=>'zipdwnload', path=>$$params{path}, classes=>'access-readable'};
	} elsif ($hook eq 'filelistaction') {
		$ret = { listaction=>'zipdwnload', label=>'zipdwnload', title=>'zipdwnloadtext', path=>$$params{path}, classes=>'sel-multi uibutton'};
	} elsif ($hook eq 'fileactionpopup') {
		$ret = { action=>'zipdwnload', label=>'zipdwnload', title=>'zipdwnloadtext', path=>$$params{path}, type=>'li', classes=>'listaction sep'};
	} elsif ($hook eq 'fileactionpopupnew') {
		$ret = { action=>'zipup', label=>'zipup', title=>'zipup', path=>$$params{path}, type=>'li', classes=>'access-writeable sep'};
	} elsif ($hook eq 'new') {	
		$ret = { action=>'zipup',label=>'zipup', title=>'zipup', path=>$$params{path}, classes=>'access-writeable', type=>'li-a', liclasses=>'sep', accesskey=>'w'};
	} elsif ($hook eq 'apps') {
		$ret = $self->handleAppsHook($$self{cgi},'listaction zipdwnload sel-multi disabled ','zipdwnload','zipdwnload');
	} elsif ($hook eq 'body') {
		$ret = $self->renderUploadFormTemplate(); 		
	} elsif ($hook eq 'templates') {
		$ret = $self->renderMessageTemplate();
	} elsif ($hook eq 'posthandler') {
		
		if ($$self{cgi}->param('action') eq 'zipdwnload') {
			$self->handleZipDownload();
			$ret = 1;
		} elsif ($$self{cgi}->param('action') eq 'zipup') {
			$self->handleZipUpload();
			$ret = 1;
		}
	}
	print STDERR "handle: ret=$ret\n";
	return $ret;
}
sub renderUploadFormTemplate {
	my($self) = @_;
	print STDERR "renderUploadFormTemplate\n";
	return $self->replaceVars($self->readTemplate('zipfileuploadform'));
}
sub renderMessageTemplate {
	my ($self) = @_;
	print STDERR "renderMessageTemplate\n";
	return $self->replaceVars($self->readTemplate('messages'));
}
sub handleZipUpload {
	my ( $self, $redirtarget ) = @_;
	my @zipfiles;
	my ( $msg, $errmsg, $msgparam );
	foreach my $fh ( $$self{cgi}->param('files') ) {
		my $rfn = $fh;
		$rfn =~ s/\\/\//g;    # fix M$ Windows backslashes
		$rfn = $$self{backend}->basename($rfn);
		if (main::isLocked("$main::PATH_TRANSLATED$rfn")) {
			$errmsg='locked';
			$msgparam='p1='.$$self{cgi}->escape($rfn);
			last;	
		}
		elsif ( $$self{backend}->saveStream( "$main::PATH_TRANSLATED$rfn", $fh ) )
		{
			push @zipfiles, $rfn;
			$$self{backend}->unlinkFile( $main::PATH_TRANSLATED . $rfn )
			  if $$self{backend} ->uncompressArchive( "$main::PATH_TRANSLATED$rfn",	$main::PATH_TRANSLATED );
		}
	}
	if ( $#zipfiles > -1 ) {
		$msg = ( $#zipfiles > 0 ) ? 'zipupmulti' : 'zipupsingle';
		$msgparam = 'p1='
		  . ( $#zipfiles + 1 ) . ';p2='
		  . $$self{cgi}->escape( substr( join( ', ', @zipfiles ), 0, 150 ) );
	}
	else {
		$errmsg = 'zipupnothingerr';
	}
	print $$self{cgi}->redirect( $redirtarget . $self->createMsgQuery( $msg, $msgparam, $errmsg, $msgparam ) );
}

sub handleZipDownload {
	my $self = shift;
	my $zfn  = $$self{backend}->basename($main::PATH_TRANSLATED) . '.zip';
	$zfn =~ s/ /_/;
	print $$self{cgi}->header(
		-status              => '200 OK',
		-type                => 'application/zip',
		-Content_disposition => 'attachment; filename=' . $zfn
	);
	$$self{backend}->compressFiles( \*STDOUT, $main::PATH_TRANSLATED,
		$$self{cgi}->param('files') );

}

1;