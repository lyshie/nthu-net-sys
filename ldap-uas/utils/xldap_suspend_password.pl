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
use ourUtils;
use ourTemplate qw(_L);

my %_VAR = (
    'PROFILE'      => $ARGV[0] || usage(),
    'SUSPEND'      => $ARGV[1] || 0,
    'FILTER'       => $ARGV[2] || usage(),
    'ANNOUNCEMENT' => $ARGV[3] || usage(),
);

my %USERS = ();

sub usage {
    print <<EOF
Usage:
\t$0 [PROFILE] [SUSPEND] [FILTER]    [ANNOUNCEMENT]
\t$0 m98       0/1       "(uid=xxx)" 20131218_01
EOF
        ;
    exit(1);
}

sub main {

    my $config = ldap_init_config( $_VAR{'PROFILE'} );
    my $ldap   = ldap_connect($config);

    my $users = ldap_get_users( $ldap, $config, undef, $_VAR{'FILTER'} );

    my $total = scalar( @{$users} );

    my $i = 0;
    foreach my $u ( @{$users} ) {
        $i++;

        if ( $_VAR{'SUSPEND'} ) {
            print suspend_password( $ldap, $config, $u, 1 );
        }
        else {
            print suspend_password( $ldap, $config, $u, 0 );
        }
    }

    if ( $i == 0 ) {
        print "No users!\n";
    }

    ldap_disconnect($ldap);
}

sub suspend_password {
    my ( $ldap, $config, $user, $suspend ) = @_;
    my ( $result, $log_msg ) = ( '', '' );

    my $uid      = $user->{'uid'}          || '';
    my $password = $user->{'userpassword'} || '';

    if ($suspend) {
        $password =~ s/^{[A-Z_]+}/{_SUSPEND_}/;

        #if ( $password eq $user->{'userpassword'} ) {
        #    $result = "Password no change for " . $user->{'uid'} . "\n";
        #    return $result;
        #}

        my $description
            = defined( $user->{'description'} )
            ? $user->{'description'}
            : '';
        $description .= sprintf( 'adm-suspendpasswd(%s,-,%s);',
            time(), $_VAR{'ANNOUNCEMENT'} );

        my $mesg = $ldap->modify(
            'uid=' . $uid . ',' . $config->{'user_dn'},
            replace => {
                'userpassword' => $password,
                'description'  => $description,
            }
        );

        if ( !$mesg->code() ) {
            $log_msg
                = sprintf( "OK: Change password [uid = %s]", $user->{'uid'} );
            $result .= $log_msg . "\n";

           # lyshie_20140120: add contrib code './inform_disabled_password.pl'
            my $email = sprintf( "%s@%s", $uid, $config->{'realm'} );
            my $announcement = $_VAR{'ANNOUNCEMENT'};
            qx{$Bin/contrib/inform_disabled_password.pl '$email' '$announcement'};
        }
        else {
            $log_msg
                = sprintf( "FAIL: Change password [uid = %s], [error = %s]",
                $user->{'uid'}, $mesg->error() );
            $result .= $log_msg . "\n";
        }

        _L( $0, $log_msg );    # syslog
    }
    else {
        $result = "Nothing for " . $user->{'uid'} . "\n";
    }

    return $result;
}

main();
