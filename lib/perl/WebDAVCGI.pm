########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2017 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
#########################################################################
# This is a very pure WebDAV server implementation that
# uses the CGI interface of a Apache webserver.
# Use this script in conjunction with a UID/GID wrapper to
# get and preserve file permissions.
# IT WORKs ONLY WITH UNIX/Linux.
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

package WebDAVCGI;

use strict;
use warnings;

our $VERSION = '2.0';

#use utf8;

use CGI;
use CGI::Carp;
use English qw ( -no_match_vars );
use IO::Handle;
use Module::Load;
use List::MoreUtils qw( any );

use DefaultConfig qw(
  init_defaults read_config
  $CGI $POST_MAX_SIZE $ALLOW_POST_UPLOADS @FORBIDDEN_UID
  $PATH_TRANSLATED $REQUEST_URI $REQUEST_METHOD $HTTP_HOST $REMOTE_USER
  $RELEASE $DEBUG $LOGFILE @EVENTLISTENER $DB $CM $CONFIG
  $TRASH_FOLDER $BUFSIZE $BACKEND $UMASK
  $CONFIGFILE $DOCUMENT_ROOT $VIRTUAL_BASE $D $L
  $ENABLE_LOCK $ENABLE_CALDAV $ENABLE_CALDAV_SCHEDULE
  $ENABLE_CARDDAV $ENABLE_GROUPDAV $ENABLE_BIND
  $ENABLE_ACL $ENABLE_SEARCH $BACKEND_INSTANCE $EVENT_CHANNEL
  %SESSION
);
use DB::Driver;
use DatabaseEventAdapter;
use Backend::Manager;
use HTTPHelper qw( print_header_and_content );
use CacheManager;


$RELEASE = '1.1.2BETA20170215.2';

use vars qw( $_METHODS_RX );

sub new {
    my $class = shift;
    my $self  = {};
    bless $self, $class;
    return $self;
}

sub run {
    my ($self) = @_;
    $self->init_defaults();
    $self->init();
    my $auth = 1;
    if (%SESSION) {
        require SessionAuthenticationHandler;
        $REMOTE_USER = 'unknown';
        $auth = SessionAuthenticationHandler->new($CGI)->authenticate(); # 0 -> login, 1 -> ok, 2->redirect
    }
    if ($auth == 1) {
        $self->init_backend_defaults();
        $self->handle_request();
    } elsif ( $auth != 2 ) {
        require WebInterface;
        WebInterface->new()->init( $self->{config} )->handle_login();
    }
    $self->free();
    return $self;
}

sub init {
    my ($self) = @_;
    ## flush immediately:
    *STDERR->autoflush(1);
    *STDOUT->autoflush(1);

    ## before 'new CGI' to read POST requests:
    $REQUEST_METHOD = $ENV{REDIRECT_REQUEST_METHOD} // $ENV{REQUEST_METHOD}
      // 'GET';

    ## create CGI instance:
    $CGI = $REQUEST_METHOD eq 'PUT' ? CGI->new( {} ) : CGI->new();
    if ($ENV{MOD_PERL}) { $CGI->compile(); }

    ## some config independent objects for convinience:
    $self->{debug}  = $D             = \&debug;
    $self->{logger} = $L             = \&logger;
    $self->{event}  = $EVENT_CHANNEL = $self->_get_event_channel();
    $self->{cache}  = $CM            = CacheManager->new();

    ## read config file:
    read_config( $self, $CONFIGFILE );

    ## for security reasons:
    $CGI::POST_MAX        = $POST_MAX_SIZE;
    $CGI::DISABLE_UPLOADS = !$ALLOW_POST_UPLOADS;

    $PATH_TRANSLATED = $ENV{PATH_TRANSLATED};
    $REQUEST_URI     = $ENV{REQUEST_URI};
    $REMOTE_USER     = $ENV{REDIRECT_REMOTE_USER} // $ENV{REMOTE_USER} // $UID;
    $HTTP_HOST = $ENV{HTTP_HOST} // $ENV{REDIRECT_HTTP_HOST} // 'localhost';

    ## some must haves:
    $BUFSIZE //= 1_048_576;
    $TRASH_FOLDER .= $TRASH_FOLDER !~ m{/$}xms ? q{/} : q{};

    ## some config objects for the convinience:
    $self->{config} = $CONFIG = $self;
    $self->{cgi}    = $CGI;
    $self->{db}     = $DB     = DB::Driver->new($self);
    $self->{dbea}   = DatabaseEventAdapter->new($self)->register( $self->{event} );

    $REQUEST_URI =~ s/&/%26/xmsg;     ## bug fix (Mac Finder and &)
    $REQUEST_URI =~ s/[?].*$//xms;    ## remove query strings

    $self->{event}->broadcast('INIT');
    return $self;
}
sub init_backend_defaults {
    my ( $self ) = @_;
    $BACKEND_INSTANCE =
      Backend::Manager::getinstance()->get_backend( $BACKEND, $self );
    $self->{backend} = $BACKEND_INSTANCE;

    # 404/rewrite/redirect handling:
    if ( !defined $PATH_TRANSLATED ) {
        $PATH_TRANSLATED = $ENV{REDIRECT_PATH_TRANSLATED};

        if ( !defined $PATH_TRANSLATED
            && ( defined $ENV{SCRIPT_URL} || defined $ENV{REDIRECT_URL} ) )
        {
            my $su = $ENV{SCRIPT_URL} // $ENV{REDIRECT_URL};
            $su =~ s/^$VIRTUAL_BASE//xms;
            $PATH_TRANSLATED = $DOCUMENT_ROOT . $su;
            $PATH_TRANSLATED .=
                 $BACKEND_INSTANCE->isDir($PATH_TRANSLATED)
              && $PATH_TRANSLATED !~ m{/$}xms
              && $PATH_TRANSLATED ne q{} ? q{/} : q{};
        }
    }

    $REQUEST_URI .= $BACKEND_INSTANCE->isDir($PATH_TRANSLATED)
      && $REQUEST_URI !~ m{/$}xms ? q{/} : q{};

    umask($UMASK) || croak("Cannot set umask $UMASK.");

    return $self;
}
sub handle_request {
    my ($self) = @_;

    # protection against direct CGI script calls:
    if ( !defined $PATH_TRANSLATED || $PATH_TRANSLATED eq q{} ) {
        carp('FORBIDDEN DIRECT CALL!');
        return print_header_and_content('404 Not Found');
    }

    $_METHODS_RX //= _get_methods_rx();

    $self->_debug_request_info();

    if ( any { /^\Q${UID}\E$/xms } @FORBIDDEN_UID ) {
        carp("Forbidden UID ${UID}!");
        return print_header_and_content('403 Forbidden');
    }
    if ( $REQUEST_METHOD !~ /$_METHODS_RX/xms ) {
        carp("Method not allowed: $REQUEST_METHOD");
        return print_header_and_content('405 Method Not Allowed');
    }
    my $module = "Requests::${REQUEST_METHOD}";
    load($module);
    $self->{method} = $module->new();
    $self->{method}->init($self)->handle();
    $self->{backend}->finalize();
    $self->{event}->broadcast('FINALIZE');
    debug( 'Modules loaded:' . ( scalar keys %INC ) );
    return $self;
}

