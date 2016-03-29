#!/usr/bin/perl
##!/usr/bin/speedy  -- -r50 -M7 -t3600
##!/usr/bin/perl -d:NYTProf
#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2016 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
# REQUIREMENTS:
#    - see http://webdavcgi.sf.net/doc.html#requirements
# INSTALLATION:
#    - see http://webdavcgi.sf.net/doc.html#installation
# CHANGES:
#    - see CHANGELOG
# KNOWN PROBLEMS:
#    - see http://webdavcgi.sf.net/
# CONFIG OPTIONS (OLD SETUP SECTION):
#    - see etc/webdav.conf.complete
#########################################################################
package main;
use strict;
use warnings;

use CGI;
use CGI::Carp;
use English qw ( -no_match_vars );
use IO::Handle;
use Module::Load;
use List::MoreUtils qw( any );

use DefaultConfig qw( :all );
use DB::Driver;
use DatabaseEventAdapter;
use Backend::Manager;
use HTTPHelper
  qw( print_header_and_content print_compressed_header_and_content print_header_and_content get_mime_type );

$RELEASE = '1.1.1BETA20160329.2';
our $VERSION = '1.1.1BETA20160329.2';

use vars qw( %_CONFIG $_METHODS_RX %_REQUEST_HANDLERS %_CACHE );

init_defaults();
init();
handle_request();

sub init {
    ## flush immediately:
    *STDERR->autoflush(1);
    *STDOUT->autoflush(1);

    ## before 'new CGI' to read POST requests:
    $REQUEST_METHOD = $ENV{REDIRECT_REQUEST_METHOD} // $ENV{REQUEST_METHOD}
      // 'GET';

    ## create CGI instance:
    $CGI = $REQUEST_METHOD eq 'PUT' ? CGI->new( {} ) : CGI->new();

    ## some config independent objects for convinience:
    $_CONFIG{debug}  = \&debug;
    $_CONFIG{logger} = \&logger;
    $_CONFIG{event}  = get_event_channel();
    $_CONFIG{cache}  = CacheManager::getinstance();

    ## read config file:
    read_config($CONFIGFILE);

    ## for security reasons:
    $CGI::POST_MAX        = $POST_MAX_SIZE;
    $CGI::DISABLE_UPLOADS = !$ALLOW_POST_UPLOADS;

    $PATH_TRANSLATED = $ENV{PATH_TRANSLATED};
    $REQUEST_URI     = $ENV{REQUEST_URI};
    $REMOTE_USER     = $ENV{REDIRECT_REMOTE_USER} // $ENV{REMOTE_USER} // $UID;

    ## some must haves:
    $BUFSIZE //= 1_048_576;
    $TRASH_FOLDER .= $TRASH_FOLDER !~ m{/$}xms ? q{/} : q{};

    ## some config objects for the convinience:
    $_CONFIG{config} = \%_CONFIG;
    $_CONFIG{cgi}    = $CGI;
    $_CONFIG{db}     = $_CACHE{ $ENV{REMOTE_USER} }{dbdriver} //=
      DB::Driver->new( \%_CONFIG );

    DatabaseEventAdapter->new( \%_CONFIG )->register( $_CONFIG{event} );

    my $backend =
      Backend::Manager::getinstance()->get_backend( $BACKEND, \%_CONFIG );
    $_CONFIG{backend} = $backend;

    # 404/rewrite/redirect handling:
    if ( !defined $PATH_TRANSLATED ) {
        $PATH_TRANSLATED = $ENV{REDIRECT_PATH_TRANSLATED};

        if ( !defined $PATH_TRANSLATED
            && ( defined $ENV{SCRIPT_URL} || defined $ENV{REDIRECT_URL} ) )
        {
            my $su = $ENV{SCRIPT_URL} || $ENV{REDIRECT_URL};
            $su =~ s/^$VIRTUAL_BASE//xms;
            $PATH_TRANSLATED = $DOCUMENT_ROOT . $su;
            $PATH_TRANSLATED .=
                 $backend->isDir($PATH_TRANSLATED)
              && $PATH_TRANSLATED !~ m{/$}xms
              && $PATH_TRANSLATED ne q{} ? q{/} : q{};
        }
    }

    $REQUEST_URI =~ s/[?].*$//xms;    ## remove query strings
    $REQUEST_URI .= $backend->isDir($PATH_TRANSLATED)
      && $REQUEST_URI !~ /\/$/xms ? q{/} : q{};
    $REQUEST_URI =~ s/&/%26/xmsg;     ## bug fix (Mac Finder and &)

    umask($UMASK) || croak("Cannot set umask $UMASK.");
    $_CONFIG{event}->broadcast('INIT');
    return;
}

