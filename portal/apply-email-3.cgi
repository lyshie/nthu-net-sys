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

sub main {
    read_param();

    my ( $status, $sid, $h ) = sessionCheck( $_GET{'sid'} );

    if ( $status > 0 ) {
        unless ( $h->{'condition_bool'} ) {
            print redirect( -uri => qq{switch-user.cgi?sid=$sid} );
            exit();
        }

        my $template = HTML::Template::Pro->new(
            case_sensitive => 1,
            filename       => "$Bin/template/$G_LANG/apply-email-3.tmpl"
        );

        my ( $role, $degree ) = getRole( $h->{'id'} );

        $template->param( SID  => $sid );
        $template->param( NAME => $h->{'name'} );

        if ( $role eq 'staff' ) {
            $template->param( IS_CHECK_NAME_EN => 1 );
        }

        $template->param( NAME_EN => $h->{'name_en'} );
        $template->param( ID      => $h->{'id'} );
        $template->param( DEGREE  => $degree );
        if ( getEmailName( $h->{'id'}, $degree, $role ) ) {
            $template->param(
                EMAIL => getEmailName( $h->{'id'}, $degree, $role ) );
        }
        else {    # staff (mx)
            my @names = getSuggestNames( $h->{'name_en'} );
            $template->param( LOOP_NAMES => \@names );
        }
        $template->param(
            IS_EXIST => isUserExist( $h->{'id'}, $degree, $role ) );
        $template->param(
            IS_SUSPENDED => isUserSuspended( $h->{'id'}, $degree, $role ) );
        $template->param( PROG => getProgramName($0) );
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
