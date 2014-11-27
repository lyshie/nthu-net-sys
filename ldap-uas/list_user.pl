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
use HTML::Template;
use URI::Escape;

# lyshie_20110614: aovid LDAP Injection attack
use Net::LDAP::Util qw(escape_filter_value);

use lib "$Bin";
use ourTemplate;
use ourLDAP;
use ourUtils;

my %_GET = ();
my %_ENV = ();

my $T_BEGIN;
my $T_END;

sub _debugConnectionInfo {
    my $ua  = $ENV{'HTTP_USER_AGENT'} || 'unknown';
    my $ra  = $ENV{'REMOTE_ADDR'}     || 'unknown';
    my $ref = $ENV{'HTTP_REFERER'}    || 'unknown';
    my $uri = $ENV{'REQUEST_URI'}     || 'unknown';
    my $auth 
        = $ENV{'AUTH_USER'}
        || $ENV{'REMOTE_USER'}
        || 'unknown';

    open( TMP, ">>/tmp/_debugLDAPUAS" );
    print TMP "=" x 80, "\n";
    print TMP qq{TIME            = } . scalar( localtime( time() ) ), "\n";
    print TMP qq{HTTP_USER_AGENT = $ua\n};
    print TMP qq{REMOTE_ADDR     = $ra\n};
    print TMP qq{HTTP_REFERER    = $ref\n};
    print TMP qq{REQUEST_URI     = $uri\n};
    print TMP qq{AUTH_USER       = $auth\n};
    print TMP "=" x 80, "\n";
    close(TMP);
}

sub read_param {
    $_GET{'profile'} = defined( param('profile') ) ? param('profile') : 'm99';
    $_GET{'profile'} =~ s/[^0-9a-zA-Z\-_]//g;

    $_GET{'prefix'} = defined( param('prefix') ) ? param('prefix') : '';
    $_GET{'prefix'} =~ s/[^0-9a-zA-Z]//g;

    $_GET{'degree'} = defined( param('degree') ) ? param('degree') : '';
    $_GET{'degree'} =~ s/\D//g;

    $_GET{'page'} = defined( param('page') ) ? param('page') : '';
    $_GET{'page'} =~ s/\D//g;

    $_GET{'filter'} = defined( param('filter') ) ? param('filter') : '*';
    $_GET{'filter'} =~ s/[^0-9a-zA-Z\-_\*\(\)&\|\!=><~]//g;

    $_GET{'modify_time'}
        = defined( param('modify_time') ) ? param('modify_time') : '0';
    $_GET{'modify_time'} =~ s/[^0-9]//g;

    $_GET{'substring'}
        = defined( param('substring') ) ? param('substring') : '';

    # lyshie: substring, student or non-student ?
    if ( $_GET{'substring'} ne '' ) {

        # lyshie_20110614: aovid LDAP Injection attack
        my $key = escape_filter_value( $_GET{'substring'} );
        $_GET{'filter'} = "(|(uid=*$key*)(sn=*$key*)(cn=*$key*))";
    }
    elsif ( $_GET{'degree'} ne '' ) {
        if ( $_GET{'degree'} eq '0' ) {
            $_GET{'filter'} = getNonStudentFilter();
        }
        else {
            $_GET{'filter'}
                = getStudentFilter( $_GET{'prefix'}, $_GET{'degree'},
                $_GET{'page'} );
        }
    }

    if ( $_GET{'modify_time'} ) {
        my $sec  = $_GET{'modify_time'} * 3600;
        my $now  = time();
        my $ever = $now - $sec;
        my $len  = 1;
        for my $i ( 0 .. length($now) ) {
            if ( substr( $now, $i, 1 ) eq substr( $ever, $i, 1 ) ) {
                $len++;
            }
            else {
                last;
            }
        }

        $ever = substr( $ever, 0, $len );
        $now  = substr( $now,  0, $len );

        my $filter = '|';
        for my $i ( $ever .. $now ) {
            $filter .= sprintf( "(description=*\\28%s*)", $i );
        }

        $_GET{'filter'} = sprintf( "(&(%s)%s)", $filter, $_GET{'filter'} );
    }
}

