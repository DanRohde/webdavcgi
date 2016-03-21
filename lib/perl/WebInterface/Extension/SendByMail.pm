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
#   login - sets the login for the mail relay (default: not used)
#   password - sets the password for the login (default: not used)
#   sizelimit - sets the mail size limit
#               (depends on your SMTP setup, default: 20971520 bytes)
#   defaultfrom - sets default sender mail addresss (default: REMOTE_USER)
#   defaultto - sets default recipient (default: empty string)
#   defaultsubject - sets default subject (default: empty string)
#   defaultmessage - sets default message (default: empty string)
#   defaultzipfilename - sets a default filename for ZIP files
#   enable_savemailasfile - allows to save a mail as a eml file
#   disable_fileactionpopup - disables entry in popup menu
#   disable_filelistaction - disables entry in toolbar
#   enable_apps - enables sidebar menu entry
#   addressboook - Perl module name with a addressbook implementation

package WebInterface::Extension::SendByMail;

use strict;
use warnings;

use base qw( WebInterface::Extension );

use MIME::Entity;
use Net::SMTP;
use JSON;
use File::Temp qw( tempfile );
use Module::Load;

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = ( 'css', 'locales', 'javascript', 'posthandler' );
    push @hooks, 'fileactionpopup'
        unless $self->config( 'disable_fileactionpopup', 0 );
    push @hooks, 'apps' if $self->config( 'enable_apps', 0 );
    push @hooks, 'filelistaction'
        unless $self->config( 'disable_filelistaction', 0 );
    $hookreg->register( \@hooks, $self );
    return 1;
}

sub handle {
    my ( $self, $hook, $config, $params ) = @_;
    my $ret = $self->SUPER::handle( $hook, $config, $params );
    return $ret if $ret;
    if ( $hook eq 'fileactionpopup' ) {
        $ret = {
            action => 'sendbymail',
            label  => 'sendbymail',
            path   => $$params{path},
            type   => 'li'
        };
    }
    elsif ( $hook eq 'filelistaction' ) {
        $ret = {
            listaction => 'sendbymail',
            label      => '&nbsp;',
            title      => $self->tl('sendbymail'),
            path       => $$params{path},
            classes    => "uibutton"
        };
    }
    elsif ( $hook eq 'apps' ) {
        $ret
            = $self->handleAppsHook( $$self{cgi},
            'listaction sendbymail sel-multi disabled',
            'sendbymail_short', 'sendbymail' );
    }
    elsif ($hook eq 'posthandler'
        && defined $$self{cgi}->param('action') && $$self{cgi}->param('action') eq 'sendbymail' )
    {

        if ( $$self{cgi}->param('ajax') eq 'preparemail' ) {
            $ret = $self->renderMailDialog();
        }
        elsif ( $$self{cgi}->param('ajax') eq 'send' ) {
            $ret = $self->sendMail();
        }
        elsif ( $$self{cgi}->param('ajax') eq 'addressbooksearch' ) {
            $ret = $self->searchAddress();
        }
    }

    return $ret;
}

sub searchAddress {
    my ($self) = @_;
    my %jsondata = ( result => [] );
    if ( $self->config('addressbook') ) {
        my $addressbook = $self->config('addressbook');
        load $addressbook;
        $jsondata{result} = $addressbook->getMailAddresses( $self, scalar $$self{cgi}->param('query') );
    }
    my $content = JSON->new->encode( \%jsondata );
    main::print_header_and_content(
        '200 OK', 'application/json',
        $content,
        { 'Cache-Control'=> 'no-cache, no-store', -Content_Length => length $content }
    );
    return 1;
}

sub buildMailFile {
    my ( $self, $limit, $filehandle ) = @_;
    my $body = MIME::Entity->build( 'Type' => 'multipart/mixed' );
    $body->attach(
        Data => $$self{cgi}->param('message') || '',
        Type => 'text/plain; charset=UTF-8',
        Encoding => '8bit'
    );

    my ( $zipfh, $zipfn );
    if ( $$self{cgi}->param("zip") ) {
        ( $zipfh, $zipfn ) = tempfile(
            TEMPLATE => '/tmp/webdavcgi-SendByMail-zip-XXXXX',
            CLEANUP  => 1,
            SUFFIX   => ".zip"
        );
        $$self{backend}->compressFiles( $zipfh, $main::PATH_TRANSLATED,
            $$self{cgi}->param('files') );
        close($zipfh);
        if ( $limit && ( stat($zipfn) )[7] > $limit ) {
            unlink $zipfn;
            return;
        }
        my $zipfilename = $$self{cgi}->param('zipfilename')
            || $self->config( 'defaultzipfilename', 'files.zip' );
        $body->attach(
            Path        => $zipfn,
            Filename    => $zipfilename,
            Type        => main::get_mime_type($zipfilename),
            Disposition => 'attachment',
            Encoding    => 'base64'
        );
    }
    else {
        my $sumsizes = 0;
        foreach my $fn ( $$self{cgi}->param('files') ) {
            my $file = $$self{backend}
                ->getLocalFilename( $main::PATH_TRANSLATED . $fn );
            my $filesize = ( stat($file) )[7];
            return if $limit && $filesize > $limit;
            $body->attach(
                Path        => $file,
                Filename    => $fn,
                Type        => main::get_mime_type($fn),
                Disposition => 'attachment',
                Encoding    => 'base64'
            );
            $sumsizes += $filesize;
            return if $limit && $sumsizes > $limit;
        }
    }
    if ($filehandle) {
        $body->print($filehandle);
        return ( $filehandle, $zipfn );
    }
    my ( $bodyfh, $bodyfn ) = tempfile(
        TEMPLATE => '/tmp/webdavcgi-SendByMail-XXXXX',
        CLEANUP  => 1,
        SUFFIX   => "mime"
    );
    $body->print($bodyfh);
    return ( $bodyfn, $zipfn );
}

