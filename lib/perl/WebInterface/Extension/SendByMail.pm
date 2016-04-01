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

our $VERSION = '2.0';

use base qw( WebInterface::Extension );

use MIME::Entity;
use Net::SMTP;
use JSON;
use File::Temp qw( tempfile );
use Module::Load;
use CGI::Carp;

use DefaultConfig qw( $PATH_TRANSLATED $REMOTE_USER $READBUFSIZE );
use HTTPHelper
  qw( print_local_file_header print_header_and_content get_mime_type print_compressed_header_and_content );
use FileUtils qw( get_error_document );

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = qw( css locales javascript posthandler );
    if ( !$self->config( 'disable_fileactionpopup', 0 ) ) {
        push @hooks, 'fileactionpopup';
    }
    if ( $self->config( 'enable_apps', 0 ) ) { push @hooks, 'apps'; }
    if ( !$self->config( 'disable_filelistaction', 0 ) ) {
        push @hooks, 'filelistaction';
    }
    $hookreg->register( \@hooks, $self );
    return $self;
}

sub handle {
    my ( $self, $hook, $config, $params ) = @_;
    my $ret = $self->SUPER::handle( $hook, $config, $params );
    return $ret if $ret;
    if ( $hook eq 'fileactionpopup' ) {
        return {
            action => 'sendbymail',
            label  => 'sendbymail',
            path   => $params->{path},
            type   => 'li'
        };
    }
    if ( $hook eq 'filelistaction' ) {
        return {
            listaction => 'sendbymail',
            label      => '&nbsp;',
            title      => $self->tl('sendbymail'),
            path       => $params->{path},
            classes    => 'uibutton'
        };
    }
    if ( $hook eq 'apps' ) {
        return $self->handleAppsHook( $self->{cgi},
            'listaction sendbymail sel-multi disabled',
            'sendbymail_short', 'sendbymail' );
    }
    if (   $hook eq 'posthandler'
        && defined $self->{cgi}->param('action')
        && $self->{cgi}->param('action') eq 'sendbymail' )
    {
        if ( $self->{cgi}->param('ajax') eq 'preparemail' ) {
            return $self->render_mail_dialog();
        }
        elsif ( $self->{cgi}->param('ajax') eq 'send' ) {
            return $self->send_mail();
        }
        elsif ( $self->{cgi}->param('ajax') eq 'addressbooksearch' ) {
            return $self->search_address();
        }
    }

    return 0;
}

sub search_address {
    my ($self) = @_;
    my %jsondata = ( result => [] );
    if ( $self->config('addressbook') ) {
        my $addressbook = $self->config('addressbook');
        load $addressbook;
        $jsondata{result} = $addressbook->get_mail_addresses( $self,
            scalar $self->{cgi}->param('query') );
    }
    my $content = JSON::encode_json( \%jsondata );
    print_header_and_content(
        '200 OK',
        'application/json',
        $content,
        {
            'Cache-Control' => 'no-cache, no-store',
            -Content_Length => length $content
        }
    );
    return 1;
}

