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
use ourSession;
use ourLanguage;
use ourUtils;
use ourLDAP;
use ourError;

#
my %_POST = ();

my %EVENT_DESC = (
    'create'     => "建立帳號 (Create account)",
    'adm-create' => "管理者建立帳號 (Create account by administrator)",
    'chpasswd'   => "變更密碼 (Change password)",
    'chcn'       => "變更姓名 (Change name)",
    'chopenid'   => "變更 OpenID (Change OpenID)",
    'chemail'    => "變更聯絡用電子郵件 (Change Email)",
    'adm-chpasswd' =>
        "管理者變更密碼 (Change password by administrator)",
    'adm-suspendpasswd' =>
        "管理者停用密碼 (Suspend password by administrator)",
    'adm-stoppasswd' =>
        "管理者暫停密碼 (Stop password by administrator)",
    'adm-suspend' =>
        "管理者停用帳號 (Suspend account by administrator)",
    'adm-restore' =>
        "管理者復用帳號 (Restore account by administrator)",
);

#
sub read_param {
    $_POST{'sid'} = param('sid') || '';
    $_POST{'sid'} =~ s/[^0-9a-f]//g;
}

sub get_log_data {
    my ( $id, $degree, $role ) = @_;

    my @result = ();

    my ( $config, $ldap, $users );

    my ($description);

    if ( $degree =~ m/^\d+$/ ) {    # student
        $config = ldap_init_config("m$degree");
        $ldap   = ldap_connect($config);
        $users  = ldap_get_users( $ldap, $config, undef,
            "(|(uid=s$id)(uid=u$id)(uid=g$id)(uid=d$id))" );

        $description
            = defined( $users->[0]->{'description'} )
            ? $users->[0]->{'description'}
            : '';
    }
    else {                          # non-student
        $id =~ s/@.*$//g;
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
            $users = ldap_get_users( $ldap, $config, undef,
                "(|(uid=$id)(sn=$id))" );
        }

        $description
            = defined( $users->[0]->{'description'} )
            ? $users->[0]->{'description'}
            : '';
    }

    ldap_disconnect($ldap);

    my @events = split( /;/, $description );

    foreach my $e ( reverse(@events) ) {
        if ( $e =~ m/([a-zA-Z\-_]+)\((\d+)(?:,)*([^,]*)(?:,)*(.*)\)/ ) {
            push(
                @result,
                {   'TIME'  => scalar( localtime($2) ),
                    'EVENT' => $EVENT_DESC{$1} || $1,
                    'IP'    => $3 || '-',

                 #    'TAG'   => $4 || '',
                 #    'FLAG'  => lc( $GI->country_code_by_addr($3) || 'fam' ),
                }
            );
        }
    }

    return @result;
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

        my @logs = get_log_data( $h->{'id'}, $degree, $role );

        my $template = HTML::Template::Pro->new(
            case_sensitive => 1,
            filename       => "$Bin/template/$G_LANG/view-log.tmpl"
        );

        $template->param( SID         => $sid );
        $template->param( LOOP_EVENTS => \@logs );
        $template->param( PROG        => getProgramName($0) );

        print header( -charset => 'utf-8', -expires => 'now' ); # later output
        $template->output( print_to => \*STDOUT );
    }
    else {
        print header( -charset => 'utf-8' );
        print show_session_error($status);
    }
}

main();