sub checkMailAddresses {
    my ($self, @addr) = @_;
    return 0 if scalar(@addr) < 0;
    foreach my $a (@addr ) {
        $a =~ s/\s//xmsg;
        $a =~ s/^[^<]*<(.*)>.*$/$1/xmsg;    ### Name <email> > email
        return 0
            unless $a =~ /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/xmsi;
    }
    return 1;
}
sub downloadMail {
    my ($self, %header) = @_;
    my ( $mailfh, $mailfn ) = tempfile(
            TEMPLATE => '/tmp/webdavcgi-SendByMail-XXXXX',
            CLEANUP  => 1,
            SUFFIX   => ".eml"
        );
        print $mailfh "To: $header{to}\n"
            . ( $header{cc} ? "Cc: $header{cc}\n" : '' )
            . "From: $header{from}\nSubject: $header{subject}\nX-Mailer: WebDAV CGI\n";
        my ( $tmpfh, $zipfile ) = $self->buildMailFile( 0, $mailfh );
        close($mailfh);

        main::print_local_file_header(
            $mailfn,
            {   -Content_Disposition => q{attachment; filename="email.eml"},
                -type                => q{application/octet-stream},
            }
        );
        if ( open( my $fh, "<", $mailfn ) ) {
            binmode(STDOUT);
            while ( read( $fh, my $buffer, $main::BUFSIZE || 1048576 ) > 0 ) {
                print $buffer;
            }
            close($fh);
        }
        else {
            main::print_header_and_content(
                main::getErrorDocument(
                    '404 Not Found',
                    'text/plain', '404 - FILE NOT FOUND'
                )
            );
        }
        unlink $mailfn;
        unlink $zipfile if $zipfile;
        return 1;
}
sub sendMail {
    my ($self) = @_;
    my ( $status, $mime ) = ( '200 OK', 'application/json' );
    my %jsondata = ();
    my $cgi      = $$self{cgi};
    my $limit    = $self->config( "sizelimit", 20971520 );
    my ($from)   = $self->sanitizeParam( scalar $cgi->param('from') );
    my @to       = $self->sanitizeParam(
        split /\s*,\s*/xms, scalar $cgi->param('to') );
    my ($strto) = $self->sanitizeParam( scalar $cgi->param('to') );
    my @cc = $self->sanitizeParam(
        split( /\s*,\s+/xms, scalar $cgi->param('cc') ) );
    my ($strcc) = $self->sanitizeParam( scalar $cgi->param('cc') );
    my @bcc = $self->sanitizeParam( scalar $cgi->param('bcc') );
    my ($subject)
        = $self->sanitizeParam( $cgi->param('subject')
            || $self->config( 'defaultsubject', '' ) );

    if ( $cgi->param('download') && $cgi->param('download') eq "yes" ) {
        return $self->downloadMail(to=>$strto, cc=>$strcc, from=>$from, subject => $subject);
    }

    if (   $self->checkMailAddresses(@to)
        && $self->checkMailAddresses($from)
        && ( !@cc  || $self->checkMailAddresses(@cc) )
        && ( !@bcc || $self->checkMailAddresses(@bcc) ) )
    {
        my ( $mailfile, $zipfile ) = $self->buildMailFile($limit);
        if ( !$mailfile || ( stat($mailfile) )[7] > $limit ) {
            $jsondata{error} = $self->tl('sendbymail_msg_sizelimitexceeded');
        }
        else {
            my $smtp = Net::SMTP->new(
                $self->config( 'mailrelay', 'localhost' ),
                Timeout => $self->config( 'timeout', 2 )
            );
            $smtp->auth( $self->config('login'), $self->config('password') )
                if $self->config( 'login', 0 );
            $smtp->mail($from);
            $smtp->to(@to);
            $smtp->cc(@cc)   if @cc;
            $smtp->bcc(@bcc) if @bcc;
            $smtp->data();
            $smtp->datasend( "To: $strto\n"
                    . ( @cc ? "Cc: $strcc\n" : '' )
                    . "From: $from\nSubject: $subject\n" );

            if ( open( my $fh, "<", $mailfile ) ) {
                while ( read( $fh, my $buffer, 1048576 ) > 0 ) {
                    $smtp->datasend($buffer);
                }
                close($fh);
            }
            $smtp->dataend();
            $smtp->quit();
            $jsondata{msg} = sprintf( $self->tl('sendbymail_msg_send'),
                join( ', ', @to ) );
        }
        unlink $mailfile if $mailfile;
        unlink $zipfile  if $zipfile;
    }
    else {
        $jsondata{error} = $self->tl('sendbymail_msg_illegalemail');
        my @fields = ();
        push @fields, 'to'   if !$self->checkMailAddresses(@to);
        push @fields, 'from' if !$self->checkMailAddresses($from);
        push @fields, 'cc'   if @cc && !$self->checkMailAddresses(@cc);
        push @fields, 'bcc'  if @bcc && !$self->checkMailAddresses(@bcc);
        $jsondata{field} = join( ',', @fields );
    }
    my $content = JSON->new->encode( \%jsondata );
    main::print_header_and_content(
        $status, $mime,
        $content,
        { 'Cache-Control'=> 'no-cache, no-store', -Content_Length => length $content }
    );
    return 1;
}