sub build_mail_file {
    my ( $self, $limit, $filehandle ) = @_;
    my $body = MIME::Entity->build( 'Type' => 'multipart/mixed' );
    $body->attach(
        Data => $self->{cgi}->param('message') // q{},
        Type => 'text/plain; charset=UTF-8',
        Encoding => '8bit'
    );

    my ( $zipfh, $zipfn );
    if ( $self->{cgi}->param('zip') ) {
        ( $zipfh, $zipfn ) = tempfile(
            TEMPLATE => '/tmp/webdavcgi-SendByMail-zip-XXXXX',
            CLEANUP  => 1,
            SUFFIX   => '.zip'
        );
        $self->{backend}->compress_files( $zipfh, $PATH_TRANSLATED,
            $self->{cgi}->param('files') );
        close($zipfh) || carp("Cannot close $zipfn.");
        if ( $limit &&  (stat $zipfn )[7] > $limit ) {
            unlink $zipfn;
            return;
        }
        my $zipfilename = $self->{cgi}->param('zipfilename')
          || $self->config( 'defaultzipfilename', 'files.zip' );
        $body->attach(
            Path        => $zipfn,
            Filename    => $zipfilename,
            Type        => get_mime_type($zipfilename),
            Disposition => 'attachment',
            Encoding    => 'base64'
        );
    }
    else {
        my $sumsizes = 0;
        foreach my $fn ( $self->{cgi}->param('files') ) {
            my $file =
              $self->{backend}->getLocalFilename( $PATH_TRANSLATED . $fn );
            my $filesize = (stat $file)[7];
            return if $limit && $filesize > $limit;
            $body->attach(
                Path        => $file,
                Filename    => $fn,
                Type        => get_mime_type($fn),
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
        SUFFIX   => 'mime'
    );
    $body->print($bodyfh);
    return ( $bodyfn, $zipfn );
}

sub check_mail_addresses {
    my ( $self, @addr ) = @_;
    return 0 if scalar(@addr) < 0;
    foreach my $a (@addr) {
        $a =~ s/\s//xmsg;
        $a =~ s/^[^<]*<(.*)>.*$/$1/xmsg;    ### Name <email> > email
        if ( $a !~ /^[[:alnum:]._%+-]+@[[:alnum:].-]+[.][[:upper:]]{2,4}$/xmsi )
        {
            return 0;
        }
    }
    return 1;
}

sub download_mail {
    my ( $self,   %header ) = @_;
    my ( $mailfh, $mailfn ) = tempfile(
        TEMPLATE => '/tmp/webdavcgi-SendByMail-XXXXX',
        CLEANUP  => 1,
        SUFFIX   => '.eml'
    );
    print(  {$mailfh} "To: $header{to}\n"
          . ( $header{cc} ? "Cc: $header{cc}\n" : q{} )
          . "From: $header{from}\nSubject: $header{subject}\nX-Mailer: WebDAV CGI\n"
    ) || carp("Cannot write date to $mailfn.");
    my ( $tmpfh, $zipfile ) = $self->build_mail_file( 0, $mailfh );
    close($mailfh) || carp("Canot close $mailfn.");

    print_local_file_header(
        $mailfn,
        {
            -Content_Disposition => q{attachment; filename="email.eml"},
            -type                => q{application/octet-stream},
        }
    );
    if ( open my $fh, '<', $mailfn ) {
        binmode STDOUT;
        while ( read $fh, my $buffer, $READBUFSIZE ) {
            print($buffer) || carp('Cannot write data to STDOUT.');
        }
        close($fh) || carp("Cannot close $mailfn.");
    }
    else {
        print_header_and_content( get_error_document('404 Not Found') );
    }
    unlink $mailfn;
    if ($zipfile) { unlink $zipfile; }
    return 1;
}

sub send_mail {
    my ($self) = @_;
    my ( $status, $mime ) = ( '200 OK', 'application/json' );
    my %jsondata = ();
    my $cgi      = $self->{cgi};
    my $limit    = $self->config( 'sizelimit', 20_971_520 );
    my ($from)   = $self->sanitize( scalar $cgi->param('from') );
    my @to = $self->sanitize( split /\s*,\s*/xms, scalar $cgi->param('to') );
    my ($strto) = $self->sanitize( scalar $cgi->param('to') );
    my @cc = $self->sanitize( split /\s*,\s+/xms, scalar $cgi->param('cc') );
    my ($strcc)   = $self->sanitize( scalar $cgi->param('cc') );
    my @bcc       = $self->sanitize( scalar $cgi->param('bcc') );
    my ($subject) = $self->sanitize( $cgi->param('subject')
          || $self->config( 'defaultsubject', q{} ) );

    if ( $cgi->param('download') && $cgi->param('download') eq 'yes' ) {
        return $self->download_mail(
            to      => $strto,
            cc      => $strcc,
            from    => $from,
            subject => $subject
        );
    }

    if (   $self->check_mail_addresses(@to)
        && $self->check_mail_addresses($from)
        && ( !@cc  || $self->check_mail_addresses(@cc) )
        && ( !@bcc || $self->check_mail_addresses(@bcc) ) )
    {
        my ( $mailfile, $zipfile ) = $self->build_mail_file($limit);
        if ( !$mailfile || (stat $mailfile )[7] > $limit ) {
            $jsondata{error} = $self->tl('sendbymail_msg_sizelimitexceeded');
        }
        else {
            my $smtp = Net::SMTP->new(
                $self->config( 'mailrelay', 'localhost' ),
                Timeout => $self->config( 'timeout', 2 )
            );
            if ( $self->config( 'login', 0 ) ) {
                $smtp->auth( $self->config('login'),
                    $self->config('password') );
            }
            $smtp->mail($from);
            $smtp->to(@to);
            if (@cc)  { $smtp->cc(@cc); }
            if (@bcc) { $smtp->bcc(@bcc); }
            $smtp->data();
            $smtp->datasend( "To: $strto\n"
                  . ( @cc ? "Cc: $strcc\n" : q{} )
                  . "From: $from\nSubject: $subject\n" );

            if ( open my $fh, '<', $mailfile ) {
                while ( read $fh, my $buffer, $READBUFSIZE ) {
                    $smtp->datasend($buffer);
                }
                close($fh) || carp("Cannot close $mailfile.");
            }
            $smtp->dataend();
            $smtp->quit();
            $jsondata{msg} = sprintf $self->tl('sendbymail_msg_send'),
              join ', ', @to;
        }
        if ($mailfile) { unlink $mailfile; }
        if ($zipfile)  { unlink $zipfile; }
    }
    else {
        $jsondata{error} = $self->tl('sendbymail_msg_illegalemail');
        my @fields = ();
        if ( !$self->check_mail_addresses(@to) )   { push @fields, 'to'; }
        if ( !$self->check_mail_addresses($from) ) { push @fields, 'from'; }
        if ( @cc && !$self->check_mail_addresses(@cc) ) { push @fields, 'cc'; }
        if ( @bcc && !$self->check_mail_addresses(@bcc) ) {
            push @fields, 'bcc';
        }
        $jsondata{field} = join q{,}, @fields;
    }
    my $content = JSON::encode_json( \%jsondata );
    print_header_and_content(
        $status, $mime, $content,
        {
            'Cache-Control' => 'no-cache, no-store',
            -Content_Length => length $content
        }
    );
    return 1;
}

sub sanitize {
    my ( $self, @params ) = @_;
    my @ret = ();
    while ( my $param = shift @params ) {
        $param =~ s/[\r\n]//xmsg;
        push @ret, $param;
    }
    return @ret;
}

sub render_mail_dialog {
    my ($self) = @_;
    my $content = $self->replace_vars( $self->read_template('mailform') );
    my $fntmpl = $content =~ s/<!--FILES\[(.*?)\]-->//xmsg ? $1 : q{};

    my $FILES        = q{};
    my $sumfilesizes = 0;
    foreach my $fn ( $self->{cgi}->param('files') ) {
        my $f = "${PATH_TRANSLATED}${fn}";

      #next if $self->{backend}->isDir($f) || !$self->{backend}->isReadable($f);
        next if !$self->{backend}->isReadable($f);
        my $s  = $fntmpl;
        my $fa = $self->render_file_attributes($fn);
        $s =~ s/\$(\w+)/$$fa{$1}/xmsg;
        $FILES .= $s;
        $sumfilesizes += $fa->{bytesize};
    }
    my ( $l, $lt ) =
      $self->render_byte_val( $self->config( 'sizelimit', 20_971_520 ) );
    my ( $sfz, $sfzt ) = $self->render_byte_val($sumfilesizes);
    my %vars = (
        FILES               => $FILES,
        mailsizelimit       => $l,
        mailsizelimit_title => $lt,
        sumfilesizes        => $sfz,
        sumfilesizes_title  => $sfzt,
        defaultfrom         => $self->config( 'defaultfrom', $REMOTE_USER ),
        defaultto           => $self->config( 'defaultto', q{} ),
        defaultsubject      => $self->config( 'defaultsubject', q{} ),
        defaultmessage      => $self->config( 'defaultmessage', q{} ),
        defaultzipfilename  => $self->config(
            'defaultzipfilename',
            $self->{backend}->basename($PATH_TRANSLATED) . '.zip'
        ),
    );
    $content =~ s/\${?(\w+)}?/exists $vars{$1} ? $vars{$1} : q{}/exmsg;

    print_compressed_header_and_content( '200 OK', 'text/html', $content,
        'Cache-Control: no-cache, no-store' );
    return 1;
}

sub render_file_attributes {
    my ( $self, $fn ) = @_;
    my $bytesize = ($self->{backend}->stat( $PATH_TRANSLATED . $fn ) )[7];
    my ( $s, $st ) = $self->render_byte_val($bytesize);
    my %attr = (
        filename       => $self->{cgi}->escapeHTML($fn),
        filename_short => $self->{cgi}->escapeHTML(
            length($fn) > 50 ? substr( $fn, 0, 40 ) . '...' . substr( $fn, -10 )
            : $fn
        ),
        size       => $s,
        size_title => $st,
        bytesize   => $bytesize,
        filetype   => $self->{backend}->isDir( $PATH_TRANSLATED . $fn ) ? 'dir'
        : 'file',
    );
    return \%attr;
}
1;
