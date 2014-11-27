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
use Config::General qw(ParseConfig);
use Net::LDAP;
use Net::LDAP::Schema;
use Data::Dump;

my %_CONFIG;

sub init_config {
    my $config_file = "$Bin/profile.d/oz.conf";
    my %config      = ();

    %config = ParseConfig($config_file);

    if ( defined( $config{'basedn'} ) ) {
        $config{'binddn'}   .= ',' . $config{'basedn'};
        $config{'rootdn'}   .= ',' . $config{'basedn'};
        $config{'group_dn'} .= ',' . $config{'basedn'};
        $config{'user_dn'}  .= ',' . $config{'basedn'};
    }

    return %config;
}

sub ldap_connect {
    my ($config) = @_;

    my $ldap = Net::LDAP->new( $config->{'host'} ) or die "$@";

    $ldap->bind( $config->{'binddn'}, password => $config->{'bindpw'} );

    return $ldap;
}

sub ldap_dump_group {
    my ( $ldap, $config ) = @_;

    my $mesg = $ldap->search(
        base   => $config->{'group_dn'},
        scope  => 'sub',
        filter => $config->{'group_filter'},
    );

    $mesg->code() && die( $mesg->error() );

    foreach my $entry ( $mesg->entries() ) {
        $entry->dump();
    }
}

sub ldap_dump_user {
    my ( $ldap, $config ) = @_;

    my $mesg = $ldap->search(
        base   => $config->{'user_dn'},
        scope  => 'sub',
        filter => $config->{'user_filter'},
    );

    $mesg->code() && die( $mesg->error() );

    foreach my $entry ( $mesg->entries() ) {
        $entry->dump();
    }
}

sub ldap_disconnect {
    my ($ldap) = @_;

    $ldap->unbind();
}

sub ldap_get_must_attr {
    my ($ldap) = @_;

    my @ocs = qw(account posixAccount shadowAccount top);

    my $schema = $ldap->schema();

    foreach my $oc (@ocs) {
        my @must = $schema->must($oc);
        print "[$oc]\n";
        print "* ", $_->{'name'}, "\n" foreach ( sort @must );
        my @may = $schema->may($oc);
        print "  + ", $_->{'name'}, "\n" foreach ( sort @may );
    }
}

sub ldap_add_user {
    my ( $ldap, $config, $attrs ) = @_;

    my @array = %{$attrs};
    my $result
        = $ldap->add( 'uid=' . $attrs->{'uid'} . ',' . $config->{'user_dn'},
        attr => \@array );

    $result->code()
        && warn( "Failed to add entry: ",
        $attrs->{'uid'}, ' ', $result->error() );
}

sub main {
    %_CONFIG = init_config();

    my $ldap = ldap_connect( \%_CONFIG );

    ldap_dump_user( $ldap, \%_CONFIG );
    #ldap_dump_group( $ldap, \%_CONFIG );
    #ldap_get_must_attr($ldap);
    #for ( 1 .. 99999 ) {
    #    last;
    #    my %attrs = (
    #        uid           => 'test' . sprintf( '%05d',                  $_ ),
    #        homeDirectory => '/home/ldap-users/test' . sprintf( '%05d', $_ ),
    #        cn            => 'test' . sprintf( '%05d',                  $_ ),
    #        objectClass   => [qw(posixAccount account)],
    #        uidNumber     => 20001 + $_,
    #        gidNumber     => 20001 + $_,
    #    );
    #    ldap_add_user( $ldap, \%_CONFIG, \%attrs );
    #}
    ldap_disconnect($ldap);
}

main();
