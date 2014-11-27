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
use HTML::Template::Pro;

use lib "$Bin";
use ourLDAP;
use ourUtils;
use ourLanguage;
use ourTemplate;
use ourTicket;
use ourMail;

#
my %_GET = ();

#
sub read_param {
    $_GET{'number'} = defined( param('number') ) ? param('number') : '';
    $_GET{'number'} =~ s/[^0-9a-f]//g;
}

sub main {
    read_param();

    if ( $_GET{'number'} eq '' ) {
        print header( -charset => 'utf-8', -type => 'text/plain' );
        print "ERROR: There is no ticket number!";
        return;
    }
    else {
        my $filename = isTicketExist( $_GET{'number'} );

        if ($filename) {
            if ( isTicketExpired($filename) ) {
                print header( -charset => 'utf-8', -type => 'text/plain' );
                print "ERROR: This ticket is expired!";
                return;
            }
        }
        else {
            print header( -charset => 'utf-8', -type => 'text/plain' );
            print "ERROR: This ticket does not exist!";
            return;
        }
    }

    my $data = readTicket( $_GET{'number'} );

    my $msg = change_email($data);

    print header( -charset => 'utf-8', -type => 'text/plain' ); # later output
    print $msg;
}

sub change_email {
    my ($data) = @_;

    my ( $id, $degree, $email2, $role ) = (
        $data->{'id'},    $data->{'degree'},
        $data->{'email'}, $data->{'role'}
    );

    my ( $config, $ldap, $mesg, $result, $users );
    $result = '';

    my ( $username, $dn, $description, $mail );

    if ( $degree =~ m/^\d+$/ ) {    # student
        $username = "$id";
        $config   = ldap_init_config("m$degree");
        $ldap     = ldap_connect($config);
        $users    = ldap_get_user( $ldap, $config, $username );

        $dn
            = defined( $users->[0]->{'uid'} )
            ? 'uid=' . $users->[0]->{'uid'} . ',' . $config->{'user_dn'}
            : '';
        $mail
            = defined( $users->[0]->{'mail'} )
            ? $users->[0]->{'mail'}
            : '';
        $description
            = defined( $users->[0]->{'description'} )
            ? $users->[0]->{'description'}
            : '';

        # write MAIL field
        if ( $email2 ne '' ) {
            $description
                .= 'chemail('
                . time() . ','
                . getRemoteAddr() . ','
                . $mail . ');';

            if ( update_email( $config, $ldap, $users, $email2, $description )
                )
            {
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
        $mail
            = defined( $users->[0]->{'mail'} )
            ? $users->[0]->{'mail'}
            : '';
        $description
            = defined( $users->[0]->{'description'} )
            ? $users->[0]->{'description'}
            : '';

        # write MAIL field
        if ( $email2 ne '' ) {
            $description
                .= 'chemail('
                . time() . ','
                . getRemoteAddr() . ','
                . $mail . ');';

            if ( update_email( $config, $ldap, $users, $email2, $description )
                )
            {
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

main;
