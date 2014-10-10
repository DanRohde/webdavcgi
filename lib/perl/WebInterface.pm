#!/usr/bin/perl
#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2011 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package WebInterface;

use strict;
#use warnings;

use WebInterface::Extension::Manager;

# for optimizing css/js:
use Fcntl qw (:flock);
use IO::Compress::Gzip;
use MIME::Base64;
	
sub new {
       my $this = shift;
       my $class = ref($this) || $this;
       my $self = { };
       bless $self, $class;

       $$self{config}=shift;
       $$self{db}=shift;
       $$self{cgi} = $$self{config}->getProperty('cgi');
       $$self{backend} = $$self{config}->getProperty('backend');
       $$self{config}{extensions} = new WebInterface::Extension::Manager($$self{config}, $$self{db});
       $self->optimizeCssAndJs();
       return $self;
}
sub handleGetRequest {
	my ($self) = @_;
	my $handled = 1;
	my $action = $$self{cgi}->param('action') || '_undef_';

	my $retByExt = $$self{config}{extensions}->handle('gethandler', $$self{config});
	my $handledByExt = $retByExt ?  join('',@{$retByExt}) : '';

	if ($handledByExt =~ /1/) {
		## done.
        } elsif ($main::PATH_TRANSLATED =~ /\/webdav-ui(-[^\.\/]+)?\.(js|css)\/?$/ || $main::PATH_TRANSLATED =~ /\Q$main::VHTDOCS\E(.*)$/)  {
                $self->getRenderer()->printStylesAndVHTOCSFiles($main::PATH_TRANSLATED);
        } elsif ($main::ENABLE_DAVMOUNT && $action eq 'davmount' && $$self{backend}->exists($main::PATH_TRANSLATED)) {
                $self->getRenderer()->printDAVMount($main::PATH_TRANSLATED);
        } elsif ($main::ENABLE_THUMBNAIL && $action eq 'mediarss' && $$self{backend}->isDir($main::PATH_TRANSLATED) && $$self{backend}->isReadable($main::PATH_TRANSLATED)) {
                $self->getRenderer()->printMediaRSS($main::PATH_TRANSLATED,$main::REQUEST_URI);
        } elsif ($main::ENABLE_THUMBNAIL && $action eq 'image' && $$self{backend}->isFile($main::PATH_TRANSLATED) && $$self{backend}->isReadable($main::PATH_TRANSLATED)) {
                $self->getRenderer()->printImage($main::PATH_TRANSLATED);
        } elsif ($main::ENABLE_THUMBNAIL && $action eq 'thumb' && $$self{backend}->isReadable($main::PATH_TRANSLATED) && $$self{backend}->isFile($main::PATH_TRANSLATED)) {
                $self->getRenderer()->printThumbnail($main::PATH_TRANSLATED);
        } elsif ($$self{backend}->isDir($main::PATH_TRANSLATED)) {
                $self->getRenderer()->renderWebInterface($main::PATH_TRANSLATED,$main::REQUEST_URI);
	} else {
		$handled = 0;
	}
	return $handled;
}
sub handleHeadRequest {
	my ($self) = @_;
	my $handled = 1;
	if ($$self{backend}->isDir($main::PATH_TRANSLATED)) {
		main::printHeaderAndContent('200 OK','httpd/unix-directory');
	} elsif ($main::PATH_TRANSLATED =~ /\/webdav-ui\.(js|css)$/) {
		main::printLocalFileHeader(-e $main::INSTALL_BASE.basename($main::PATH_TRANSLATED) ? $main::INSTALL_BASE.basename($main::PATH_TRANSLATED) : "${main::INSTALL_BASE}lib/".basename($main::PATH_TRANSLATED));
	} else {
		$handled = 0;
	}
	return $handled;
}

sub handlePostRequest {
	my ($self) =@_;
        my $redirtarget = $main::REQUEST_URI;
        $redirtarget =~s/\?.*$//; # remove query
	my $handled = 1;
	
	my $retByExt = $$self{config}{extensions}->handle('posthandler', $$self{config});
	my $handledByExt = $retByExt ?  join('',@{$retByExt}) : '';

	if ($handledByExt =~ /1/) {
		## done.	
	} elsif ($self->getFunctions()->handleFileActions()) {
                ## done.
        } elsif ($main::ALLOW_POST_UPLOADS && $$self{backend}->isDir($main::PATH_TRANSLATED) && defined $$self{cgi}->param('filesubmit')) {
                $self->getFunctions()->handlePostUpload($redirtarget);
        } elsif ($main::ENABLE_CLIPBOARD && $$self{cgi}->param('action')) {
                $self->getFunctions()->handleClipboardAction($redirtarget);
	} else {
		$handled = 0;
	}
	return $handled;
}