sub get_users {
    $T_BEGIN = time();
    my $result;
    my $result_sp;

    my $config = ldap_init_config( $_GET{'profile'} );
    my $ldap   = ldap_connect($config);

    $_ENV{'ldap_host'} = $ldap->host()       || '';
    $_ENV{'ldap_port'} = $ldap->port()       || '';
    $_ENV{'user'}      = $ENV{'REMOTE_USER'} || '';

    $result = ldap_get_users( $ldap, $config, undef, $_GET{'filter'} );
    $result_sp
        = ldap_get_users( $ldap, $config, $config->{'suspended_user_dn'},
        $_GET{'filter'} );

    ldap_disconnect($ldap);

    $result    = [ sort { $a->{'uid'} cmp $b->{'uid'} } @{$result} ];
    $result_sp = [ sort { $a->{'uid'} cmp $b->{'uid'} } @{$result_sp} ];

    my $i = 0;
    foreach ( @{$result} ) {
        $i++;
        $_->{'id'}                   = $i;
        $_->{'odd'}                  = ( $i % 2 );
        $_->{'group'}                = int( $i / 100 );
        $_->{'profile'}              = _H( $_GET{'profile'} );
        $_->{'quota'}                = _H( $config->{'quota_size'} );
        $_->{'escape_uid'}           = _H( $_->{'uid'} );
        $_->{'escape_uidnumber'}     = _H( $_->{'uidnumber'} );
        $_->{'escape_gidnumber'}     = _H( $_->{'gidnumber'} );
        $_->{'escape_loginshell'}    = _H( $_->{'loginshell'} );
        $_->{'escape_homedirectory'} = _H( $_->{'homedirectory'} );
        $_->{'cn'}                   = _H( uri_escape( $_->{'cn'} ) );
        $_->{'userpassword'} =~ s/^({.+}.{3}).*$/$1\.\.\./g;
    }

    foreach ( @{$result_sp} ) {
        $i++;
        $_->{'id'}                   = $i;
        $_->{'odd'}                  = ( $i % 2 );
        $_->{'group'}                = int( $i / 100 );
        $_->{'profile'}              = _H( $_GET{'profile'} );
        $_->{'quota'}                = _H( $config->{'quota_size'} );
        $_->{'escape_uid'}           = _H( $_->{'uid'} );
        $_->{'escape_uidnumber'}     = _H( $_->{'uidnumber'} );
        $_->{'escape_gidnumber'}     = _H( $_->{'gidnumber'} );
        $_->{'escape_loginshell'}    = _H( $_->{'loginshell'} );
        $_->{'escape_homedirectory'} = _H( $_->{'homedirectory'} );
        $_->{'cn'}                   = _H( uri_escape( $_->{'cn'} ) );
        $_->{'suspended'}            = 1;
        $_->{'userpassword'} =~ s/^({.+}.{3}).*$/$1\.\.\./g;
    }

    $T_END = time();

    my @total;
    push( @total, @{$result}, @{$result_sp} );

    return \@total;
}

sub getLoopPrefix {
    my @result;
    my %prefix = (
        u => 'u / 大學部',
        g => 'g / 碩士研究生',
        d => 'd / 博士研究生',
        s => 's / 不分類',
    );
    for my $c ( keys(%prefix) ) {
        my %hash = ();
        $hash{'prefix'}      = $c;
        $hash{'description'} = $prefix{$c};
        push( @result, \%hash );
    }

    return \@result;
}

sub getLoopDegree {
    my @result;
    for my $c ( '80' .. '100' ) {
        my %hash = ();
        $hash{'degree'} = $c;
        push( @result, \%hash );
    }

    return \@result;
}

sub getLoopPage {
    my @result;
    for my $c ( '0' .. '9', '00' .. '99' ) {
        my %hash = ();
        $hash{'page'} = $c;
        push( @result, \%hash );
    }

    return \@result;
}

sub getLoopProfile {

    # lyshie: log profiles and descriptions
    my ( $short, $long ) = getProfiles();
    my @data = ();
    for ( my $i = 0; $i < scalar(@$short); $i++ ) {
        my %hash = ();

        $hash{'PROFILE'} = _H( $short->[$i] );

        my $config = ldap_init_config( $short->[$i] );
        $hash{'PROFILE_LONG'} = _H( $config->{'name'} );

        push( @data, \%hash );
    }

    return \@data;
}

sub main {
    _debugConnectionInfo();
    read_param();

    my $template = HTML::Template->new(
        filename          => getTemplate("list_user.tmpl"),
        die_on_bad_params => 0,
    );
    $template->param( TIMESTAMP => time() );
    my $users_ref = get_users();
    $template->param( LOOP_LIST_USER => $users_ref );
    $template->param( GROUP_SIZE     => int( scalar(@$users_ref) / 100 ) );
    $template->param( COUNT          => scalar(@$users_ref) );
    $template->param( TIME           => $T_END - $T_BEGIN );
    $template->param( PROFILE        => $_GET{'profile'} );
    $template->param( MODIFY_TIME    => $_GET{'modify_time'} );
    $template->param( FILTER         => _H( $_GET{'filter'} ) );
    $template->param( PREFIX         => _H( $_GET{'prefix'} ) );
    $template->param( LOOP_PREFIX    => getLoopPrefix() );
    $template->param( DEGREE         => $_GET{'degree'} );
    $template->param( LOOP_DEGREE    => getLoopDegree() );
    $template->param( PAGE           => $_GET{'page'} );
    $template->param( LOOP_PAGE      => getLoopPage() );
    $template->param( LOOP_PROFILE   => getLoopProfile() );

    my $config = ldap_init_config( $_GET{'profile'} );
    $template->param(
        INFO => _H(
            sprintf(
                "%s (%s / %s:%s), (管理者：%s)",
                $_GET{'profile'},   $config->{'name'}, $_ENV{'ldap_host'},
                $_ENV{'ldap_port'}, $_ENV{'user'}
            )
        )
    );

    print header( -charset => 'utf-8' );    # later output
    print $template->output();
}

main();
