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

sub new {
       my $this = shift;
       my $class = ref($this) || $this;
       my $self = { };
       bless $self, $class;

       $$self{config}=shift;
       $$self{db}=shift;
       $$self{cgi} = $$self{config}->getProperty('cgi');
       $$self{backend} = $$self{config}->getProperty('backend');
       return $self;
}
sub handleGetRequest {
	my ($self) = @_;
	my $fn = $main::PATH_TRANSLATED;
	my $ru = $main::REQUEST_URI;
	my $handled = 1;
	my $action = $$self{cgi}->param('action') || '_undef_';

	if ($main::ENABLE_SYSINFO && $fn =~/\/sysinfo.html\/?$/) {
                $self->getRenderer()->renderSysInfo();
        } elsif ($fn =~ /\/webdav-ui(-custom)?\.(js|css)\/?$/ || $fn =~ /\Q$main::VHTDOCS\E(.*)$/)  {
                $self->getRenderer()->printStylesAndVHTOCSFiles($fn);
        } elsif ($main::ENABLE_DAVMOUNT && $action eq 'davmount' && $$self{backend}->exists($fn)) {
                $self->getRenderer()->printDAVMount($fn);
        } elsif ($main::ENABLE_THUMBNAIL && $action eq 'mediarss' && $$self{backend}->isDir($fn) && $$self{backend}->isReadable($fn)) {
                $self->getRenderer()->printMediaRSS($fn,$ru);
        } elsif ($main::ENABLE_THUMBNAIL && $action eq 'image' && $$self{backend}->isFile($fn) && $$self{backend}->isReadable($fn)) {
                $self->getRenderer()->printImage($fn);
        } elsif ($action eq 'opensearch' && $$self{backend}->isDir($fn)) {
                $self->getRenderer()->printOpenSearch();
        } elsif ($main::ENABLE_THUMBNAIL && $action eq 'thumb' && $$self{backend}->isReadable($fn) && $$self{backend}->isFile($fn)) {
                $self->getRenderer()->printThumbnail($fn);
        } elsif ($main::ENABLE_PROPERTIES_VIEWER && $action eq 'props' && $$self{backend}->exists($fn)) {
                $self->getRenderer()->renderPropertiesViewer($fn, $ru);
        } elsif ($$self{backend}->isDir($fn)) {
                $self->getRenderer()->renderWebInterface($fn,$ru);
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
        if ($$self{cgi}->param('delete')||$$self{cgi}->param('rename')||$$self{cgi}->param('mkcol')||$$self{cgi}->param('changeperm')||$$self{cgi}->param('edit')||$$self{cgi}->param('savetextdata')||$$self{cgi}->param('savetextdatacont')||$$self{cgi}->param('createnewfile')||$$self{cgi}->param('createsymlink')) {
                $self->getFunctions()->handleFileActions();
        } elsif ($main::ALLOW_POST_UPLOADS && $$self{backend}->isDir($main::PATH_TRANSLATED) && defined $$self{cgi}->param('filesubmit')) {
                $self->getFunctions()->handlePostUpload($redirtarget);
        } elsif ($main::ALLOW_ZIP_DOWNLOAD && defined $$self{cgi}->param('zip')) {
                $self->getFunctions()->handleZipDownload($redirtarget);
        } elsif ($main::ALLOW_ZIP_UPLOAD && defined $$self{cgi}->param('uncompress')) {
                $self->getFunctions()->handleZipUpload();
        } elsif ($main::ALLOW_AFSACLCHANGES && $$self{cgi}->param('saveafsacl')) {
                $self->getFunctions()->doAFSSaveACL($redirtarget);
        } elsif ($$self{cgi}->param('afschgrp')|| $$self{cgi}->param('afscreatenewgrp') || $$self{cgi}->param('afsdeletegrp') || $$self{cgi}->param('afsrenamegrp') || $$self{cgi}->param('afsaddusr') || $$self{cgi}->param('afsremoveusr')) {
                $self->getFunctions()->doAFSGroupActions($redirtarget);
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

1;
