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

#
my %_GET   = ();
my %RESULT = ();

#
sub read_param {
    $_GET{'sid'} = param('sid') || '';
    $_GET{'sid'} =~ s/[^0-9a-f]//g;

    $_GET{'format'} = param('format') || 'text';

    $_GET{'charset'} = param('charset') || 'utf-8';
    $_GET{'charset'} = lc( $_GET{'charset'} );
    if ( $_GET{'charset'} ne 'big5' ) {
        $_GET{'charset'} = 'utf-8';
    }
}

sub dump_result {
    my ( $ref, $charset, $format ) = @_;

    $format = defined($format) ? $format : 'text';

    if ( $format eq 'json' ) {
        eval "require JSON";
        if ($@) {
            print header( -charset => $charset, -type => 'application/json' );
        }
        else {
            use JSON;
            print header( -charset => $charset, -type => 'application/json' );
            if ( $charset eq 'big5' ) {
                foreach ( sort grep { !m/^status/ } keys(%$ref) ) {
                    $ref->{$_} = utf8_to_big5( $ref->{$_} );
                }
            }
            print JSON->new->latin1->pretty->encode($ref);
        }
    }
    elsif ( $format eq 'yaml' ) {
        eval "require YAML::Syck";
        if ($@) {
            print header( -charset => $charset, -type => 'text/yaml' );
        }
        else {
            use YAML::Syck;
            print header( -charset => $charset, -type => 'text/yaml' );
            if ( $charset eq 'big5' ) {
                foreach ( sort grep { !m/^status/ } keys(%$ref) ) {
                    $ref->{$_} = utf8_to_big5( $ref->{$_} );
                }
            }
            print Dump($ref);
        }
    }
    else {
        print header( -charset => $charset, -type => 'text/plain' );
        foreach ( sort grep {m/^status/} keys(%$ref) ) {
            print "$_ = $ref->{$_}\n";
        }

        print "charset = $charset\n";

        foreach ( sort grep { !m/^status/ } keys(%$ref) ) {
            if ( $charset eq 'big5' ) {
                print "$_ = ", utf8_to_big5( $ref->{$_} ), "\n";
            }
            else {
                print "$_ = $ref->{$_}\n";
            }
        }
    }
}

sub safe_check {
    my $addr = $ENV{'REMOTE_ADDR'} || '';

    if ( ( $addr eq '' )
        || $addr
        !~ m/^(?:140\.114\.5\.|140\.114\.64\.|140\.114\.63\.|127\.)/ )
    {
        $RESULT{'status'}         = "failed";
        $RESULT{'status_message'} = "ip address not allow";
        dump_result( \%RESULT, $_GET{'charset'}, $_GET{'format'} );
        exit(1);
    }
}

#sub get_priority {
#    my %priority = ( 's' => 4, 'd' => 3, 'g' => 2, 'u' => 1 );
#    my ($id) = @_;
#
#    return $priority{ lc( substr( $id, 0, 1 ) ) };
#}

sub main {
    read_param();

    safe_check();

    my ( $status, $sid, $h ) = sessionCheck( $_GET{'sid'}, 1 );

    if ( $status > 0 ) {
        foreach my $key ( sort keys(%$h) ) {
            next if ( $key =~ m/^_SESSION/ );
            $RESULT{$key} = "$h->{$key}";
            if ( $key eq 'id' ) {
                my ( $role, $degree ) = getRole( $h->{$key} );
                $RESULT{'role'}   = $role;
                $RESULT{'degree'} = $degree;

                my ( $ldap, $config, $users, $username );
                $username = "$h->{$key}";
                if ( $degree =~ m/^\d+$/ ) {    # student
                    $config = ldap_init_config("m$degree");
                    $ldap   = ldap_connect($config);
                    $users  = ldap_get_user( $ldap, $config, $username );
                    ldap_disconnect($ldap);
#
#                    @$users = 
#                        sort {
#                            get_priority( $b->{"uid"} )
#                                <=> get_priority( $a->{"uid"} )
#                            } @$users;
#                    
                }
                else {    # non-student
                    $username =~ s/@.*$//g;
                    $config = ldap_init_config("$role");
                    $ldap   = ldap_connect($config);

                    if ( $role eq 'staff' ) {
                        $users = ldap_get_users_by_sn( $ldap, $config,
                            $username );
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

                    #$users  = ldap_get_users( $ldap, $config, undef,
                    #    "(|(uid=$username)(sn=$username))" );
                    ldap_disconnect($ldap);
                }

                $RESULT{'uid'}         = $users->[0]->{'uid'}     || '';
                $RESULT{'sn'}          = $users->[0]->{'sn'}      || '';
                $RESULT{'realm'}       = $config->{'realm'}       || '';
                $RESULT{'realm_short'} = $config->{'realm_short'} || '';
            }
        }

        $RESULT{'status'} = "ok";
        dump_result( \%RESULT, $_GET{'charset'}, $_GET{'format'} );
    }
    else {
        $RESULT{'status'}         = "failed";
        $RESULT{'status_message'} = "session empty";
        dump_result( \%RESULT, $_GET{'charset'}, $_GET{'format'} );
    }
}

main();
