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
package ourUtils;

BEGIN { $INC{'ourAccountCheck.pm'} ||= __FILE__ }

use strict;
use warnings;

use Exporter;
use FindBin qw($Bin);
use Net::SMTP;
use Net::Nslookup;
use lib "$Bin";
use ourLDAP;

our @ISA    = qw(Exporter);
our @EXPORT = qw(
    checkAccountReady
);

my $REGEXP_FILE = "$Bin/check_by_regexp.txt";
my $PASSWD_FILE = '/etc/passwd';
my $LIST_FILE   = "$Bin/check_by_list.txt";

my %_GET = ();

sub check_by_regexp {
    my ($account) = @_;

    my $is_match = 0;

    open( FH, $REGEXP_FILE ) or return $is_match;
    while (<FH>) {
        next if ( $_ =~ m/^\s*#/ );
        chomp($_);
        if ( $account =~ m/$_/g ) {
            $is_match = 1;
            last;
        }
    }
    close(FH);

    return $is_match;
}

sub check_by_passwd {
    my ($account) = @_;

    my $is_match = 0;

    open( FH, $PASSWD_FILE ) or return $is_match;
    while (<FH>) {
        my ($u) = split( /:/, $_ );
        if ( $u eq $account ) {
            $is_match = 1;
            last;
        }
    }
    close(FH);

    return $is_match;
}

sub check_by_list {
    my ($account) = @_;

    my $is_match = 0;

    open( FH, $LIST_FILE ) or return $is_match;
    while (<FH>) {
        next if ( $_ =~ m/^\s*#/ );
        chomp($_);
        $_ = lc($_);
        if ( $_ && $account =~ m/\Q$_\E/ ) {
            $is_match = 1;
            last;
        }
    }
    close(FH);

    return $is_match;
}

sub getMXRecord {
    my ($domain) = @_;
    my $host = 'localhost.localdomain';

    $Net::Nslookup::DEBUG         = 0;
    $Net::Nslookup::DEBUG_NET_DNS = 0;
    $Net::Nslookup::TIMEOUT       = 2;
    my @mx = nslookup( qtype => 'MX', domain => $domain );

    $host = $mx[0] if (@mx);

    return $host;
}

sub check_by_smtp {
    my ( $account, $host ) = @_;

    my $is_match = 0;

    $host = defined($host) ? $host : 'localhost.localdomain';
    my $smtp_server = getMXRecord($host);

    my $smtp = Net::SMTP->new(
        Host    => $smtp_server,
        Hello   => 'localhost.localdomain',
        Timeout => 3,

        #Debug   => 1,
    );

    if (   defined($smtp)
        && $smtp->mail(qq{check_account\@ua.net.nthu.edu.tw})
        && $smtp->to(qq{$account\@$host}) )
    {
        $is_match = 1;
    }

    $smtp->quit() if defined($smtp);

    return $is_match;
}

sub check_by_ldap {
    my ( $account, $profile ) = @_;

    # lyshie_20110308: check user by query uid
    my $is_match = 0;

    my ( $config, $ldap );

    $config = ldap_init_config($profile);
    $ldap   = ldap_connect($config);

    my $users;
    $users = ldap_get_user( $ldap, $config, $account );
    $is_match = 1 if (@$users);

    $users = ldap_get_user_suspended( $ldap, $config, $account );
    $is_match = 1 if (@$users);

    ldap_disconnect($ldap);

    return $is_match;
}

sub check_by_ldap_aliases {
    my ( $account, $profile ) = @_;

    my $is_match = 0;

    my ( $config, $ldap );

    $config = ldap_init_config($profile);
    $ldap   = ldap_connect($config);

    # lyshie_20110308: this code will consume a lot of time querying result
    my $users = ldap_get_users( $ldap, $config, $config->{'alias_dn'},
        $config->{'alias_filter'} );

    ldap_disconnect($ldap);

    foreach (@$users) {
        my $cn  = $_->{'cn'}  ? $_->{'cn'}  : '';
        my $uid = $_->{'uid'} ? $_->{'uid'} : '';

        if ( $cn eq $account ) {
            $is_match = 1;
            last;
        }
        if ( $uid eq $account ) {
            $is_match = 1;
            last;
        }
    }

    return $is_match;
}

sub checkAccountReady {
    my ( $account, $host ) = @_;

    $account = defined($account) ? $account : '';
    $host    = defined($host)    ? $host    : '';

    my $is_match = 0;

    $is_match 
        = check_by_regexp($account)
        || check_by_list($account)
        || check_by_passwd($account)
        || check_by_ldap( $account, 'staff' )    # not ready for ALIASES
        || check_by_ldap_aliases( $account, 'staff' );    # ready for ALIASES
         #|| check_by_smtp( $account, 'mx.nthu.edu.tw' )

    return !$is_match;
}

1;
