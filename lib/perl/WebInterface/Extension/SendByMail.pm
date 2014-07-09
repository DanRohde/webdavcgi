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
# PREREQUISITES:
#   install MIME tools (apt-get install libmime-tools-perl)
# SETUP:
#   mailrelay - sets the host(name|ip) of the mail relay  (default: localhost)
#   login - sets the  login for the mail relay (default: not used)
#   password - sets the password for the login (default: not used)
#   sizelimit - sets the mail size limit (depends on your SMTP setup, default: 20971520 bytes)
#   zipdefaultfilename - sets a default filename for ZIP files
#   enable_savemailasfile - allows to save a mail as a eml file
#   disable_fileactionpopup - disables fileaction entry in popup menu
#   enable_apps - enables sidebar menu entry


package WebInterface::Extension::SendByMail;

use strict;

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension  );

use MIME::Entity;
use Net::SMTP;
use JSON;
use File::Temp qw( tempfile );


sub init { 
	my($self, $hookreg) = @_; 
	
	$self->setExtension('SendByMail');
	
	my @hooks = ('css','locales','javascript', 'posthandler');
	push @hooks,'fileactionpopup' unless $self->config('disable_fileactionpopup');
	push @hooks,'apps' if $self->config('enable_apps');
	$hookreg->register(\@hooks, $self);
}

sub handle { 
	my ($self, $hook, $config, $params) = @_;
	my $ret = $self->SUPER::handle($hook, $config, $params);
	return $ret if $ret;
	if ($hook eq 'fileactionpopup') {
		$ret ={ action=>'sendbymail', label=>'sendbymail', path=>$$params{path}, type=>'li'};	
	} elsif ($hook eq 'apps') {
		$ret = $self->handleAppsHook($$self{cgi},'listaction sendbymail sel-multi disabled','sendbymail_short','sendbymail'); 
	} elsif ($hook eq 'posthandler' && $$self{cgi}->param('action') eq 'sendbymail') {
	
		if ($$self{cgi}->param('ajax') eq 'preparemail') {
			$self->renderMailDialog();
		} elsif ($$self{cgi}->param('ajax') eq 'send') {
			$self->sendMail();
		}
		$ret=1;
	}
	
	return $ret;
}
sub buildMailFile {
	my ($self) = @_;
	my $body = MIME::Entity->build('Type'=>'multipart/mixed');
	$body->attach(Data=>$$self{cgi}->param('message'), Type=>'text/plain; charset=UTF-8', Encoding=>'8bit') if $$self{cgi}->param('message');
	if ($$self{cgi}->param("zip")) {
		my ($tmpfh, $tmpfn) = tempfile();
		$$self{backend}->compressFiles($tmpfh, $main::PATH_TRANSLATED, $$self{cgi}->param('files') );
		my $zipfilename = $$self{cgi}->param('zipfilename') || 'files.zip';
		$body->attach(Path=>$tmpfn, Filename=> $zipfilename, Type=> main::getMIMEType($zipfilename),Disposition=>'attachment', Encoding=>'base64');
		
	} else {
		foreach my $fn ( $$self{cgi}->param('files')) {
			$body->attach(Path=>$$self{backend}->getLocalFilename($main::PATH_TRANSLATED.$fn), Filename=>$fn, Type=> main::getMIMEType($fn),Disposition=>'attachment', Encoding=>'base64');	
		}
	}
	
	my ($bodyfh, $bodyfn) = tempfile();
	$body->print($bodyfh);
	return $bodyfn;
}
sub checkMailAddresses {
	my $self = shift @_;
	for (my $i=0; $i<=$#_;$i++) {
		$_[$i]=~s/\s//g;
		$_[$i]=~s/^[^<]*<(.*)>.*$/$1/g; ### Name <email> > email
		return 0 unless $_[$i] =~ /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/i;
	}
	return 1;
}
sub sendMail {
	my ($self) = @_;
	my ($status,$mime) = ("200 OK", "application/json");
	my %jsondata = ();
	
	my $mailfile = $self->buildMailFile();

	if ((stat($mailfile))[7]>$self->config("sizelimit",20971520)) {
		$jsondata{error} = $self->tl('sendbymail_msg_sizelimitexceeded');
	} else {
		my $cgi = $$self{cgi};
		my ($from) = $self->sanitizeParam($cgi->param('from'));
		my @to = $self->sanitizeParam(split(/\s*,\s*/,$cgi->param('to')));
		my ($subject) = $self->sanitizeParam($cgi->param('subject') || "some files");
		if ($self->checkMailAddresses(@to) && $self->checkMailAddresses($from)) {
		
			my $smtp = Net::SMTP->new($self->config("mailrelay") || 'localhost', Timeout=> $self->config("timeout") || 2);
			$smtp->auth($self->config('login'), $self->config('password'));
			$smtp->mail($from);
			$smtp->to(@to);
			$smtp->data();
			$smtp->datasend(sprintf("To: \%s\n",join(", ",@to)));
			$smtp->datasend("From: $from\n");
			$smtp->datasend("Subject: $subject\n");
			$smtp->datasend("X-Mailer: WebDAV CGI\n");
			if (open(my $fh, "<", $mailfile)) {
				while (read($fh, my $buffer, 1048576)>0) {
					$smtp->datasend($buffer);
				}
				close($fh);
			}
		 	$smtp->dataend();
		 	$smtp->quit();
		 	$jsondata{msg}=sprintf($self->tl('sendbymail_msg_send'),join(', ',@to));
		} else {
			$jsondata{error} = $self->tl('sendbymail_msg_illegalemail');
			$jsondata{field} = ! $self->checkMailAddresses(@to) ? "to" : "from";
		}
	}
	my $json = new JSON();
	main::printHeaderAndContent($status, $mime, $json->encode(\%jsondata), 'Cache-Control: no-cache, no-store');
}
sub sanitizeParam {
	my $self = shift @_;
	my @ret = ();
	while (my $param = shift @_) {
		$param=~s/[\r\n]//sg;
		push @ret, $param;
	} ;
	return @ret;
}

