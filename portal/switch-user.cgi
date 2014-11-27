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
use ourSession;
use ourLanguage;
use ourUtils;
use ourError;

#
my %_GET = ();

#
sub read_param {
    $_GET{'sid'} = param('sid') || '';
    $_GET{'sid'} =~ s/[^0-9a-f]//g;

    $_GET{'profile'} = defined( param('profile') ) ? param('profile') : '';
    $_GET{'profile'} =~ s/[^0-9a-zA-Z\-_]//g;
}

sub main {
    read_param();

    my ( $status, $sid, $h ) = sessionCheck( $_GET{'sid'} );

    if ( $status > 0 ) {    # session ok
        my ( $role, $degree ) = getRole( $h->{'id'} );
        my $prev_page = $h->{'prev_page'};

        if ( $degree eq '' ) {    # not student
            if ( $role eq 'staff' ) {
                my $config = ldap_init_config($role);
                my $ldap   = ldap_connect($config);
                my $result
                    = ldap_get_users_by_sn( $ldap, $config, $h->{'id'} );
                my @users = @$result;
                if ( $_GET{'profile'} ) {
                    foreach my $u (@users) {
                        if ( $_GET{'profile'} eq $u->{'profile'} ) {
                            sessionSet( $sid, 'id',
                                $u->{'uid'} . '@' . $u->{'profile'} );
                            print redirect( -uri => qq{$prev_page?sid=$sid} );
                            return;    # match and exit the loop and sub
                        }
                    }
                    print header( -charset => 'utf-8' );
                    print show_user_error(-4);
                }
                elsif ( !@users ) {
                    print header( -charset => 'utf-8' );
                    print show_user_error(-4);
                }
                else {
                    my $template = HTML::Template::Pro->new(
                        case_sensitive => 1,
                        filename => "$Bin/template/$G_LANG/switch-user.tmpl"
                    );

                    $template->param( SID => $sid );
                    foreach (@users) {
                        my $c = ldap_init_config( $_->{'profile'} );
                        $_->{'realm'} = $c->{'realm'};
                    }
                    $template->param( LOOP_USERS => \@users );

                    print header( -charset => 'utf-8', -expires => 'now' )
                        ;    # later output
                    $template->output( print_to => \*STDOUT );
                }
            }
            else {
                print header( -charset => 'utf-8' );
                print show_user_error(-4);
            }
        }
        else {               # student
            print header( -charset => 'utf-8' );
            print show_user_error(-4);
        }
    }
    else {                   # session failed
        print header( -charset => 'utf-8' );
        print show_session_error($status);
    }
}

main();