sub handle_request {

    # protect against direct CGI script call:
    if ( !defined $PATH_TRANSLATED || $PATH_TRANSLATED eq q{} ) {
        carp('FORBIDDEN DIRECT CALL!');
        return print_header_and_content('404 Not Found');
    }

    my $method = $CGI->request_method();

    $_METHODS_RX //= _get_methods_rx();

    _debug_request_info($method);

    if ( any { /^\Q${UID}\E$/xms } @FORBIDDEN_UID ) {
        carp("Forbidden UID ${UID}!");
        return print_header_and_content('403 Forbidden');
    }
    if ( $method !~ /$_METHODS_RX/xms ) {
        carp("Method not allowed: $method");
        return print_header_and_content('405 Method Not Allowed');
    }
    if ( !$_REQUEST_HANDLERS{$method} ) {
        my $module = "Requests::${method}";
        load($module);
        $_REQUEST_HANDLERS{$method} = $module->new();
    }
    $_CONFIG{method} = $_REQUEST_HANDLERS{$method};
    $_REQUEST_HANDLERS{$method}->init( \%_CONFIG )->handle();
    if ( $_CONFIG{backend} ) { $_CONFIG{backend}->finalize(); }
    $_CONFIG{event}->broadcast('FINALIZE');
    debug("Modules loaded:".(scalar keys %INC));
    return;
}

sub _debug_request_info {
    my ($method) = @_;
    debug(
"${PROGRAM_NAME} called with UID='${UID}' EUID='${EUID}' GID='${GID}' EGID='${EGID}' method=$method"
    );
    debug("User-Agent: $ENV{HTTP_USER_AGENT}");
    debug("CGI-Version: $CGI::VERSION");
    if ( defined $CGI->http('X-Litmus') ) {
        debug( "${PROGRAM_NAME}: X-Litmus: " . $CGI->http('X-Litmus') );
    }
    if ( defined $CGI->http('X-Litmus-Second') ) {
        debug( "${PROGRAM_NAME}: X-Litmus-Second: "
              . $CGI->http('X-Litmus-Second') );
    }
    debug("METHODS_RX: $_METHODS_RX");
    return;
}

sub _get_methods_rx {
    my @methods =
      qw( GET HEAD POST OPTIONS PUT PROPFIND PROPPATCH MKCOL COPY MOVE DELETE GETLIB );
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
        print {$LOG} localtime()
          . " - ${UID}($REMOTE_USER)\@$ENV{REMOTE_ADDR}: @_\n"
          || carp("Cannot write log entry to $LOGFILE: @_");
        close($LOG) || carp("Cannot close filehandle for '$LOGFILE'");
    }
    else {
        print {*STDERR} "${PROGRAM_NAME}: @_\n"
          || carp("Cannot print log entry to STDERR: @_");
    }
    return;
}

sub debug {
    my ($text) = @_;
    if ($DEBUG) {
        print {*STDERR} "${PROGRAM_NAME}: $text\n"
          || carp("Cannot print debug output to STDERR: $text");
    }
    return;
}

sub get_event_channel {
    my $cache = CacheManager::getinstance();
    my $ec    = $cache->get_entry('eventchannel');
    if ( !$ec ) {
        require Events::EventChannel;
        $ec = Events::EventChannel->new();
        $cache->set_entry( 'eventchannel', $ec );
        foreach my $listener (@EVENTLISTENER) {
            load $listener;
            $listener->new( \%_CONFIG )->register($ec);
        }
    }
    return $ec;
}

sub get_cgi {
    return $CGI;
}

sub get_backend {
    return $_CONFIG{backend};
}

1;
