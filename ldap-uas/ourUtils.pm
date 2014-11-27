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

BEGIN { $INC{'ourUtils.pm'} ||= __FILE__ }

use strict;
use warnings;

use Exporter;
use FindBin qw($Bin);
use Encode qw(from_to encode decode);
use HTML::Entities;
use Net::Telnet;
use Authen::Passphrase::MD5Crypt;
use DateTime;
use lib "$Bin";
use ourLDAP;
use ourLanguage;
use ourShortenName;
use ourAccountCheck;
use lib_crypt;

our @ISA    = qw(Exporter);
our @EXPORT = qw(
    getProfiles
    getRole
    getEmailName
    getSuggestNames
    isUserExist
    isUserSuspended
    getStudentFilter
    getNonStudentFilter
    generatePassword
    makeHomeDir
    setQuota
    getQuota
    getRemoteAddr
    getProgramName
    utf8_to_big5
    isPasswordSuspended
    isPasswordStop
    unix_to_ldap_time
    ldap_to_unix_time
    replace_pattern
    getConditionBool
    passwordStrength
);

sub getProfiles {
    my @short = ();
    my @long  = ();

    my $path = "$Bin/profile.d";
    opendir( DH, $path );
    @long = sort grep { -f "$path/$_" && !-l "$path/$_" && m/\.conf$/ }
        readdir(DH);    # no symbol link files
    closedir(DH);

    @short = @long;
    map {s/\.conf$//} @short;

    return ( \@short, \@long );
}

sub getEmailName {
    my ( $id, $degree, $role ) = @_;

    my $result = '';

    if ( $degree =~ m/^\d+$/ ) {    # student
        if ( $degree < 98 ) {       # oz (97, 96, 95...)
            if ( isUserSuspended( $id, $degree, $role ) ) {
                my $config = ldap_init_config("m$degree");
                my $ldap   = ldap_connect($config);
                my $users  = ldap_get_user_suspended( $ldap, $config, $id );
                my $uid
                    = defined( $users->[0]->{'uid'} )
                    ? $users->[0]->{'uid'}
                    : '';
                $result = sprintf( '%s@oz.nthu.edu.tw', $uid );
            }
            elsif ( isUserExist( $id, $degree, $role ) ) {
                my $config = ldap_init_config("m$degree");
                my $ldap   = ldap_connect($config);
                my $users  = ldap_get_user( $ldap, $config, $id );
                my $uid
                    = defined( $users->[0]->{'uid'} )
                    ? $users->[0]->{'uid'}
                    : '';
                $result = sprintf( '%s@oz.nthu.edu.tw', $uid );
            }
            else {
                $result = sprintf( 's%s@oz.nthu.edu.tw', $id );
            }
        }
        else {
            $result = sprintf( 's%s@m%s.nthu.edu.tw', $id, $degree );
        }
    }
    else {    # non-student
        $id =~ s/@.*$//g;
        my $config = ldap_init_config($role);

        if ( $role eq 'staff' ) {
            $result = '';
        }
        else {
            $result = sprintf( '%s@%s', $id, $config->{'realm'} );
        }
    }

    return $result;
}

sub getSuggestNames {
    my ($id) = @_;

    my @result;

    my @names  = getShortenNames($id);
    my @names2 = ();
    my @names3 = ();

    foreach my $n (@names) {
        $n = lc($n);
        if ( checkAccountReady($n) ) {
            push(
                @result,
                {   suggest_name => $n,
                    crypt        => $n . ':' . lib_crypt::encrypt($n),
                }
            );
        }
        else {
            push( @names2, sprintf( "%s2", $n ) );
        }
    }

    # second chance
    foreach my $n (@names2) {
        $n = lc($n);
        if ( checkAccountReady($n) ) {
            push(
                @result,
                {   suggest_name => $n,
                    crypt        => $n . ':' . lib_crypt::encrypt($n),
                }
            );
        }
        else {
            $n =~ s/2+$//g;
            push( @names3, sprintf( "%s3", $n ) );
        }
    }

    # third chance
    foreach my $n (@names3) {
        $n = lc($n);
        if ( checkAccountReady($n) ) {
            push(
                @result,
                {   suggest_name => $n,
                    crypt        => $n . ':' . lib_crypt::encrypt($n),
                }
            );
        }
    }

    @result = sort {
        ( length( $a->{'suggest_name'} ) <=> length( $b->{'suggest_name'} ) )
            || ( $a->{'suggest_name'} cmp $b->{'suggest_name'} )
    } @result;

    return @result;
}

sub isUserExist {
    my ( $id, $degree, $role ) = @_;
    my $result;

    my ( $config, $ldap, $users );

    if ( $degree =~ m/^\d+$/ ) {    # student
        $config = ldap_init_config("m$degree");
        $ldap   = ldap_connect($config);
        $users  = ldap_get_user( $ldap, $config, $id );
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
            $users = ldap_get_user( $ldap, $config, $id );
        }
    }
    ldap_disconnect($ldap);

    if ( scalar(@$users) > 0 ) {
        $result = 1;
    }
    else {
        $result = 0;
    }

    if ( wantarray() ) {
        return ( $result, $users );
    }
    else {
        return $result;
    }
}

