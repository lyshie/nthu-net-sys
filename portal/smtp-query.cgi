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
my %_GET = ();

#
sub read_param {
    $_GET{'sid'} = param('sid') || '';
    $_GET{'sid'} =~ s/[^0-9a-f]//g;
}

sub get_email {
    my ($id) = @_;

    my $email = '';
    my ( $uid, $profile ) = split( /@/, $id );

    return $email if ( !defined($uid) || !defined($profile) );

    my $config = ldap_init_config($profile);
    $email = $uid . '@' . $config->{'realm'};

    return $email;

}

sub get_dates {
    my ($current) = @_;

    my @dates     = ();
    my @dates_rev = ();

    for my $i ( -32 .. -1 ) {
        my ( $y, $m, $d ) = ( localtime( $current + $i * 86400 ) )[ 5, 4, 3 ];
        $y += 1900;
        $m += 1;
        my $date = sprintf( "%04d-%02d-%02d", $y, $m, $d );
        push( @dates, { 'date' => $date } );
        unshift( @dates_rev, { 'date' => $date } );
    }

    return ( \@dates, \@dates_rev );
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

        my ( $dates, $dates_rev ) = get_dates( time() );

        my $template = HTML::Template::Pro->new(
            case_sensitive => 1,
            filename       => "$Bin/template/$G_LANG/smtp-query.tmpl"
        );

        $template->param( SID            => $sid );
        $template->param( LOOP_DATES     => $dates );
        $template->param( LOOP_DATES_REV => $dates_rev );
        $template->param( EMAIL          => get_email( $h->{'id'} ) );

        print header( -charset => 'utf-8', -expires => 'now' ); # later output
        $template->output( print_to => \*STDOUT );
    }
    else {
        print header( -charset => 'utf-8' );
        print show_session_error($status);
    }
}

main();
