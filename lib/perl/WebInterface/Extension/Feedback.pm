#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2016 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
# contact - TO recipient address[es] (default: d.rohde@cms.hu-berlin.de)
# contact_cc - CC recipient address[es] (default: undef)
# contact_bcc - BCC recipient address[es] (default: undef)
# emailallowed - enables email field in feedback form (default: 0 [disabled])
# domain - mail domain for 'from' address (only used if a REMOTE_USER doesn't contain a domain)
# subject - email subject (default: "WebDAV CGI")
# body - email body (default: "\$msg\n\n%s\n" [%s - client info data, \$msg - message])
# clientinfo - if enabled add client info to feedback mail (default: 1 [enabled])
# mailrelay - sets the host(name|ip) of the mail relay  (default: localhost)
# timeout - mailrelay timeout in seconds (default: 2)
# sizelimit - defines the mail size limit excepted by your mail relay (default: 20971520 [=20MB])

package WebInterface::Extension::Feedback;

use strict;
use warnings;

our $VERSION = '2.0';
use base qw( WebInterface::Extension );

use DefaultConfig
    qw( $PATH_TRANSLATED $REQUEST_URI $REMOTE_USER $REQUEST_URI $HTTP_HOST);
use HTTPHelper qw( print_compressed_header_and_content );

use vars qw( $ACTION );

$ACTION = 'feedback';

sub init {
    my ( $self, $hookreg ) = @_;
    if ( !$self->config('contact') ) {
        return;
    }
    my @hooks = qw( css locales javascript posthandler appsmenu
        fileactionpopup pref body );
    $hookreg->register( \@hooks, $self );
    $self->{sizelimit} = $self->config( 'sizelimit', 20_971_520 );
    return;
}

sub handle_hook_fileactionpopup {
    my ( $self, $config, $params ) = @_;
    return {
        action    => $ACTION,
        label     => $ACTION,
        path      => ${$params}{path},
        type      => 'li',
    };
}

sub handle_hook_appsmenu {
    my ( $self, $config, $params ) = @_;
    return {
        action    => $ACTION,
        label     => $ACTION,
        type      => 'li',
        accesskey => 9,
    };
}
sub handle_hook_pref {
    my ( $self, $config, $params ) = @_;
    return {
        action => $ACTION,
        title  => $self->tl($ACTION),
        attr   => { aria_label => $self->tl($ACTION), tabindex=>0, },
        label  => $self->tl($ACTION),
    };
}

sub handle_hook_body {
    my ($self) = @_;
    return $self->{cgi}->div(
        {   class      => 'feedback-button action feedback',
            title      => $self->tl('feedback'),
            aria_label => $self->tl('feedback'),
            tabindex   => 0
        },
        $self->tl('feedback')
    );
}

sub _get_email {
    my ($self) = @_;
    my $email
        = $self->config( 'emailallowed', 0 )
        ? $self->{cgi}->param('email')
        : undef;
    $email //=
          $REMOTE_USER =~ /\@/xms ? $REMOTE_USER
        : $self->config('domain')
        ? $REMOTE_USER . q{@} . $self->config('domain')
        : $HTTP_HOST =~ /([^.]+[.][^.]+$)/xms ? "$REMOTE_USER\@$1"
        :                                       $REMOTE_USER;
    $email =~ s/[\r\n]//xmsg;
    return $email;
}

sub _get_clientinfo {
    my ($self) = @_;
    return sprintf
        "User: %s\nURI: %s\nUser Agent: %s\nIP: %s\nCookies: %s\n",
        $REMOTE_USER,
        "https://${HTTP_HOST}${REQUEST_URI}",
        $ENV{HTTP_USER_AGENT},
        $ENV{REMOTE_ADDR},
        join ', ',
        map { $_ . q{=} . $self->{cgi}->cookie($_) } $self->{cgi}->cookie();
}

sub _check_data_size {
    my ($self) = @_;
    if ( $self->{sizelimit} <= 0 ) { return 1; }
    my $size = 0;
    $size +=
        $self->{cgi}->param('message')
        ? length $self->{cgi}->param('message')
        : 0;
    $size +=
        $self->{cgi}->param('screenshot')
        ? length $self->{cgi}->param('screenshot')
        : 0;
    $size +=
        $self->config( 'clientinfo', 1 )
        ? length $self->_get_clientinfo()
        : 0;
    return $size <= $self->{sizelimit};
}

sub _get_recipients {
    my ( $self, $email ) = @_;
    return
        defined $email && ref \$email eq 'SCALAR'
        ? [ split /,\s*/xms, $email ]
        : $email;
}

