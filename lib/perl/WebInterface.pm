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
        } elsif ($action eq 'opensearch' && $$self{backend}->isDir($main::PATH_TRANSLATED)) {
                $self->getRenderer()->printOpenSearch();
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

1;