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
# disable_new - disables new menu entry
# enable_apps - enables sidebar menu entry


package WebInterface::Extension::Zip;

use strict;

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension  );

use JSON;
use File::Temp qw(tempfile);
use POSIX qw(strftime);

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
		$ret = { title=>$self->tl('zip.menu'), classes=>'zip-popup', subpopupmenu=> 
			[ 
				{ action=>'zipup', label=>'zipup', title=>'zipup', path=>$$params{path}, type=>'li', classes=>'access-writeable sep'},
				{ action=>'zipdwnload', label=>'zipdwnload', title=>'zipdwnloadtext', path=>$$params{path}, type=>'li', classes=>'listaction'},
				{ action=>'zipcompress', label=>'zip.compress', title=>'zip.compress.title', path=>$$params{path}, type=>'li', classes=>'access-writeable' },
				{ action=>'zipuncompress',label=>'zip.uncompress', title=>'zip.uncompress.title', path=>$$params{path}, type=>'li', classes=>'access-writeable' } 
			] 
		};
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
			$ret = $self->handleZipDownload();
		} elsif ($$self{cgi}->param('action') eq 'zipup') {
			$ret = $self->handleZipUpload();
		} elsif ($$self{cgi}->param('action') eq 'zipcompress') {
			$ret = $self->handleZipCompress();
		} elsif ($$self{cgi}->param('action') eq 'zipuncompress') {
			$ret = $self->handleZipUncompress();
		} 
	}
	return $ret;
}
sub renderUploadFormTemplate {
	my($self) = @_;
	return $self->replaceVars($self->readTemplate('zipfileuploadform'));
}
sub renderMessageTemplate {
	my ($self) = @_;
	return $self->replaceVars($self->readTemplate('messages'));
}
sub handleZipUpload {
	my ( $self ) = @_;
	my @zipfiles;
	my ( $msg, $errmsg, $msgparam );
	foreach my $fh ( $$self{cgi}->param('files') ) {
		my $rfn = $fh;
		$rfn =~ s/\\/\//g;    # fix M$ Windows backslashes
		$rfn = $$self{backend}->basename($rfn);
		if (main::isLocked("$main::PATH_TRANSLATED$rfn")) {
			$errmsg='locked';
			$msgparam= [ $rfn ];
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
		$msgparam = [ scalar(@zipfiles), substr( join( ', ', @zipfiles ), 0, 150 ) ];
	}
	else {
		$errmsg = 'zipupnothingerr';
	}
	my %jsondata = ();
	my @params = $msgparam ? map { $$self{cgi}->escapeHTML($_) } @{ $msgparam } : (); 
	$jsondata{error} = sprintf($self->tl("msg_$errmsg"), @params) if $errmsg;
	$jsondata{message} = sprintf($self->tl("msg_$msg"), @params ) if $msg;		
	my $json = new JSON();
	main::printCompressedHeaderAndContent('200 OK','application/json',$json->encode(\%jsondata),'Cache-Control: no-cache, no-store');
	return 1;
}
sub getZipFilename {
	my ($self, $files) = @_;
	my $time = strftime('%Y-%m-%d-%H:%M:%S',localtime);
	my $zipfilename = $$self{backend}->basename(scalar(@$files) > 1 || $$files[0] eq '.' ? $main::REQUEST_URI : $$files[0],'.zip') . "-$time.zip";
	$zipfilename =~ s/[\/ ]/_/g;
	return $zipfilename;
}
sub handleZipDownload {
	my $self = shift;
	my @files = $$self{cgi}->param('files');
	my $zfn  = $self->getZipFilename(\@files);
	print $$self{cgi}->header(
		-status              => '200 OK',
		-type                => 'application/zip',
		-Content_disposition => 'attachment; filename=' . $zfn
	);
	$$self{backend}->compressFiles( \*STDOUT, $main::PATH_TRANSLATED, @files);
	return 1;
}
sub handleZipCompress {
	my $self = shift;
	my @files = $$self{cgi}->param('files');
	my $zipfilename = $self->getZipFilename(\@files);
	
	my ($zipfh, $zipfn) = tempfile(TEMPLATE=>'/tmp/webdavcgi-Zip-XXXXX', CLEANUP=>1, SUFFIX=>".zip");
	my $error;
	if (open($zipfh,">","$zipfn")) {
		$$self{backend}->compressFiles($zipfh, $main::PATH_TRANSLATED, @files); 
		close($zipfh);
		if ((stat($zipfn))[7]>0) {
			my ($quotahrd,$quotacur) = main::getQuota();
			if ($quotahrd == 0 || (stat($zipfn))[7] + $quotacur < $quotahrd) {
				if (open($zipfh,"<",$zipfn)) {;
					$$self{backend}->saveStream($main::PATH_TRANSLATED.$zipfilename, $zipfh);
					close($zipfh);
				}
			} else {
				$error = $self->tl('msg_zipcompress_quotaexceeded');
			}
		} else {
			$error=$self->tl('msg_zipcompress_failed');
		}
	}
	my %jsondata = ();
	
	if ($error) {
		$jsondata{error} = $error;		
	} else {
		$jsondata{message} = sprintf($self->tl('msg_zipcompress'), $$self{cgi}->escapeHTML($zipfilename), $$self{cgi}->escapeHTML(scalar(@files)>1 ? $files[0].",..." : $files[0]));
	}
	unlink $zipfn;		

	
	my $json = new JSON();
	main::printCompressedHeaderAndContent('200 OK','application/json',$json->encode(\%jsondata),'Cache-Control: no-cache, no-store');
	return 1;
}
sub handleZipUncompress {
	my ($self) = @_;
	my @files = $$self{cgi}->param('files');
	foreach my $file ($$self{cgi}->param('files')) {
		$$self{backend}->uncompressArchive($main::PATH_TRANSLATED.$file, $main::PATH_TRANSLATED);
	}
	my %jsondata = ();
	$jsondata{message} = sprintf($self->tl('msg_zipuncompress'), $$self{cgi}->escapeHTML(join(', ',@files)));
	my $json = new JSON();
	main::printCompressedHeaderAndContent('200 OK','application/json',$json->encode(\%jsondata),'Cache-Control: no-cache, no-store');
	return 1;
}

1;