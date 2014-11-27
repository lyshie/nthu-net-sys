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
use lib "$Bin";
use ourLDAP;

my %_VAR = ( 'PROFILE' => $ARGV[0] || usage(), );

sub usage {
    print <<EOF
Usage:
\t$0 [PROFILE]
\t$0 deb-server-m98
EOF
        ;
    exit(1);
}

sub duplicate_uidnumber {
    my ( $config, $ldap, $mesg, $result );
    my %_UIDNUMBER = ();
    my %_UID       = ();

    $config = ldap_init_config( $_VAR{'PROFILE'} );
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
    my $result = '';

    $result = duplicate_uidnumber();

    return $result;
}

sub main {
    my $result = do_action();

    print $result, "\n";
}

main();

