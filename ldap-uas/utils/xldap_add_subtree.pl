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

use FindBin qw($Bin);
use lib "$Bin";
use ourLDAP;

my %_VAR = (
    'PROFILE'     => $ARGV[0] || usage(),
    'NAME'        => $ARGV[1] || usage(),
    'DESCRIPTION' => $ARGV[2] || usage(),
);

my @OU     = qw(People Group Hosts Services Aliases Suspended);
my %GROUPS = (
    'user' => 1001,
    'cc'   => 501,
);

sub usage {
    print <<EOF
Usage:
\t$0 [PROFILE] [NAME] [DESCRIPTION]
\t$0 m99       m99    "For m99"
EOF
        ;
    exit(1);
}

sub main {
    my $config = ldap_init_config( $_VAR{'PROFILE'} );
    my $ldap   = ldap_connect($config);

    my $dc = "dc=$_VAR{'NAME'}," . $config->{'basedn'};

    print qq{Add or replace entry: $dc\n};
    my $result = $ldap->add(
        $dc,
        attr => [
            'objectclass' => [ 'dcObject', 'organization', 'posixAccount' ],
            'dc'          => $_VAR{'NAME'},
            'o'           => $_VAR{'DESCRIPTION'},
            'description' => $_VAR{'DESCRIPTION'},

            # posixAccount
            'cn'            => $_VAR{'NAME'},
            'uid'           => $_VAR{'NAME'},
            'homedirectory' => $_VAR{'NAME'},
            'uidnumber'     => $config->{'min_uid'},
            'gidnumber'     => $config->{'min_uid'},
        ],
        )
        && $ldap->modify(
        $dc,
        replace => [
            'objectclass' => [ 'dcObject', 'organization', 'posixAccount' ],
            'dc'          => $_VAR{'NAME'},
            'o'           => $_VAR{'DESCRIPTION'},
            'description' => $_VAR{'DESCRIPTION'},

            # posixAccount
            'cn'            => $_VAR{'NAME'},
            'uid'           => $_VAR{'NAME'},
            'homedirectory' => $_VAR{'NAME'},
            'uidnumber'     => $config->{'min_uid'},
            'gidnumber'     => $config->{'min_uid'},
        ],
        );

    if ( !$result->code() ) {
        foreach my $name (@OU) {
            my $ou = "ou=$name," . $dc;
            print qq{Add or replace entry: $ou\n};
            my $r = $ldap->add(
                $ou,
                attr => [
                    'objectclass' => ['organizationalUnit'],
                    'ou'          => $name,
                ],
                )
                && $ldap->modify(
                $ou,
                replace => [
                    'objectclass' => ['organizationalUnit'],
                    'ou'          => $name,
                ],
                );
            $r->code()
                && warn( "FAIL: failed to add entry: ", $r->error() );
        }

        foreach my $name ( keys(%GROUPS) ) {
            my $cn = "cn=$name,ou=Group," . $dc;
            print qq{Add or replace entry: $cn\n};
            my $r = $ldap->add(
                $cn,
                attr => [
                    'objectclass' => ['posixGroup'],
                    'cn'          => $name,
                    'gidnumber'   => $GROUPS{$name},
                ],
                )
                && $ldap->modify(
                $cn,
                replace => [
                    'objectclass' => ['posixGroup'],
                    'cn'          => $name,
                    'gidnumber'   => $GROUPS{$name},
                ],
                );
            $r->code()
                && warn( "FAIL: failed to add entry: ", $r->error() );
        }

    }
    else {
        warn( "FAIL: failed to add entry: ", $result->error() );
    }

    ldap_disconnect($ldap);
}

main();