sub sanitizeParam {
    my ($self, @params) = @_;
    my @ret  = ();
    while ( my $param = shift @params ) {
        $param =~ s/[\r\n]//xmsg;
        push @ret, $param;
    }
    return @ret;
}

sub renderMailDialog {
    my ($self) = @_;
    my $content = $self->replace_vars( $self->read_template('mailform') );
    my $fntmpl = $content =~ s/<!--FILES\[(.*?)\]-->//xmsg ? $1 : q{};
    
    my $FILES        = q{};
    my $sumfilesizes = 0;
    foreach my $fn ( $$self{cgi}->param('files') ) {
        my $f = "${main::PATH_TRANSLATED}${fn}";

      #next if $$self{backend}->isDir($f) || !$$self{backend}->isReadable($f);
        next if !$$self{backend}->isReadable($f);
        my $s  = $fntmpl;
        my $fa = $self->renderFileAttributes($fn);
        $s =~ s/\$(\w+)/$$fa{$1}/xmsg;
        $FILES .= $s;
        $sumfilesizes += $$fa{bytesize};
    }
    my ( $l, $lt )
        = $self->render_byte_val( $self->config( 'sizelimit', 20971520 ) );
    my ( $sfz, $sfzt ) = $self->render_byte_val($sumfilesizes);
    my %vars = (
        FILES               => $FILES,
        mailsizelimit       => $l,
        mailsizelimit_title => $lt,
        sumfilesizes        => $sfz,
        sumfilesizes_title  => $sfzt,
        defaultfrom => $self->config( 'defaultfrom', $main::REMOTE_USER ),
        defaultto          => $self->config( 'defaultto',      '' ),
        defaultsubject     => $self->config( 'defaultsubject', '' ),
        defaultmessage     => $self->config( 'defaultmessage', '' ),
        defaultzipfilename => $self->config(
            'defaultzipfilename',
            $$self{backend}->basename($main::PATH_TRANSLATED) . '.zip'
        ),
    );
    $content =~ s/\$\{?(\w+)\}?/exists $vars{$1} ? $vars{$1} : ''/xmesg;

    main::print_compressed_header_and_content( '200 OK', 'text/html', $content,
        'Cache-Control: no-cache, no-store' );
    return 1;
}

sub renderFileAttributes {
    my ( $self, $fn ) = @_;
    my $bytesize
        = ( $$self{backend}->stat( $main::PATH_TRANSLATED . $fn ) )[7];
    my ( $s, $st ) = $self->render_byte_val($bytesize);
    my %attr = (
        filename       => $$self{cgi}->escapeHTML($fn),
        filename_short => $$self{cgi}->escapeHTML(
            length($fn) > 50
            ? substr( $fn, 0, 40 ) . '...' . substr( $fn, -10 )
            : $fn
        ),
        size       => $s,
        size_title => $st,
        bytesize   => $bytesize,
        filetype   => $$self{backend}->isDir( $main::PATH_TRANSLATED . $fn )
        ? 'dir'
        : 'file',
    );
    return \%attr;
}

sub renderFileSize {
    my ( $self, $fn ) = @_;
    my $size = ( $$self{backend}->stat( $main::PATH_TRANSLATED . $fn ) )[7];
    return $size;
}
1;
