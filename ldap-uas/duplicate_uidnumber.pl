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
use FindBin qw($Bin);
use HTML::Template;

use lib "$Bin";
use ourTemplate;
use ourLDAP;

#use ourUtils;

my %_GET = ();

sub read_param {
    $_GET{'profile'} = defined( param('profile') ) ? param('profile') : 'm99';
    $_GET{'profile'} =~ s/[^0-9a-zA-Z\-_]//g;
}

sub duplicate_uidnumber {
    my ( $config, $ldap, $mesg, $result );
    my %_UIDNUMBER = ();
    my %_UID       = ();

    $config = ldap_init_config( $_GET{'profile'} );
    $ldap   = ldap_connect($config);

    $mesg = $ldap->search(
        base   => $config->{'user_dn'},
        scope  => 'sub',
        filter => '(uid=*)',
        attrs  => [ 'uid', 'uidNumber' ]
    );

    $result = '';
    if ( !$mesg->code() ) {
        foreach my $entry ( $mesg->entries ) {
            my $un  = $entry->get_value('uidnumber');
            my $uid = $entry->get_value('uid');
            if ( defined( $_UIDNUMBER{$un} ) ) {
                $_UIDNUMBER{$un}++;
                $_UID{$un} .= "$uid;";
            }
            else {
                $_UIDNUMBER{$un} = 1;
                $_UID{$un}       = "$uid;";
            }
        }

        foreach ( keys(%_UIDNUMBER) ) {
            if ( $_UIDNUMBER{$_} > 1 ) {
                $result .= sprintf( "%s (%s, %s)\n", $_, $_UIDNUMBER{$_},
                    $_UID{$_} );
            }
        }

        $result = "沒有重複的 uidNumber\n" if ( $result eq '' );
    }
    else {
        $result = $mesg->error();
    }

    ldap_disconnect($ldap);

    return $result;
}

sub do_action {
    my $result  = '';
    my $log_msg = '';

    $log_msg = 'Find out duplicate uidNumber';
    _L( $0, $log_msg );    # syslog

    $result = duplicate_uidnumber();

    return $result;
}

sub main {
    read_param();

    my $result = do_action();

    my $template = HTML::Template->new(
        filename => getTemplate("duplicate_uidnumber.tmpl") );
    $template->param( RESULT => _H($result) );

    print header( -charset => 'utf-8' );    # later output
    print $template->output();
}

main();

