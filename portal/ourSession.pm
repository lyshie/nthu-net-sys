#!/usr/bin/perl -w

#
#    Copyright (C) 2011~2014 SHIE, Li-Yi (lyshie) <lyshie@mx.nthu.edu.tw>
#
#    https://github.com/lyshie
#	
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation,  either version 3 of the License,  or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful, 
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not,  see <http://www.gnu.org/licenses/>.
#
package ourSession;

BEGIN { $INC{'ourSession.pm'} ||= __FILE__ }

use strict;
use warnings;

use Exporter;
use CGI::Session;
use File::stat;
use URI::Split qw(uri_split);
use FindBin qw($Bin);
use lib "$Bin";
use ourLanguage;

our @ISA    = qw(Exporter);
our @EXPORT = qw(
    sessionCheck
    sessionNew
    sessionDelete
    sessionSet
);

my $SESSION_PATH = "$Bin/tmp";
mkdir($SESSION_PATH) if ( !-d $SESSION_PATH );

=comment
my $ACIXSTORE_PATH = "$Bin/acixstore";
mkdir($ACIXSTORE_PATH) if ( !-d $ACIXSTORE_PATH );

sub _acixstoreSet {
    my ( $acixstore, $sid ) = @_;

    my $file = "$ACIXSTORE_PATH/$acixstore";
    open( FH, ">$file" );
    print FH $sid;
    close(FH);

    return $sid;
}

sub _acixstoreGet {
    my ($acixstore) = @_;

    my $file = "$ACIXSTORE_PATH/$acixstore";
    if ( -f $file ) {
        open( FH, $file );
        my $sid = <FH>;
        chomp($sid);
        close(FH);

        return $sid;
    }
    else {
        return undef;
    }
}

