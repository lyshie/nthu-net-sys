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
use ourSession;
use ourUtils;
use ourLDAP;
use ourError;
use ourMail;

#
my %_POST = ();

#
sub read_param {
    $_POST{'sid'} = param('sid') || '';
    $_POST{'sid'} =~ s/[^0-9a-f]//g;

    $_POST{'email'} = param('email') || '';
}

sub delete_email2 {
    my ( $id, $degree, $email2, $role ) = @_;

    my ( $config, $ldap, $mesg, $result, $users );
    $result = '';

    my ( $username, $dn );

    if ( $degree =~ m/^\d+$/ ) {    # student
        $username = "$id";
        $config   = ldap_init_config("m$degree");
        $ldap     = ldap_connect($config);
        $users    = ldap_get_user( $ldap, $config, $username );

        $dn
            = defined( $users->[0]->{'uid'} )
            ? 'uid=' . $users->[0]->{'uid'} . ',' . $config->{'user_dn'}
            : '';

        # write MAIL field
        if ( $email2 ne '' ) {
            if ( delete_email( $config, $ldap, $users, $email2 ) ) {
                $result
                    .= "完成變更使用者 $username ($email2) 的 Email2\n";
                $result .= "Changed Email2: $username ($email2)\n";
                $result .= "\n";
            }
            else {
                $result
                    .= "無法變更使用者 $username ($email2) 的 Email2 ("
                    . $mesg->error() . ")\n";
                $result .= "Failed to change Email2: $username ($email2) ("
                    . $mesg->error() . ")\n";
                $result .= "\n";
            }
        }
    }
    else {    # non-student
        $username = $id;
        $username =~ s/@.*$//g;
        $config = ldap_init_config("$role");
        $ldap   = ldap_connect($config);

        if ( $role eq 'staff' ) {
            $users = ldap_get_users_by_sn( $ldap, $config, $id );
            my @tmp = ();
            foreach (@$users) {
                if ( $_->{'profile'} eq 'mx' ) {
                    push( @tmp, $_ );
                    last;
                }
            }
            $users = \@tmp;
        }
        else {
            $users = ldap_get_user( $ldap, $config, $username );
        }

        $dn
            = defined( $users->[0]->{'uid'} )
            ? 'uid=' . $users->[0]->{'uid'} . ',' . $config->{'user_dn'}
            : '';

        # write MAIL field
        if ( $email2 ne '' ) {
            if ( delete_email( $config, $ldap, $users, $email2 ) ) {
                $result
                    .= "完成變更使用者 $username ($email2) 的 Email2\n";
                $result .= "Changed Email2: $username ($email2)\n";
                $result .= "\n";
            }
            else {
                $result
                    .= "無法變更使用者 $username ($email2) 的 Email2 ("
                    . $mesg->error() . ")\n";
                $result .= "Failed to change Email2: $username ($email2) ("
                    . $mesg->error() . ")\n";
                $result .= "\n";
            }
        }
    }

    ldap_disconnect($ldap);

    if ( $result eq '' ) {
        $result .= "沒有變更\n";
        $result .= "Nothing changed.\n";
    }

    return $result;
}

sub main {
    read_param();

    my ( $status, $sid, $h ) = sessionCheck( $_POST{'sid'} );

    if ( $status > 0 ) {
        my ( $role, $degree ) = getRole( $h->{'id'} );

        if ( ( $role eq 'staff' ) && ( $degree eq '' ) ) {
            print redirect( -uri => qq{switch-user.cgi?sid=$sid} );
            exit();
        }

        my $is_exist = isUserExist( $h->{'id'}, $degree, $role );
        my $is_suspended = isUserSuspended( $h->{'id'}, $degree, $role );

        if ($is_suspended) {
            print header( -charset => 'utf-8' );
            print show_user_error(-3);
            exit();
        }

        if ( !$is_exist ) {
            print header( -charset => 'utf-8' );
            print show_user_error(-2);
            exit();
        }

        my $result
            = delete_email2( $h->{'id'}, $degree, $_POST{'email'}, $role );

        print header( -charset => 'utf-8', -expires => 'now' ); # later output

        print $result;
    }
    else {
        print header( -charset => 'utf-8' );
        print show_session_error($status);
    }
}

main();