sub isUserSuspended {
    my ( $id, $degree, $role ) = @_;
    my $result;

    my ( $config, $ldap, $users );

    if ( $degree =~ m/^\d+$/ ) {    # student
        $config = ldap_init_config("m$degree");
        $ldap   = ldap_connect($config);
        $users  = ldap_get_user_suspended( $ldap, $config, $id );
    }
    else {                          # non-student
        $id =~ s/@.*$//g;
        $config = ldap_init_config("$role");
        $ldap   = ldap_connect($config);

        if ( $role eq 'staff' ) {
            $users = ldap_get_users_suspended_by_sn( $ldap, $config, $id );
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
            $users = ldap_get_user_suspended( $ldap, $config, $id );
        }
    }
    ldap_disconnect($ldap);

    if ( scalar(@$users) > 0 ) {
        $result = 1;
    }
    else {
        $result = 0;
    }

    if ( wantarray() ) {
        return ( $result, $users );
    }
    else {
        return $result;
    }
}

sub getRole {
    my ($id) = @_;
    $id = lc($id);

    my ( $role, $degree ) = ( '', '' );

    if ( $id =~ m/^[a-z]\d+$/ ) {
        $role   = 'staff';
        $degree = '';
    }
    elsif ( $id =~ m/^\d+$/ ) {
        $role = 'student';

        #  (98) (12)(34)(5)(67)
        #  (99) (12)(34)(5)(67)
        # (100)(123)(45)(6)(789)
        if ( length($id) < 8 ) {
            $degree = substr( $id, 0, 2 );
        }
        else {
            $degree = substr( $id, 0, 3 );
        }
    }
    elsif ( $id =~ m/^(.+?)@(.+)$/ ) {
        $role   = $2;
        $degree = '';
    }

    return ( $role, $degree );
}

sub getNonStudentFilter {
    my $filter = '(!(|';

    for my $ci (qw(u g d s)) {
        for my $cj ( '0' .. '9' ) {
            $filter .= qq{(uid=$ci$cj*)};
        }
    }

=comment
    my $filter = '(|';

    for my $ci ( 'a' .. 'z' ) {
        for my $cj ( 'a' .. 'z' ) {
            $filter .= qq{(uid=$ci$cj*)};
        }
    }

=cut

    $filter .= '))';
    return $filter;
}

sub getStudentFilter {
    my ( $prefix, $degree, $page ) = @_;

    $prefix = defined($prefix) ? $prefix : '';
    $degree = defined($degree) ? $degree : '';
    $page   = defined($page)   ? $page   : '';

    my $filter = '(|';

    if ( $prefix ne '' ) {
        $filter .= qq{(uid=$prefix$degree$page*)};

    }
    else {
        for my $c (qw(u g d s)) {
            $filter .= qq{(uid=$c$degree$page*)};
        }
    }

    $filter .= ')';

    return $filter;
}

sub generatePassword {
    my ($plain) = @_;

    my $ppr = Authen::Passphrase::MD5Crypt->new(
        salt_random => 1,
        passphrase  => $plain,
    );

    return $ppr->as_rfc2307();
}

sub makeHomeDir {
    my ( $host, $port, $username, $uid, $gid, $home_dir ) = @_;

    my $t = Net::Telnet->new(
        Host    => $host,
        Port    => $port,
        Timeout => 10,
        Errmode => 'return'
    );

    my $output = ();

    if ( defined($t) ) {
        $t->print(qq{$username:$uid:$gid:$home_dir});
        my @tmp;
        @tmp = $t->getlines();
        $output
            = sprintf(
            "Create home directory [uid = %s], [uidNumber = %s], [gidNumber = %s], [homeDirectory = %s], [result = %s].",
            $username, $uid, $gid, $home_dir, join( "; ", @tmp ) );
    }
    else {
        $output
            = sprintf(
            "Failed to create home directory [uid = %s], [uidNumber = %s], [gidNumber = %s], [homeDirectory = %s].",
            $username, $uid, $gid, $home_dir );
    }

    return $output;
}