sub _acixstoreDelete {
    my ($acixstore) = @_;

    my $file = "$ACIXSTORE_PATH/$acixstore";

    if ( -f $file ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub _acixstoreFree {
    my ( $path, $lifetime ) = @_;
    opendir( DH, $path );
    my @acixstores = grep { -f "$path/$_" } readdir(DH);
    close(DH);

    my $now = time();
    eval {
        foreach (@acixstores)
        {
            my $st = stat("$path/$_");
            if ( ( $now - $st->atime() ) > $lifetime ) {
                unlink("$path/$_");
            }
        }
    };
}
=cut

sub sessionInvalidReferer {
    return -4;
}

sub sessionMismatchIP {
    return -2;
}

sub sessionExpire {
    return -1;
}

sub sessionEmpty {
    return 0;
}

sub sessionFree {
    my ( $path, $lifetime ) = @_;
    opendir( DH, $path );
    my @sessions = grep { -f "$path/$_" && m/^cgisess_/ } readdir(DH);
    close(DH);

    my $now = time();
    eval {
        foreach (@sessions)
        {
            my $st = stat("$path/$_");
            if ( ( $now - $st->atime() ) > $lifetime ) {
                unlink("$path/$_");
            }
        }
    };
}

sub sessionCheck {
    my ( $sid, $disable_ip_check ) = @_;

    my $status = 1;

    # lyshie_20100805: for debug use
    _debugConnectionInfo();

    $status = sessionEmpty() unless ($sid);

    my $s = CGI::Session->load( "driver:file;serializer:FreezeThaw;id:md5",
        $sid, { 'Directory' => "$SESSION_PATH" } );

    if ( $s->is_expired() ) {
        $status = sessionExpire();
        return ( $status, '', undef );
    }

    if ( !defined($s) || $s->is_empty() ) {
        $status = sessionEmpty();
        return ( $status, '', undef );
    }

    my ($name,           $name_en,   $id,        $persistent_id,
        $ip,             $timestamp, $acixstore, $language,
        $condition_bool, $condition, $prev_page
        )
        = (
        $s->param('name')           || '',
        $s->param('name_en')        || '',
        $s->param('id')             || '',
        $s->param('persistent_id')  || '',
        $s->param('ip')             || '',
        $s->param('timestamp')      || '',
        $s->param('acixstore')      || '',
        $s->param('language')       || '',
        $s->param('condition_bool') || 0,
        $s->param('condition')      || '',
        $s->param('prev_page')      || '',
        );

    my $ua  = $ENV{'HTTP_USER_AGENT'} || '';
    my $ra  = $ENV{'REMOTE_ADDR'}     || '';
    my $ref = $ENV{'HTTP_REFERER'}    || '';

    #if ( ( $useragent ne $ua ) || ( $ip ne $ra ) ) {
    #    $status = sessionEmpty();
    #}
    if ( !$disable_ip_check && ( $ip ne '' ) && ( $ip ne $ra ) ) {
        $status = sessionMismatchIP();
        return ( $status, '', undef );
    }

    # lyshie_20100825: disable referer check
    #if ( $ref !~ m{^(?:http|https)://.*\.nthu\.edu\.tw(?:\:\d+)*/}i ) {
    #    $status = sessionInvalidReferer();
    #    return ( $status, '', undef );
    #}

    # lyshie_20100201: auto detect browser language, set $G_LANG
    detectLanguage($language);

    # lyshie_20111230: record the previous page name for redirect
    my $page = defined( $ENV{'SCRIPT_NAME'} ) ? $ENV{'SCRIPT_NAME'} : '';
    my ( $scheme, $auth, $path, $query, $frag ) = uri_split($page);
    my @parts = split( /\//, $path );
    $page = $parts[-1] if (@parts);
    $page = 'portal.cgi' unless ($page);
    $s->flush();    # close & flush before set
    if ( $page !~ m/(?:switch\-user|ask)\.cgi/ ) {
        sessionSet( $sid, 'prev_page', $page );
    }

    return ( $status, $s->id(), $s->dataref() );
}

sub sessionNew {
    my (%h) = @_;

    #my $sid = _acixstoreGet( $h{'acixstore'} );
    #return $sid if ( defined($sid) );

    my $s = new CGI::Session( "driver:file;serializer:FreezeThaw;id:md5",
        undef, { 'Directory' => "$SESSION_PATH" } );

    $s->param( 'name',           $h{'name'}           || '' );
    $s->param( 'name_en',        $h{'name_en'}        || '' );
    $s->param( 'language',       $h{'language'}       || '' );
    $s->param( 'condition_bool', $h{'condition_bool'} || 0 );
    $s->param( 'condition',      $h{'condition'}      || '' );
    $s->param( 'id',             $h{'id'}             || '' );
    $s->param( 'persistent_id',  $h{'persistent_id'}  || '' );
    $s->param( 'ip',             $h{'ip'}             || '' );
    $s->param( 'timestamp',      $h{'timestamp'}      || '' );
    $s->param( 'acixstore',      $h{'acixstore'}      || '' );
    $s->param( 'openid',    $h{'openid'}    || '' );    # lyshie: OpenID
    $s->param( 'prev_page', $h{'prev_page'} || '' );
    $s->expire('20m');
    $s->flush();

    #_acixstoreSet( $h{'acixstore'}, $s->id() );

    # lyshie_20070107: for security reason, free unused sessions
    #                  after 1 hour (3600 seconds)
    sessionFree( "$SESSION_PATH", 60 * 60 );

    #_acixstoreFree( "$ACIXSTORE_PATH", 60 * 60 );

    return $s->id();
}

sub sessionDelete {
    my ($sid) = @_;

    return 0 unless ($sid);

    my $s = CGI::Session->load( "driver:file;serializer:FreezeThaw;id:md5",
        $sid, { 'Directory' => "$SESSION_PATH" } );

    if ( defined($s) ) {
        $s->delete();
        $s->flush();

        return 1;
    }
    else {
        return 0;
    }
}

sub sessionSet {
    my ( $sid, $key, $value ) = @_;

    my $s = CGI::Session->load( "driver:file;serializer:FreezeThaw;id:md5",
        $sid, { 'Directory' => "$SESSION_PATH" } );

    my $result;
    $result = $s->param( $key, $value );
    $s->flush();

    return $result;
}

sub _debugConnectionInfo {
    my $ua  = $ENV{'HTTP_USER_AGENT'} || 'unknown';
    my $ra  = $ENV{'REMOTE_ADDR'}     || 'unknown';
    my $ref = $ENV{'HTTP_REFERER'}    || 'unknown';
    my $uri = $ENV{'REQUEST_URI'}     || 'unknown';

    open( TMP, ">>/tmp/_debugConnectionInfo" );
    print TMP "=" x 80, "\n";
    print TMP qq{TIME            = } . scalar( localtime( time() ) ), "\n";
    print TMP qq{HTTP_USER_AGENT = $ua\n};
    print TMP qq{REMOTE_ADDR     = $ra\n};
    print TMP qq{HTTP_REFERER    = $ref\n};
    print TMP qq{REQUEST_URI     = $uri\n};
    print TMP "=" x 80, "\n";
    close(TMP);
}

1;
