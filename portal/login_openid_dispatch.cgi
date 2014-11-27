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

use CGI qw(:standard :cgi-lib);
use FindBin qw($Bin);
use String::Random qw(random_regex);
use Net::OpenID::Consumer;
use CGI::Cookie;
use File::Cache;
use LWPx::ParanoidAgent;

use lib "$Bin";
use lib_crypt;
use ourSession;
use ourLanguage;
use ourLDAP;
use ourUtils;
use ourError;

#
my %_GET            = ();
my %_ENV            = ( 'HTTP_HOST' => "https://$ENV{'HTTP_HOST'}/" );
my $MAGIC_PATH      = "$Bin/magic";
my $SCRIPT_NAME     = $_ENV{'HTTP_HOST'} . 'portal/login_openid.cgi';
my $CONSUMER_SECRET = "";

#
sub read_param {
    $_GET{'ret'} = defined( param('ret') ) ? param('ret') : '';
}

sub generate_magic {
    my $magic = random_regex('[a-z0-9]{48}');

    open( FH, ">$MAGIC_PATH/$magic" );
    close(FH);

    return $magic;
}

sub init_consumer {
    my $cgi = CGI->new();
    my $csr = Net::OpenID::Consumer->new(
        ua              => LWPx::ParanoidAgent->new(),
        cache           => File::Cache->new(),
        args            => $cgi,
        consumer_secret => $CONSUMER_SECRET,
        required_root   => $_ENV{'HTTP_HOST'}
    );
}

sub main {
    read_param();

    if ( param() ) {
        if ( $_GET{'ret'} ) {
            my $csr = init_consumer();
            init_response($csr);
        }
        else {
            print header( -charset => 'utf-8', -type => 'text/plain' );
            print "Authentication error (no-ret)! Please try again!\n";
        }
    }
    else {
        print header( -charset => 'utf-8', -type => 'text/plain' );
        print "Authentication error (no-param)! Please try again!\n";
    }
}

main();

#===============================================================================
# OpenID functions
#===============================================================================

sub _not_openid {
    print header( -charset => 'utf-8', -type => 'text/plain' );
    print "Not an OpenID message.\n";
    exit(0);
}

sub _user_setup_url {
    my ($setup_url) = @_;
    print redirect( -uri => $setup_url );
}

sub _user_cancel {
    print redirect( -uri => $SCRIPT_NAME );
}

sub _verified_identity {
    my ($vident) = @_;

    #print header( -charset => 'utf-8', -type => 'text/plain' );
    #use Data::Dump;
    #print Data::Dump->dump(param());
    #exit(0);
    my $url = $vident->url;

    my ( $url_http, $url_https ) = ( $url, $url );
    $url_http  =~ s/^https:\/\//http:\/\//;
    $url_https =~ s/^http:\/\//https:\/\//;

    foreach my $profile (qw(cc oz m98 m99)) {
        my $config = ldap_init_config($profile);
        my $ldap   = ldap_connect($config);
        my $users  = ldap_get_users( $ldap, $config, undef,
            "(|(labeledURI=$url_http)(labeledURI=$url_https))" );

        ldap_disconnect($ldap);

        if ( scalar(@$users) > 0 ) {
            my $name = $users->[0]->{'cn'}  || '';
            my $uid  = $users->[0]->{'uid'} || '';
            my $ip   = $ENV{'REMOTE_ADDR'}  || '';
            my $timestamp = time();
            my $data      = <<EOF
charset = utf-8
name = $name
id = $uid\@$profile
ip = $ip
timestamp = $timestamp
openid = $url
EOF
                ;
            my $magic = generate_magic();
            print redirect(
                -uri => "index.cgi?magic=$magic&amp;ACIXSTORE=&amp;data="
                    . lib_crypt::encrypt($data) );

#            print header( -charset => 'utf-8' );
#            print qq{<a href="index.cgi?magic=$magic&amp;ACIXSTORE=&amp;data=}
#                . lib_crypt::encrypt($data)
#                . qq{">HERE!!!</a>};
#            use Data::Dump;
#            print "<pre>" . Data::Dump->dump(Vars) . "</pre>";
#            return;
        }
    }

    print header( -charset => 'utf-8', -type => 'text/plain' );
    print "Authentication error (no-such-user: $url)!\n";
}

sub _error {
    my ( $errcode, $errtext ) = @_;

    print header( -charset => 'utf-8', -type => 'text/plain' );
    print "ERROR: $errcode ($errtext).\n";
    if ( $errcode =~ m/server_not_allowed/ ) {
        print <<EOF;
You may have gone to an http: server and come back from an https:
server. This happens with "myopenid.com".
EOF
    }
    elsif ( $errcode =~ m/naive_verify_failed_return/ ) {
        print 'Oops! Did you reload this page?';
    }
}

sub init_response {
    my ($csr) = @_;
    $csr->handle_server_response(
        not_openid     => \&_not_openid,
        setup_required => \&_user_setup_url,
        cancelled      => \&_user_cancel,
        verified       => \&_verified_identity,
        error          => \&_error,

    );
}
