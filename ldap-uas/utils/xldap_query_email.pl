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
use strict;
use warnings;

use CGI qw(:standard);
use CGI::Carp qw(fatalsToBrowser set_die_handler);
use FindBin qw($Bin);
use lib "$Bin";
use ourLDAP;
use ourUtils;

BEGIN {

    sub handle_errors {
        print "FAIL: internal server error\n";
        exit(1);
    }
    set_die_handler( \&handle_errors );
}

my %_GET  = ();
my %USERS = ();

sub read_param {
    $_GET{'id'} = defined( param('id') ) ? param('id') : '';
    $_GET{'id'} =~ s/[^0-9a-zA-Z\-\_@\.]//g;
}

sub query_email {
    my ( $role, $degree ) = getRole( $_GET{'id'} );

    my ( $config, $ldap, $mesg );

    $config = ldap_init_config( ( $role ne 'student' ) ? $role : "m$degree" );
    $ldap = ldap_connect($config);

    # user_dn
    $mesg = $ldap->search(
        base  => $config->{'user_dn'},
        scope => 'sub',
        filter =>
            "(|(uid=s$_GET{'id'})(uid=u$_GET{'id'})(uid=g$_GET{'id'})(uid=d$_GET{'id'}))",
        attrs => ['uid']
    );

    if ( !$mesg->code() ) {
        foreach my $entry ( $mesg->entries ) {
            my $uid = $entry->get_value('uid') || '';
            $USERS{$uid} = 1 if ( $uid ne '' );
        }
    }
    else {
        print "FAIL:" . $mesg->error(), "\n";
        exit(1);
    }
    ####

    # suspended_user_dn
    $mesg = $ldap->search(
        base  => $config->{'suspended_user_dn'},
        scope => 'sub',
        filter =>
            "(|(uid=s$_GET{'id'})(uid=u$_GET{'id'})(uid=g$_GET{'id'})(uid=d$_GET{'id'}))",
        attrs => ['uid']
    );

    if ( !$mesg->code() ) {
        foreach my $entry ( $mesg->entries ) {
            my $uid = $entry->get_value('uid') || '';
            $USERS{$uid} = 1 if ( $uid ne '' );
        }
    }
    else {
        print "FAIL:" . $mesg->error(), "\n";
        exit(1);
    }
    ####

    ldap_disconnect($ldap);

    if ( scalar( keys(%USERS) ) > 0 ) {
        foreach ( sort( keys(%USERS) ) ) {
            print "OK: $_@" . $config->{'realm'}, "\n";
        }
    }
    else {
        print "FAIL: email not found\n";
    }
}

sub safe_check {
    my $addr = $ENV{'REMOTE_ADDR'} || '';

    if ( ( $addr eq '' )
        || $addr !~ m/^(?:140\.114\.68\.|140\.114\.64\.|140\.114\.70\.138)/ )
    {
        print "FAIL: remote address not allow\n";
        exit(1);
    }
}

sub main {
    read_param();

    print header( -charset => 'utf-8', -type => 'text/plain' );
    safe_check();
    query_email();
}

main();