sub setQuota {
    my ( $host, $port, $uid, $uidnumber, $domain, $quota ) = @_;

    my $t = Net::Telnet->new(
        Host    => $host,
        Port    => $port,
        Timeout => 10,
        Errmode => 'return'
    );

    my $output = '';

    if ( defined($t) ) {
        $t->print(qq{uid=$uidnumber,domain=$domain,quota=$quota});
        my @tmp = ();
        @tmp = $t->getlines();
        $output
            = sprintf(
            "OK: Set quota [uid = %s], [uidNumber = %s], [quota = %s], [result = %s]",
            $uid, $uidnumber, $quota, join( "; ", @tmp ) );
    }
    else {
        $output
            = sprintf(
            "FAIL: Set quota [uid = %s], [uidNumber = %s], [quota = %s]",
            $uid, $uidnumber, $quota );
    }

    return $output;
}

sub getQuota {
    my ( $host, $port, $uid ) = @_;

    my $t = Net::Telnet->new(
        Host    => $host,
        Port    => $port,
        Timeout => 10,
        Errmode => 'return'
    );

    my $output = '';

    if ( defined($t) ) {
        $t->print(qq{$uid});
        my @tmp = ();
        @tmp    = $t->getlines();
        $output = sprintf( "OK: Get quota [uid = %s], [result = %s]",
            $uid, join( "; ", @tmp ) );
    }
    else {
        $output = sprintf( "FAIL: Get quota [uid = %s]", $uid );
    }

    return $output;
}

sub getRemoteAddr {
    my $result = '';
    $result = defined( $ENV{'REMOTE_ADDR'} ) ? $ENV{'REMOTE_ADDR'} : '-';

    return $result;
}

sub getProgramName {
    my ($name) = @_;

    $name = defined($name) ? $name : $0;

    $name =~ s/^.*\///g;
    $name =~ s/\..*$//g;
    $name =~ s/_/\-/g;

    return $name;
}

