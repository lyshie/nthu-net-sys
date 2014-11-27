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
use Authen::Passphrase::MD5Crypt;

use lib "$Bin";
use ourSession;
use ourLanguage;
use ourTemplate;
use ourUtils;
use ourLDAP;
use ourError;

#
my %_POST = ();

#
sub read_param {
    $_POST{'sid'} = param('sid') || '';
    $_POST{'sid'} =~ s/[^0-9a-f]//g;

    $_POST{'password'} = param('password') || '';
}

sub change_password {
    my ( $id, $degree, $password, $name, $role ) = @_;

    my ( $config, $ldap, $mesg, $result, $users );
    $result = '';

    if ( $password eq '' ) {
        $result .= "沒有變更\n";
        $result .= "Nothing changed.\n";
        return $result;
    }
    else {
        my ( $code, $msg ) = passwordStrength( $id, $password );
        if ( $code < 1 ) {    # lyshie_20110919: password too weak
            $result .= "沒有變更 ($msg)\n";
            $result .= "Nothing changed. ($msg)\n";
            return $result;
        }
    }

    my ( $username, $dn, $description, $cn );

    if ( $degree =~ m/^\d+$/ ) {    # student
        $username = "$id";
        $config   = ldap_init_config("m$degree");
        $ldap     = ldap_connect($config);
        $users    = ldap_get_user( $ldap, $config, $username );

        $dn
            = defined( $users->[0]->{'uid'} )
            ? 'uid=' . $users->[0]->{'uid'} . ',' . $config->{'user_dn'}
            : '';
        $description
            = defined( $users->[0]->{'description'} )
            ? $users->[0]->{'description'}
            : '';
        $description .= 'chpasswd(' . time() . ',' . getRemoteAddr() . ');';

        $cn = defined( $users->[0]->{'cn'} ) ? $users->[0]->{'cn'} : '';

        $name = defined($name) ? $name : $cn;

        if ( ( $dn ne '' ) && ( $description ne '' ) ) {

            # lyshie_20100818: change name (cn field)
            if ( $cn ne $name ) {
                $description
                    .= 'chcn('
                    . time() . ','
                    . getRemoteAddr() . ','
                    . $cn . ');';
            }

            $mesg = $ldap->modify(
                $dn,
                replace => {
                    'userpassword' => generatePassword($password),
                    'description'  => $description,
                    'cn'           => $name,
                }
            );
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
        $description
            = defined( $users->[0]->{'description'} )
            ? $users->[0]->{'description'}
            : '';
        $description .= 'chpasswd(' . time() . ',' . getRemoteAddr() . ');';

        $cn = defined( $users->[0]->{'cn'} ) ? $users->[0]->{'cn'} : '';

        $name = defined($name) ? $name : $cn;

        if ( ( $dn ne '' ) && ( $description ne '' ) ) {

            # lyshie_20100818: change name (cn field)
            if ( $cn ne $name ) {
                $description
                    .= 'chcn('
                    . time() . ','
                    . getRemoteAddr() . ','
                    . $cn . ');';
            }

            $mesg = $ldap->modify(
                $dn,
                replace => {
                    'userpassword' => generatePassword($password),
                    'description'  => $description,
                    'cn'           => $name,
                }
            );
        }
    }

    if ( !$mesg->code() ) {
        $result .= "完成變更使用者 $username 密碼\n";
        $result .= "Changed password: $username\n";
    }
    else {
        $result .= "無法變更使用者 $username 密碼 ("
            . $mesg->error() . ")\n";
        $result .= "Failed to change password: $username ("
            . $mesg->error() . ")\n";
    }

    ldap_disconnect($ldap);

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
        my $is_password_suspended
            = isPasswordSuspended( $h->{'id'}, $degree, $role, $sid );

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

        if ($is_password_suspended) {
            print header( -charset => 'utf-8' );
            print show_user_error(-5);
            exit();
        }

        my $result = change_password( $h->{'id'}, $degree, $_POST{'password'},
            $h->{'name'}, $role );

        my $template = HTML::Template::Pro->new(
            case_sensitive => 1,
            filename       => "$Bin/template/$G_LANG/change-password.tmpl"
        );

        $template->param( SID    => $sid );
        $template->param( RESULT => $result );

        print header( -charset => 'utf-8', -expires => 'now' ); # later output
        $template->output( print_to => \*STDOUT );
    }
    else {
        print header( -charset => 'utf-8' );
        print show_session_error($status);
    }
}

main();