sub _debug_request_info {
    my ($self) = @_;
    if ( !$DEBUG ) { return; }
    debug("########## $REQUEST_METHOD ##########");
    debug("URI: $REQUEST_URI");
    debug("PATH_TRANSLATED: $PATH_TRANSLATED");
    debug("REMOTE_USER: $REMOTE_USER");
    debug("UID='${UID}' EUID='${EUID}' GID='${GID}' EGID='${EGID}'");
    debug("CONFIGFILE=$CONFIGFILE");

    if ( $ENV{MOD_PERL} ) {
        debug( sprintf "WORKER %s %s time(s) used.\n",
            $PID, ++$self->{runcounter} );
    }
    debug("AGENT: $ENV{HTTP_USER_AGENT}");
    if ( defined $CGI->http('X-Litmus') ) {
        debug( 'LITMUS: X-Litmus: ' . $CGI->http('X-Litmus') );
    }
    if ( defined $CGI->http('X-Litmus-Second') ) {
        debug( 'LITMUS: X-Litmus-Second: ' . $CGI->http('X-Litmus-Second') );
    }
    debug("METHODS_RX: $_METHODS_RX");
    return $self;
}

sub _get_methods_rx {
    my @methods = qw( GET HEAD POST OPTIONS PUT PROPFIND
      PROPPATCH MKCOL COPY MOVE DELETE GETLIB );
    if ($ENABLE_LOCK)   { push @methods, qw( LOCK UNLOCK ); }
    if ($ENABLE_SEARCH) { push @methods, 'SEARCH'; }
    if ( $ENABLE_ACL || $ENABLE_CALDAV || $ENABLE_CARDDAV ) {
        push @methods, 'ACL';
    }
    if ($ENABLE_BIND) { push @methods, qw( BIND UNBIND REBIND ); }
    if (   $ENABLE_ACL
        || $ENABLE_CALDAV
        || $ENABLE_CALDAV_SCHEDULE
        || $ENABLE_CARDDAV
        || $ENABLE_GROUPDAV )
    {
        push @methods, 'REPORT';
    }
    if ( $ENABLE_CALDAV || $ENABLE_CALDAV_SCHEDULE ) {
        push @methods, 'MKCALENDAR';
    }
    return q{^(?:} . join( q{|}, @methods ) . q{)$};
}

sub logger {
    if ( defined $LOGFILE && open my $LOG, '>>', $LOGFILE ) {
        print( {$LOG} localtime()
              . " - ${UID}($REMOTE_USER)\@$ENV{REMOTE_ADDR}: @_\n" )
          || carp("Cannot write log entry to $LOGFILE: @_");
        close($LOG) || carp("Cannot close filehandle for '$LOGFILE'");
    }
    else {
        print( {*STDERR} "${PROGRAM_NAME}: @_\n" )
          || carp("Cannot print log entry to STDERR: @_");
    }
    return;
}

sub debug {
    my ($text) = @_;
    if ($DEBUG) {
        print( {*STDERR} "${PROGRAM_NAME}: $text\n" )
          || carp("Cannot print debug output to STDERR: $text");
    }
    return;
}

sub _get_event_channel {
    my ($self) = @_;
    require Events::EventChannel;
    my $ec = Events::EventChannel->new();
    foreach my $listener (@EVENTLISTENER) {
        load $listener;
        $listener->new($self)->register($ec);
    }
    return $ec;
}

sub free {
    my ($self) = @_;
    foreach my $k (qw(method cache db dbea event backend)) {
        if (defined $self->{$k}) {
            $self->{$k}->free();
            delete $self->{$k};
        }
    }
    delete $self->{config};
    undef $CONFIG;
    undef $CM;
    undef $DB;
    undef $BACKEND_INSTANCE;
    undef $EVENT_CHANNEL;
    delete $self->{cgi};
    undef $CGI;
    delete $self->{debug};
    delete $self->{logger};
    DefaultConfig::free();
    return $self;
}
1;