sub renderMailDialog {
	my ($self) = @_;
	my $content = $self->replaceVars($self->readTemplate("mailform"));
	
	$content =~s/<!--FILES\[(.*?)\]-->//sg;
	my $fntmpl = $1;
	my $FILES = "";
	my $sumfilesizes = 0;
	foreach my $fn ($$self{cgi}->param('files')) {
		my $f = "${main::PATH_TRANSLATED}${fn}";
		#next if $$self{backend}->isDir($f) || !$$self{backend}->isReadable($f);
		next if !$$self{backend}->isReadable($f);
		my $s = $fntmpl;
		my $fa = $self->renderFileAttributes($fn); 
		$s=~s/\$(\w+)/$$fa{$1}/sg;
		$FILES.=$s;
		$sumfilesizes += $$fa{bytesize};
	}
	my ($l,$lt) = $self->renderByteValue($self->config('sizelimit',20971520));	
	my ($sfz, $sfzt ) = $self->renderByteValue($sumfilesizes);
	my %vars = (	FILES => $FILES, 
			mailsizelimit => $l, mailsizelimit_title => $lt, 
			zipdefaultfilename => $self->config('zipdefaultfilename') || $$self{backend}->basename($main::PATH_TRANSLATED).'.zip',
			sumfilesizes => $sfz,
			sumfilesizes_title => $sfzt,
			);
	$content=~s/\$(\w+)/$vars{$1} || $1/esg;
	
	main::printCompressedHeaderAndContent('200 OK', 'text/html', $content, 'Cache-Control: no-cache, no-store');
}
sub renderFileAttributes {
	my ($self,$fn) = @_;
	my $bytesize = ($$self{backend}->stat("${main::PATH_TRANSLATED}${fn}"))[7];
	my ($s,$st) = $self->renderByteValue($bytesize);
	my %attr = ( 
		filename => $$self{cgi}->escapeHTML($fn),
		filename_short => $$self{cgi}->escapeHTML(length($fn) > 50 ? substr($fn,0,40) . '...' . substr($fn,-10) : $fn),
		size => $s,
		size_title => $st,
		bytesize => $bytesize,
		filetype => $$self{backend}->isDir($main::PATH_TRANSLATED.$fn) ? 'dir' : 'file',
	);
	return \%attr;
}
sub renderFileSize {
	my($self,$fn) = @_;
	my $size = ($$self{backend}->stat("${main::PATH_TRANSLATED}${fn}"))[7];
	return $size;	
}
sub readTemplate {
	my ($self,$filename) = @_;
	return $self->SUPER::readTemplate($filename, $self->getExtensionLocation("SendByMail","templates/"));
}
1;