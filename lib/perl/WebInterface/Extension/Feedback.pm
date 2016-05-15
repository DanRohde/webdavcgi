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
# contact - recipient address (default: d.rohde@cms.hu-berlin.de)
# subject - email subject (default: "WebDAV CGI")
# clientinfo - if enabled add client info to feedback mail (default: 1 [enabled])
# mailrelay - sets the host(name|ip) of the mail relay  (default: localhost)
# timeout - mailrelay timeout in seconds (default: 2)

package WebInterface::Extension::Feedback;

use strict;
use warnings;

our $VERSION = '2.0';
use base qw( WebInterface::Extension );

use DefaultConfig qw( $PATH_TRANSLATED $REQUEST_URI );
use HTTPHelper qw( print_header_and_content );

use vars qw( $ACTION );

$ACTION = 'feedback';

sub init {
    my ( $self, $hookreg ) = @_;
    if ( !$self->config('contact') ) {
        return;
    }
    my @hooks =
      qw( css locales javascript gethandler posthandler fileactionpopup pref );
    $hookreg->register( \@hooks, $self );
    return;
}

sub handle_hook_fileactionpopup {
    my ( $self, $config, $params ) = @_;
    return {
        action => $ACTION,
        label  => $ACTION,
        path   => ${$params}{path},
        type   => 'li'
    };
}

sub handle_hook_pref {
    my ( $self, $config, $params ) = @_;
    return $self->{cgi}->li(
        $self->{cgi}->a(
            {
                -href       => q{#},
                -class      => 'action ' . $ACTION,
                -title      => $self->tl('feedback'),
                -aria_label => $self->tl('feedback')
            },
            $self->{cgi}->span( { -class => 'label' }, $self->tl('feedback') )
        )
    );
}

sub _sanitize {
    my ( $self, $param ) = @_;
    $param =~ s/[\r\n]//xmsg;
    return $param;
}

sub _send_feedback {
    my ($self) = @_;
    require Net::SMTP;
    my $smtp = Net::SMTP->new(
        $self->config( 'mailrelay', 'localhost' ),
        Timeout => $self->config( 'timeout', 2 )
    );

    my $to      = $self->config('contact');
    my $from    = $self->_sanitize( $self->{cgi}->param('email') // 'unknown' );
    my $subject = $self->config('subject') // 'WebDAV CGI';

    if ( !$smtp->mail($to) || !$smtp->to($to) ) {
        return 0;
    }
    $smtp->data();

    require MIME::Entity;
    my $body = MIME::Entity->build(
        From    => $from,
        To      => $to,
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
            Data => sprintf(
                "URI: %s\nUser Agent: %s\nIP: %s\nCookies: %s\n",
                "https://$ENV{HTTP_HOST}$ENV{REQUEST_URI}",
                $ENV{HTTP_USER_AGENT},
                $ENV{REMOTE_ADDR},
                join ', ',
                map { $_ . q{=} . $self->{cgi}->cookie($_) }
                  $self->{cgi}->cookie()
            ),
            Type        => 'text/plain; charset=UTF-8',
            Disposition => 'attachment',
            Filename    => 'clientinfo.txt',
            Encoding    => '8bit'
        );
    }

    #    if ( $self->{cgi}->param('tel') || $self->{cgi}->param('email') ) {
    #        $body->attach(
    #            Data => sprintf(
    #                "begin:vcard\nemail;internet:%s\ntel;home: %s\nend:vcard",
    #                $self->{cgi}->escapeHTML($from),
    #                $self->{cgi}->escapeHTML($tel)
    #            ),
    #            Type        => 'text/x-vcard; charset=UTF-8',
    #            Encoding    => '8bit',
    #            Disposition => 'attachment',
    #            Filename    => 'contact.vcf'
    #        );
    #    }
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
        if ( $self->{cgi}->param('message') =~ m{^/s*$} ) {
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
        print_header_and_content( '200 OK', 'application/json',
            JSON->new()->encode( \%resp ) );
        return 1;
    }
    return 0;
}

sub handle_hook_gethandler {
    my ( $self, $config, $params ) = @_;
    my $action = $self->{cgi}->param('action') // q{};
    if ( $action eq $ACTION ) {
        print_header_and_content(
            '200 OK',
            'text/html',
            $self->render_template(
                $PATH_TRANSLATED,
                $REQUEST_URI,
                $self->read_template('feedbackform'),
                {
                    feedback_contact => sprintf(
                        $self->tl('feedback.contact'),
                        $self->{cgi}->escape( $self->config('contact') ),
                        $self->{cgi}
                          ->escape( $self->config( 'subject', 'WebDAV CGI' ) )
                    ),
                    feedback_error => sprintf(
                        $self->tl('feedback.error'),
                        $self->{cgi}->escapeHTML( $self->config('contact') )
                    ),
                }
            )
        );
        return 1;
    }
    return 0;
}
1;