sub _send_feedback {
    my ($self) = @_;
    require Net::SMTP;
    my $smtp = Net::SMTP->new(
        $self->config( 'mailrelay', 'localhost' ),
        Timeout => $self->config( 'timeout', 2 )
    );

    my $to      = $self->_get_recipients( $self->config('contact') );
    my $from    = $self->_get_email();
    my $subject = $self->config('subject') // 'WebDAV CGI';
    my $cc      = $self->_get_recipients( $self->config('contact_cc') );
    my $bcc     = $self->_get_recipients( $self->config('contact_bcc') );

    if ( !$smtp->mail( ${$to}[0] ) || !$smtp->to( @{$to} ) ) {
        return 0;
    }
    if ( $cc && !$smtp->cc( @{$cc} ) ) {
        return 0;
    }
    if ( $bcc & !$smtp->bcc( @{$bcc} ) ) {
        return 0;
    }
    $smtp->data();

    require MIME::Entity;
    my $body = MIME::Entity->build(
        From    => $from,
        To      => $to,
        Cc      => $cc,
        Subject => $subject,
        Type    => 'multipart/mixed'
    );
    $body->attach(
        Data => $self->{cgi}->param('message') // q{},
        Type => 'text/plain; charset=UTF-8',
        Encoding => '8bit'
    );
    if ( $self->config( 'clientinfo', 1 ) ) {
        $body->attach(
            Data        => $self->_get_clientinfo(),
            Type        => 'text/plain; charset=UTF-8',
            Disposition => 'attachment',
            Filename    => 'clientinfo.txt',
            Encoding    => '8bit'
        );
    }
    my $ss;
    if ( ( $ss = $self->{cgi}->param('screenshot') )
        && $ss =~ m{^data:(image/(?:gif|png));base64,(.*)$}xms )
    {
        my ( $type, $bss ) = ( $1, $2 );
        require MIME::Base64;
        $body->attach(
            Data        => MIME::Base64::decode_base64url($bss),
            Type        => $type,
            Disposition => 'attachment',
            Encoding    => 'base64',
            Filename    => 'screenshot.'
                . ( $type =~ m{^image/(gif|png)$}xms ? $1 : 'png' ),
        );
    }

    $smtp->datasend( $body->stringify() );
    $smtp->dataend();
    $smtp->quit();
    undef $smtp;
    undef $body;
    return 1;
}

sub handle_hook_posthandler {
    my ( $self, $config, $params ) = @_;
    my $action = $self->{cgi}->param('action') // q{};
    if ( $action eq $ACTION ) {
        my %resp;
        if ( !$self->_check_data_size() ) {
            $resp{error} = sprintf $self->tl('feedback.sizelimit.exceeded'),
                $self->render_byte_val( $self->{sizelimit} );
        }
        elsif ( $self->{cgi}->param('message') =~ m{^/s*$}xms ) {
            $resp{error}    = $self->tl('feedback.missing.message');
            $resp{required} = 1;
        }
        elsif ( $self->_send_feedback() ) {
            $resp{message} = $self->tl('feedback.response');
        }
        else {
            $resp{error} = sprintf $self->tl('feedback.error'),
                $self->config('contact');
        }
        require JSON;
        print_compressed_header_and_content( '200 OK', 'application/json',
            JSON->new()->encode( \%resp ) );
        return 1;
    }
    if ( $action eq 'getFeedbackDialog' ) {
        print_compressed_header_and_content(
            '200 OK',
            'text/html',
            $self->render_template(
                $PATH_TRANSLATED,
                $REQUEST_URI,
                $self->read_template('feedbackform'),
                {   feedback_contact => sprintf(
                        $self->tl('feedback.contact'),
                        $self->{cgi}->escape( $self->config('contact') ),
                        $self->{cgi}->escape(
                            $self->config( 'subject', 'WebDAV CGI' )
                        ),
                        $self->{cgi}->escape(
                            sprintf $self->config( 'body', "\$msg\n\n%s\n" ),
                            $self->config( 'clientinfo', 1 )
                            ? $self->_get_clientinfo()
                            : q{}
                            )

                    ),
                    feedback_error => sprintf(
                        $self->tl('feedback.error'),
                        $self->{cgi}->escapeHTML( $self->config('contact') )
                    ),
                    email => $self->{cgi}->escapeHTML( $self->_get_email() ),
                    emailallowed => $self->config( 'emailallowed', 0 ),
                }
            )
        );
        return 1;
    }
    return 0;
}
1;