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

package WebInterface::Renderer;

use strict;

use WebInterface::Common;
our @ISA = ( 'WebInterface::Common' );

use Module::Load;
use Graphics::Magick; 
use POSIX qw(strftime);

use vars qw( %renderer );

sub _getRenderer {
	my ($self) = @_;
	my $view = "WebInterface::View::${main::VIEW}::Renderer";
	$view=~s/[\.\/]+//g;
	$view="WebInterface::View::$main::SUPPORTED_VIEWS[0]::Renderer" unless -f "${main::INSTALL_BASE}lib/perl/WebInterface/View/${main::VIEW}/Renderer.pm";
	return $renderer{$self}{$view} if exists $renderer{$self}{$view};
	eval {
		load $view;
		$renderer{$self}{$view} = $view->new($$self{config},$$self{db});
	};
	die($@) if $@;
	return $renderer{$self}{$view};
}
sub renderWebInterface {
	my ($self, $fn, $ru) =@_;
	my $renderer = $self->_getRenderer();
	return $renderer->render($fn,$ru);
}

sub printStylesAndVHTOCSFiles {
        my ($self,$fn) = @_;
        my $file = $fn =~ /\Q$main::VHTDOCS\E(.*)/ ? $main::INSTALL_BASE.'htdocs/'.$1 : $main::INSTALL_BASE.'lib/'.$$self{backend}->basename($fn);
        $file=~s/\/\.\.\///g;
        my $compression = !-e $file && -e "$file.gz";
        my $nfile = $file;
        $file = "$nfile.gz" if $compression;
        if (open(F,"<$file")) {
                my $header = { -Expires=>strftime("%a, %d %b %Y %T GMT" ,gmtime(time()+ 604800)), -Vary=>'Accept-Encoding' };
                if ($compression) {
                        $$header{-Content_Encoding}='gzip';
                        $$header{-Content_Length}=(stat($file))[7];
                }
                main::printLocalFileHeader($nfile, $header);
                binmode(STDOUT);
                while (read(F,my $buffer, $main::BUFSIZE || 1048576 )>0) {
                        print $buffer;
                }
                close(F);
        } else {
                main::printHeaderAndContent('404 Not Found','text/plain','404 - NOT FOUND');
        }

}
sub printMediaRSS {
        my ($self,$fn,$ru) = @_;
	my $renderer = $self->_getRenderer();
        my $content = qq@<?xml version="1.0" encoding="utf-8" standalone="yes"?><rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/" xmlns:atom="http://www.w3.org/2005/Atom"><channel><title>$ENV{SCRIPT_URI} media data</title><description>$ENV{SCRIPT_URI} media data</description><link>$ENV{SCRIPT_URI}</link>@;
        foreach my $file (sort { $renderer->cmp_files } @{$$self{backend}->readDir($fn, main::getFileLimit($fn), $renderer)}) {
                my $mime = main::getMIMEType($file);
                $mime='image/gif' if $renderer->hasThumbSupport($mime) && $mime !~ /^image/i;
                $content.=qq@<item><title>$file</title><link>$ru$file</link><media:thumbnail type="image/gif" url="$ENV{SCRIPT_URI}$file?action=thumb"/><media:content type="$mime" url="$ENV{SCRIPT_URI}$file?action=image"/></item>@ if $renderer->hasThumbSupport($mime) && $$self{backend}->isReadable("$fn$file") && $$self{backend}->isFile("$fn$file") && !$$self{backend}->isEmpty("$fn$file");
        }
        $content.=qq@</channel></rss>@;
        main::printHeaderAndContent("200 OK", 'appplication/rss+xml', $content);

}
sub printThumbnail {
        my ($self,$fn) = @_;
        my $image = Graphics::Magick->new;
        my $width = $main::THUMBNAIL_WIDTH || $main::ICON_WIDTH || 18;
        if ($main::ENABLE_THUMBNAIL_CACHE) {
                my $uniqname = $fn;
                $uniqname=~s/\//_/g;
                my $cachefile = "$main::THUMBNAIL_CACHEDIR/$uniqname.thumb.gif";
                mkdir($main::THUMBNAIL_CACHEDIR) if ! -e $main::THUMBNAIL_CACHEDIR;
                if (! -e $cachefile || ($$self{backend}->stat($fn))[9] > (stat($cachefile))[9]) {
                        my $lfn = $$self{backend}->getLocalFilename($fn);
                        my $x;
                        my ($w, $h,$s,$f) = $image->Ping($lfn);

                        $x = $image->Read($lfn); warn "$x" if "$x";
                        $image->Set(delay=>200);
                        $image->Crop(height=>$h / ${width} ) if ($h > $width && $w < $width);
                        $image->Resize(geometry=>$width,filter=>'Gaussian') if ($w > $width);
                        $image->Frame(width=>2,height=>2,outer=>0,inner=>2, fill=>'black');
                        $x = $image->Write($cachefile); warn "$x" if "$x";

                }
                if (open(my $cf, "<$cachefile")) {
                        print $$self{cgi}->header(-status=>'200 OK',-type=>main::getMIMEType($cachefile), -ETag=>main::getETag($cachefile), -Content-length=>(stat($cachefile))[7]);
                        binmode $cf;
                        binmode STDOUT;
                        print while(<$cf>);
                        close($cf);
                }
        } else {
                my $lfn = $$self{backend}->getLocalFilename($fn);
                print $$self{cgi}->header(-status=>'200 OK',-type=>'image/gif', -ETag=>main::getETag($fn));
                my ($w, $h,$s,$f) = $image->Ping($lfn);
                my $x;
                $x = $image->Read($lfn); warn "$x" if "$x";
                $image->Set(delay=>200);
                $image->Crop(height=>$h / ${width} ) if ($h > $width && $w < $width);
                $image->Resize(geometry=>$width,filter=>'Gaussian') if ($w > $width);
                $image->Frame(width=>2,height=>2,outer=>0,inner=>2, fill=>'black');
                binmode STDOUT;
                $x = $image->Write('gif:-'); warn "$x" if "$x";
        }
}
sub printImage {
        my ($self, $fn) = @_;
	if (!$$self{backend}->isFile($fn) || $$self{backend}->isEmpty($fn)) {
		main::printHeaderAndContent('404 Not Found','text/plain','404 Not Found');
		return;
	}
        $fn = $$self{backend}->getLocalFilename($fn);
        my $image = Graphics::Magick->new;
        my $x = $image->Read($fn); warn "$x" if "$x";
        $image->Set(delay=>200);
        binmode STDOUT;
        print $$self{cgi}->header(-status=>'200 OK',-type=>'image/gif', -ETag=>main::getETag($fn));
        $x = $image->Write('gif:-'); warn "$x" if "$x";
}
sub printOpenSearch {
        my ($self) = @_;
        my $content = qq@<?xml version="1.0" encoding="utf-8" ?><OpenSearchDescription xmlns="http://a9.com/-/spec/opensearch/1.1/"><ShortName>WebDAV CGI filename</ShortName><Description>WebDAV CGI filename search in $ENV{SCRIPT_URI}</Description><InputEncoding>utf-8</InputEncoding><Url type="text/html" template="$ENV{SCRIPT_URI}?search={searchTerms}" /></OpenSearchDescription>@;
        main::printHeaderAndContent("200 OK", 'text/xml', $content);
}

sub printDAVMount {
        my ($self,$fn) = @_;
        my $su = $ENV{REDIRECT_SCRIPT_URI} || $ENV{SCRIPT_URI};
        my $bn = $$self{backend}->basename($fn);
        $su =~ s/\Q$bn\E\/?//;
        $bn.='/' if $$self{backend}->isDir($fn) && $bn!~/\/$/;
        main::printHeaderAndContent('200 OK','application/davmount+xml',
               qq@<dm:mount xmlns:dm="http://purl.org/NET/webdav/mount"><dm:url>$su</dm:url><dm:open>$bn</dm:open></dm:mount>@);
}

1;