sub getFunctions {
	my $self = shift;
        require WebInterface::Functions;
        return new WebInterface::Functions($$self{config},$$self{db});
}
sub getRenderer {
	my $self = shift;
        require WebInterface::Renderer;
        return new WebInterface::Renderer($$self{config},$$self{db});
}

sub optimizer_isOptimized {
	my ($self) = @_;
	return $$self{isoptimized};
}

sub optimizer_getFilepath {
	my ($self, $ft) = @_;
	my $tmp = $main::OPTIMIZERTMP || $main::THUMBNAIL_CACHEDIR || '/var/tmp';
	my $optimizerbasefn = "${main::CONFIGFILE}_${main::RELEASE}_${main::REMOTE_USER}";
	$optimizerbasefn=~s/[\/\.]/_/g;
	my $optimizerbase =$tmp.'/'.$optimizerbasefn;
	return "${optimizerbase}.$ft";
}
sub optimizeCssAndJs {
	my ($self) = @_;
	return if $$self{isoptimized} || $$self{notoptimized};
	$$self{isoptimized} = 0; 
	
	my $csstargetfile = $self->optimizer_getFilepath('css').'.gz';
	my $jstargetfile =  $self->optimizer_getFilepath('js').'.gz';
	if ((-e $csstargetfile && !-w $csstargetfile) || (-e $jstargetfile && !-w $jstargetfile)) {
		 $$self{notoptimized}=1;
		 warn("Cannot write optimized CSS and JavaScript to $csstargetfile and/or $jstargetfile");
		 return;
	}
	if (-r $jstargetfile && -r $csstargetfile && (stat($jstargetfile))[10] > (stat($main::CONFIGFILE))[10]) {
		$$self{isoptimized} = 1;
		return;
	}
	
	## collect CSS:
	my $tags = join("\n", @{$$self{config}{extensions}->handle('css') || []});
	my $content = $self->optimizer_ExtractContentFromTagsAndAttributes($tags,'css');
	$self->optimizer_writeContent2Zip($csstargetfile, \$content) if $content;
	
	## collect JS:	
	$tags=join("\n",@{$$self{config}{extensions}->handle('javascript') || []});
	$content = $self->optimizer_ExtractContentFromTagsAndAttributes($tags,'js');
	$self->optimizer_writeContent2Zip($jstargetfile, \$content) if $content;
	
	$$self{isoptimized} = 1;
}
sub optimizer_writeContent2Zip {
	my ($self, $file, $contentref) = @_;
	if (open(my $fh, ">", $file )) {
		flock($fh, LOCK_EX);
		my $z = new IO::Compress::Gzip($fh);
		$z->print($$contentref);
		$z->close();
		flock($fh, LOCK_UN);
		close($fh);
		return 1;
	}  
	return 0;
}
sub optimizer_encodeImage {
	my($self,$basepath, $url) = @_;
	return "url($url)" if $url=~/^data:image/;
	my $ifn = "$basepath/$url";
	my $mime = main::getMIMEType($ifn);
	if (open(my $ih, '<', $ifn)) {
		main::debug("encode image $ifn");
		my $buffer;
		binmode $ih;
		read($ih, $buffer, (stat($ih))[7]);
		close($ih);
		return 'url(data:'.$mime.';base64,'. encode_base64($buffer,'') .')';
	} else {
		warn("Cannot read $ifn.");
	}
}

sub optimizer_Collect {
	my ($self, $contentref, $filename, $data, $type) = @_;
	if ($filename) {
		my $full=$filename;
		$full=~s@^.*${main::VHTDOCS}_EXTENSION\((.*?)\)_(.*)@${main::INSTALL_BASE}lib/perl/WebInterface/Extension/$1$2@g;
		main::debug("collect $type from $full");
		my $fc = (main::getLocalFileContentAndType($full))[1];
		if ($type eq 'css') {
			my $basepath = main::getParentURI($full);
			$fc =~ s/url\((.*?)\)/$self->optimizer_encodeImage($basepath, $1)/iegs;
		}
		$$contentref.= $fc;
		main::debug("optimizer_Collect: $full collected.");
	} 
	$$contentref .= $data if $data;
}
sub optimizer_ExtractContentFromTagsAndAttributes {
	my ($self,$data,$type) = @_;
	my $content = "";	
	if ($type eq 'css') {
		$data=~s@<style[^>]*>(.*?)</style>@$self->optimizer_Collect(\$content, undef, $1, $type)@iegs;
		$data=~s@<link .*?href="(.*?)"@$self->optimizer_Collect(\$content, $1, undef, $type)@iegs;
	} else {
		$data=~s@<script .*?src="([^>"]+)".*?>(.*?)</script>@$self->optimizer_Collect(\$content, $1, $2, $type)@iegs;
	}
	
	return $content;
}
sub isOptimized {
	my ($self) = @_;
	return $$self{isoptimized};
}

1;