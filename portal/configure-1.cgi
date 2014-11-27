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
use ourMail;

#
my %_GET = ();

#
sub read_param {
    $_GET{'sid'} = param('sid') || '';
    $_GET{'sid'} =~ s/[^0-9a-f]//g;
}

sub get_openid_email2 {
    my ( $id, $degree, $role ) = @_;

    my ( $config, $ldap, $users );

    my ( $openid, $email2 ) = ( '', '' );

    if ( $degree =~ m/^\d+$/ ) {    # student
        $config = ldap_init_config("m$degree");
        $ldap   = ldap_connect($config);
        $users  = ldap_get_users( $ldap, $config, undef,
            "(|(uid=s$id)(uid=u$id)(uid=g$id)(uid=d$id))" );

        $openid
            = defined( $users->[0]->{'labeleduri'} )
            ? $users->[0]->{'labeleduri'}
            : '';

        my @mails = ();
        push( @mails, { email => $_ } ) foreach read_email($users);
        $email2 = \@mails;
    }
    else {    # non-student
        $id =~ s/@.*$//g;
        $config = ldap_init_config("$role");
        $ldap   = ldap_connect($config);
        $users
            = ldap_get_users( $ldap, $config, undef, "(|(uid=$id)(sn=$id))" );

        $openid
            = defined( $users->[0]->{'labeleduri'} )
            ? $users->[0]->{'labeleduri'}
            : '';

        my @mails = ();
        push( @mails, { email => $_ } ) foreach read_email($users);
        $email2 = \@mails;
    }

    ldap_disconnect($ldap);

    return ( $openid, $email2 );
}

sub main {
    read_param();

    my ( $status, $sid, $h ) = sessionCheck( $_GET{'sid'} );

    if ( $status > 0 ) {
        my ( $role, $degree ) = getRole( $h->{'id'} );

        if ( ( $role eq 'staff' ) && ( $degree eq '' ) ) {
            print redirect( -uri => qq{switch-user.cgi?sid=$sid} );
            exit();
        }

        my $template = HTML::Template::Pro->new(
            case_sensitive => 1,
            filename       => "$Bin/template/$G_LANG/configure-1.tmpl"
        );

        $template->param( SID  => $sid );
        $template->param( NAME => $h->{'name'} );
        $template->param( ID   => $h->{'id'} );
        my ( $openid, $email2 )
            = get_openid_email2( $h->{'id'}, $degree, $role );
        $template->param( OPENID => $openid );
        $template->param( EMAIL2 => $email2 );
        $template->param( DEGREE => $degree );
        $template->param(
            EMAIL => getEmailName( $h->{'id'}, $degree, $role ) );
        $template->param(
            IS_EXIST => isUserExist( $h->{'id'}, $degree, $role ) );

        #        $template->param( PROG => getProgramName($0) );
        $template->param(
            TIMESTAMP => scalar( localtime( $h->{'timestamp'} ) ) );

        print header( -charset => 'utf-8', -expires => 'now' ); # later output
        $template->output( print_to => \*STDOUT );
    }
    else {
        print header( -charset => 'utf-8' );
        print show_session_error($status);
    }
}

main();