sub utf8_to_big5 {
    my ( $str, $is_safe ) = @_;

    $is_safe = defined($is_safe) ? $is_safe : 1;

    my $result = '';

    if ($is_safe) {
        my $ucs = decode( "utf-8", $str );

        foreach ( split( //, $ucs ) ) {
            my $c = encode( "big-5", $_, Encode::FB_QUIET );
            $c = encode_entities($_) if ( $c eq '' );
            $result .= $c;
        }
    }
    else {
        $result = $str;
        from_to( $result, "utf-8", "big5" );
    }

    return $result;
}

sub isPasswordSuspended {
    my ( $id, $degree, $role, $sid ) = @_;

    my ( $config, $ldap, $users );

    my ( $userpassword, $description );

    if ( $degree =~ m/^\d+$/ ) {    # student
        $config = ldap_init_config("m$degree");
        $ldap   = ldap_connect($config);
        $users  = ldap_get_users( $ldap, $config, undef,
            "(|(uid=s$id)(uid=u$id)(uid=g$id)(uid=d$id))" );

        $userpassword
            = defined( $users->[0]->{'userpassword'} )
            ? $users->[0]->{'userpassword'}
            : '';

        $description
            = defined( $users->[0]->{'description'} )
            ? $users->[0]->{'description'}
            : '';
    }
    else {    # non-student
        $id =~ s/@.*$//g;
        $config = ldap_init_config("$role");
        $ldap   = ldap_connect($config);
        $users
            = ldap_get_users( $ldap, $config, undef, "(|(uid=$id)(sn=$id))" );

        $userpassword
            = defined( $users->[0]->{'userpassword'} )
            ? $users->[0]->{'userpassword'}
            : '';

        $description
            = defined( $users->[0]->{'description'} )
            ? $users->[0]->{'description'}
            : '';
    }

    ldap_disconnect($ldap);

    # suspended password alarm

    if ( $userpassword =~ m/^{_SUSPEND_}/ ) {
        $description
            = ( grep {m/^adm\-suspendpasswd/} split( /;/, $description ) )
            [-1];
        $description = ( split( /[,\(\)]/, $description ) )[-1];

        return $description or 1;
    }
    else {
        return undef;
    }
}

sub isPasswordStop {
    my ( $id, $degree, $role, $sid ) = @_;

    my ( $config, $ldap, $users );

    my ( $userpassword, $description );

    if ( $degree =~ m/^\d+$/ ) {    # student
        $config = ldap_init_config("m$degree");
        $ldap   = ldap_connect($config);
        $users  = ldap_get_users( $ldap, $config, undef,
            "(|(uid=s$id)(uid=u$id)(uid=g$id)(uid=d$id))" );

        $userpassword
            = defined( $users->[0]->{'userpassword'} )
            ? $users->[0]->{'userpassword'}
            : '';

        $description
            = defined( $users->[0]->{'description'} )
            ? $users->[0]->{'description'}
            : '';
    }
    else {    # non-student
        $id =~ s/@.*$//g;
        $config = ldap_init_config("$role");
        $ldap   = ldap_connect($config);
        $users
            = ldap_get_users( $ldap, $config, undef, "(|(uid=$id)(sn=$id))" );

        $userpassword
            = defined( $users->[0]->{'userpassword'} )
            ? $users->[0]->{'userpassword'}
            : '';

        $description
            = defined( $users->[0]->{'description'} )
            ? $users->[0]->{'description'}
            : '';
    }

    ldap_disconnect($ldap);

    # stop password alarm

    if ( $userpassword =~ m/^{_STOP_}/ ) {
        $description
            = ( grep {m/^adm\-stoppasswd/} split( /;/, $description ) )[-1];
        $description = ( split( /[,\(\)]/, $description ) )[-1];

        return $description or 1;
    }
    else {
        return undef;
    }
}

sub unix_to_ldap_time {
    my ($unix_time) = @_;

    my $result = '';
    my ( $year, $month, $day, $hour, $min, $sec )
        = ( gmtime($unix_time) )[ 5, 4, 3, 2, 1, 0 ];

    $result = sprintf(
        "%04d%02d%02d%02d%02d%02dZ",
        $year + 1900,
        $month + 1, $day, $hour, $min, $sec
    );

    return $result;
}

sub ldap_to_unix_time {
    my ($source) = @_;

    my $result = 0;
    my ( $year, $month, $day, $hour, $min, $sec );

    if ( $source =~ m/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/ ) {
        $year  = $1;    # - 1900;
        $month = $2;    # - 1;
        $day   = $3;
        $hour  = $4;
        $min   = $5;
        $sec   = $6;
    }

    my $dt = DateTime->new(
        year   => $year,
        month  => $month,
        day    => $day,
        hour   => $hour,
        minute => $min,
        second => $sec,
    );
    $result = $dt->epoch();

    return $result;
}

sub replace_pattern {
    my ( $string, $ref ) = @_;

    while ( $string =~ m/(\$[A-Z]+)(\{[0-9\-]+,[0-9\-]+\})*/ ) {
        if ( defined($1) ) {
            my $one_b = $-[1];
            my $one_e = $+[1];

            my $key = substr( lc($1), 1 );
            my $value = $ref->{$key};

            if ( defined($2) ) {
                my $two_b = $-[2];
                my $two_e = $+[2];

                my $tmp = $2;
                $tmp =~ s/[\{\}]//g;
                my ( $v_index, $v_len ) = split( /,/, $tmp );
                $v_index = int($v_index);
                $v_len   = int($v_len);

                $value = substr( $value, $v_index, $v_len );
                substr( $string, $one_b, $two_e - $one_b ) = $value;
            }
            else {
                substr( $string, $one_b, $one_e - $one_b ) = $value;
            }

        }
    }

    return $string;
}

sub getConditionBool {
    my ($condition) = @_;

    $condition = defined($condition) ? $condition : '';

    my $result = 0;

    if ( $condition =~ m/^(?:一般|出國|借調|校|復|畢)$/ ) {
        $result = 1;
    }

    return $result;
}

sub passwordStrength {
    my ( $username, $password ) = @_;

    if ( !defined($password) || !defined($username) ) {
        return ( -3, 'No password or username' );
    }
    elsif ( length($password) < 8 ) {
        return ( -2, 'Password is too short' );
    }
    elsif ( index( lc($password), lc($username) ) != -1 ) {
        return ( -1, 'Password is similar to username' );
    }

    my $LOWER   = qr/[a-z]/;
    my $UPPER   = qr/[A-Z]/;
    my $DIGIT   = qr/[0-9]/;
    my $DIGITS  = qr/[0-9].*[0-9]/;
    my $SPECIAL = qr/[^a-zA-Z0-9]/;

    my $lower   = ( $password =~ m/$LOWER/ );
    my $upper   = ( $password =~ m/$UPPER/ );
    my $digit   = ( $password =~ m/$DIGIT/ );
    my $digits  = ( $password =~ m/$DIGITS/ );
    my $special = ( $password =~ m/$SPECIAL/ );

    if (   ( $lower && $upper && $digit )
        || ( $lower && $digits )
        || ( $upper && $digits )
        || ($special) )
    {
        return ( 2, 'Strong password' );
    }
    elsif (( $lower && $upper )
        || ( $lower && $digit )
        || ( $upper && $digit ) )
    {
        return ( 1, 'Good password' );
    }
    else {
        return ( 0, 'Weak password' );
    }
}

1;
