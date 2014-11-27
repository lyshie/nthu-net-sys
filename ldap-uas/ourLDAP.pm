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
package ourLDAP;

BEGIN { $INC{'ourLDAP.pm'} ||= __FILE__ }

use strict;
use warnings;

use Exporter;

use FindBin qw($Bin);
use Config::General qw(ParseConfig);
use Net::LDAP;
use Net::LDAP::Util qw(escape_filter_value);
use Net::LDAP::Schema;

# lyshie_20110411: experimental cache
use YAML::Syck;
use Digest::SHA qw(sha1_hex);

our @ISA    = qw(Exporter);
our @EXPORT = qw(
    ldap_init_config
    ldap_connect
    ldap_disconnect
    ldap_get_users
    ldap_get_users_via_cache
    ldap_get_user
    ldap_get_user_suspended
    ldap_get_groups
    ldap_query_group_name
    ldap_query_group_gid
    ldap_query_max_uid
    ldap_query_next_uid
    ldap_query_max_gid
    ldap_add_user
    ldap_get_users_by_sn
    ldap_get_users_suspended_by_sn
);

my %GROUP_NAMES = ();
my %GROUP_GIDS  = ();

my @EXT_ATTRIBUTES = qw(sn cn o title telephonenumber businesscategory);

sub ldap_init_config {
    my ($profile) = @_;

    # init variables - reset to NULL
    %GROUP_NAMES = ();
    %GROUP_GIDS  = ();

    $profile = defined($profile) ? $profile : 'default';
    $profile = $profile || 'default';

    my $config_file = "$Bin/profile.d/$profile.conf";
    my %config      = ();

    %config = ParseConfig( -ConfigFile => $config_file );

    if ( defined( $config{'basedn'} ) ) {
        $config{'binddn'}            .= ',' . $config{'basedn'};
        $config{'rootdn'}            .= ',' . $config{'basedn'};
        $config{'group_dn'}          .= ',' . $config{'basedn'};
        $config{'user_dn'}           .= ',' . $config{'basedn'};
        $config{'suspended_user_dn'} .= ',' . $config{'basedn'};
        $config{'alias_dn'}          .= ',' . $config{'basedn'};
    }

    return \%config;
}

# lyshie: add multi hosts support
sub ldap_connect {
    my ($config) = @_;

    my $cache_file = "/tmp/ldap_connect_$config->{'realm'}";
    my $cache_host;
    if ( -f $cache_file ) {
        open( FH, $cache_file );
        $cache_host = <FH> || undef;
        close(FH);

        # lyshie: expired then delete
        my $ft = ( stat($cache_file) )[9];
        if ( ( time() - $ft ) > 3_600 ) {
            unlink($cache_file);
            $cache_host = undef;
        }
    }

    my @hosts = ();
    if ( ref( $config->{'host'} ) eq 'ARRAY' ) {
        @hosts = @{ $config->{'host'} };
    }
    else {
        @hosts = ( $config->{'host'} );
    }

    my $ldap;
    unshift( @hosts, $cache_host ) if defined($cache_host);
    foreach my $host (@hosts) {
        $ldap = Net::LDAP->new(
            $host,
            async   => 1,
            timeout => $config->{'timeout'}
        );

        if ($ldap) {
            umask(0000);
            open( FH, ">$cache_file" );
            print FH $ldap->host();
            close(FH);
            last;
        }
    }

    $ldap or die($@);

    $ldap->bind( $config->{'binddn'}, password => $config->{'bindpw'} );

    return $ldap;
}

# lyshie: original single host
sub _ldap_connect {
    my ($config) = @_;

    my $ldap = Net::LDAP->new(
        $config->{'host'},
        async   => 1,
        timeout => $config->{'timeout'}
    ) or die($@);

    $ldap->bind( $config->{'binddn'}, password => $config->{'bindpw'} );

    return $ldap;
}

sub ldap_get_groups {
    my ( $ldap, $config ) = @_;

    my %result = ();

    my $mesg = $ldap->search(
        base   => $config->{'group_dn'},
        scope  => 'sub',
        filter => $config->{'group_filter'},
    );

    open( FH, ">>/tmp/fh.txt" );
    print FH $config->{'group_dn'}, "\n";
    close(FH);

    $mesg->code() && die( $mesg->error() );

    foreach my $entry ( $mesg->entries() ) {
        my $gidnumber = $entry->get_value('gidnumber');
        my $gid       = $entry->get_value('cn');
        $GROUP_NAMES{$gidnumber} = $gid;
        $GROUP_GIDS{$gid}        = $gidnumber;
        $result{$gidnumber}      = $gid;
    }

    return \%result;
}

sub ldap_query_group_gid {
    my ( $ldap, $config, $name ) = @_;

    my $result = $name;

    unless (%GROUP_GIDS) {
        ldap_get_groups( $ldap, $config );
    }

    if ( defined( $GROUP_GIDS{$name} ) ) {
        $result = $GROUP_GIDS{$name};
    }

    return $result;
}

sub ldap_query_group_name {
    my ( $ldap, $config, $gidnumber ) = @_;

    my $result = $gidnumber;

    unless (%GROUP_NAMES) {
        ldap_get_groups( $ldap, $config );
    }

    if ( defined( $GROUP_NAMES{$gidnumber} ) ) {
        $result = $GROUP_NAMES{$gidnumber};
    }

    return $result;
}

sub ldap_get_users {
    my ( $ldap, $config, $base, $filter_rule ) = @_;

    $base = defined($base) ? $base : $config->{'user_dn'};

    my $filter = $config->{'user_filter'};

    use Net::LDAP::Control::Paged;
    use Net::LDAP::Constant qw( LDAP_CONTROL_PAGED );
    my $page = Net::LDAP::Control::Paged->new( size => 25000 );

    if ( defined($filter_rule) ) {
        if ( $filter_rule !~ m/[\(\)]/g ) {
            $filter =~ s/=\*/=$filter_rule/;
        }
        else {
            if ( $filter_rule !~ m/objectclass=/i ) {
                $filter =~ s/\(uid=\*\)/$filter_rule/;
            }
            else {
                $filter = $filter_rule;
            }
        }
    }

    open( TMP, ">>/tmp/filter" );
    print TMP "$filter\n";
    close(TMP);

    #my $mesg = $ldap->search(
    my @users;
    my $mesg;
    my @args;

    my $cookie;
    my $j     = 0;
    my $index = 1;
    my $end   = 0;

SEARCH:
    while (1) {
        $j++;
        if ( ( $j > $index - 1 ) && ( $j < $index + 1 ) ) {
            @args = (
                base   => $base,
                scope  => 'sub',
                filter => $filter,
                attrs  => ["*"],

               #attrs => [ "uid", "uidnumber", "gidnumber", "homedirectory" ],
                control => [$page],
                deref   => 'never',
            );
        }
        else {
            @args = (
                base      => $base,
                scope     => 'sub',
                filter    => $filter,
                attrs     => ['1.1'],
                control   => [$page],
                deref     => 'never',
                typesonly => 1,
            );
        }

        $mesg = $ldap->search(@args);
        $mesg->code and last;

        if ( $j > $index - 1 ) {
            if ( $j < $index + 1 ) {
            ENTRY:
                while ( my $entry = $mesg->shift_entry() ) {
                    my %user = ();
                    $user{'uid'}       = $entry->get_value('uid');
                    $user{'uidnumber'} = $entry->get_value('uidnumber');
                    $user{'gidnumber'} = $entry->get_value('gidnumber');

                    $user{'gid'} = ldap_query_group_name( $ldap, $config,
                        $user{'gidnumber'} );
                    $user{'homedirectory'}
                        = $entry->get_value('homedirectory');
                    $user{'loginshell'}   = $entry->get_value('loginshell');
                    $user{'description'}  = $entry->get_value('description');
                    $user{'labeleduri'}   = $entry->get_value('labeleduri');
                    $user{'mail'}         = $entry->get_value('mail');
                    $user{'userpassword'} = $entry->get_value('userpassword');
                    $user{'cn'}           = $entry->get_value('cn');
                    $user{'sn'}           = $entry->get_value('sn');
                    $user{'profile'}      = $config->{'profile'};
                    push( @users, \%user );
                }
            }
            else {
                $end = 1;
                last SEARCH;
            }
        }

        my ($resp) = $mesg->control(LDAP_CONTROL_PAGED) or last;
        $cookie = $resp->cookie or last;
        $page->cookie($cookie);
    }

    if ( $cookie || $end ) {
        $page->cookie($cookie);
        $page->size(0);
        $ldap->search(@args);
    }

    return \@users;

    #    $mesg->code() && warn( $mesg->error() );
}

# lyshie_20110411: experimental cache
sub ldap_get_users_via_cache {
    my ( $ldap, $config, $base, $filter_rule ) = @_;

    my $users;

    my $cache_id = sha1_hex(
        sprintf( "%s_%s_%s_%s",
            $ldap->host(), $config->{'profile'},
            $base ? $base : '', $filter_rule ? $filter_rule : '' )
    );

    my $CACHE_PATH = "$Bin/cache";
    my $cache_file = "$CACHE_PATH/$cache_id";

    if ( -f $cache_file ) {
        $users = LoadFile($cache_file);
    }
    else {
        $users = ldap_get_users( $ldap, $config, $base, $filter_rule );
        DumpFile( $cache_file, $users );
    }

    return $users;
}

sub ldap_get_user_suspended {
    my ( $ldap, $config, $id ) = @_;

    return ldap_get_user( $ldap, $config, $id,
        $config->{'suspended_user_dn'} );
}

sub ldap_query_max_uid {
    my ( $ldap, $config ) = @_;

    my $users = ldap_get_users( $ldap, $config );
    my $users_sp
        = ldap_get_users( $ldap, $config, $config->{'suspended_user_dn'} );

    my $max_uid = $config->{'min_uid'};

    foreach ( @$users, @$users_sp ) {
        if (   ( $_->{'uidnumber'} > $max_uid )
            && ( $_->{'uidnumber'} < $config->{'max_uid'} ) )
        {
            $max_uid = $_->{'uidnumber'};
        }
    }

    return $max_uid;
}

# lyshie_20100826: solve uidNumber conflict problem
sub _is_uid_conflict {
    my ( $ldap, $config, $uidnumber ) = @_;
    my $mesg;

    $mesg = $ldap->search(
        base   => $config->{'user_dn'},
        scope  => 'sub',
        filter => "(uidnumber=$uidnumber)",
        attrs  => ["uidnumber"],
    );
    return 1 if ( $mesg->count() > 0 );

    $mesg = $ldap->search(
        base   => $config->{'suspended_user_dn'},
        scope  => 'sub',
        filter => "(uidnumber=$uidnumber)",
        attrs  => ["uidnumber"],
    );
    return 1 if ( $mesg->count() > 0 );

    return 0;
}

# lyshie_20130122: merge the following codes into upstream and slightly modified
#                  1. convert to internal function
#                  2. rename variables
#                  3. lower-case attribute name
#                  4. prevent an infinite loop
#                  5. return default uidNumber=0 if failed
#
sub _get_next_uid {
    my ( $ldap, $config ) = @_;

    my ( $base, $uid, $mesg, $entry ) = ( '', 0 );
    my ( @add, @delete, @changes );

    $base = "dc=$config->{'realm_short'},$config->{'basedn'}";

    my $max_try = 5;

    while ( $max_try > 0 ) {
        $max_try--;

        my $mesg = $ldap->search(
            base   => $base,
            scope  => "base",
            filter => "(|(objectclass=uidPool)(objectclass=posixAccount))",
            attrs  => ["uidnumber"],
        );

        if ( $mesg->code ) {
            warn( $mesg->error() );
            last;
        }

        if ( !$mesg->count ) {
            warn("Unable to locate uidPool entry!");
            last;
        }

        # Get the next UID
        $entry = $mesg->entry(0);
        $uid = $entry->get_value('uidnumber') || 0;

        if ( !$uid ) {
            warn("Unable to get uidnumber!");
            last;
        }

        # Update the next UID in the directory
        push( @delete,  'uidnumber', $uid );
        push( @add,     'uidnumber', $uid + 1 );
        push( @changes, 'delete',    \@delete );
        push( @changes, 'add',       \@add );
        my $result = $ldap->modify( $entry->dn(), 'changes' => [@changes] );

        if ( !$result->code() ) {    # OK
            last;
        }
        else {
            $uid = 0;                # fall back to zero
        }
    }

    return $uid;
}

# lyshie_20100826: solve uidNumber conflict problem
sub ldap_query_next_uid {
    my ( $ldap, $config ) = @_;

    #my $range    = $config->{'max_uid'} - $config->{'min_uid'};
    my $next_uid = 0;

    my $max_try = 100;

    while ( $max_try > 0 ) {
        $max_try--;

        $next_uid = _get_next_uid( $ldap, $config );

        if ( !$next_uid || _is_uid_conflict( $ldap, $config, $next_uid ) ) {
            next;
        }
        else {
            last;
        }

        #if ( $try > 3 ) {    # sequential method
        #    $next_uid = ldap_query_max_uid( $ldap, $config ) + 1;
        #}
        #else {               # random jump method
        #    $next_uid = $config->{'min_uid'} + int( rand($range) );
        #}
    }

    die("$next_uid is less than the min_uid")
        if ( $next_uid < $config->{'min_uid'} );
    die("$next_uid is greater than the min_uid")
        if ( $next_uid > $config->{'max_uid'} );

    return $next_uid;
}

sub ldap_query_max_gid {
    my ( $ldap, $config ) = @_;

    my %groups = %{ ldap_get_groups( $ldap, $config ) };

    my $max_gidnumber = 0;
    foreach ( keys(%groups) ) {
        if ( $_ > $max_gidnumber ) {
            $max_gidnumber = $_;
        }
    }

    return $max_gidnumber;
}

sub ldap_get_user {
    my ( $ldap, $config, $id, $base, $ext ) = @_;

    $base = defined($base) ? $base : $config->{'user_dn'};

    my $filter = $config->{'user_filter'};

    if ( $id =~ m/^\d+$/ ) {    # for student-id
        $filter =~ s/uid=\*/|(uid=s$id)(uid=u$id)(uid=g$id)(uid=d$id)/
            ;                   # s, u, g, d
    }
    else {
        $filter =~ s/=\*/=$id/;
    }

    my $mesg = $ldap->search(
        base   => $base,
        scope  => 'sub',
        filter => $filter,
        attrs  => ["*"],
    );

    $mesg->code() && warn( $mesg->error() );

    my $count = $mesg->count();

    my @users;
    for ( my $i = 0; $i < $count; $i++ ) {
        my $entry = $mesg->entry($i);

        my %user = ();
        $user{'uid'}       = $entry->get_value('uid');
        $user{'uidnumber'} = $entry->get_value('uidnumber');
        $user{'gidnumber'} = $entry->get_value('gidnumber');
        $user{'gid'}
            = ldap_query_group_name( $ldap, $config, $user{'gidnumber'} );
        $user{'homedirectory'} = $entry->get_value('homedirectory');
        $user{'loginshell'}    = $entry->get_value('loginshell');
        $user{'description'}   = $entry->get_value('description');
        $user{'labeleduri'}    = $entry->get_value('labeleduri');
        $user{'mail'}          = $entry->get_value('mail');
        $user{'userpassword'}  = $entry->get_value('userpassword');
        $user{'profile'}       = $config->{'profile'};

        # ----
        $user{'gecos'} = $entry->get_value('gecos');
        $user{'sn'}    = $entry->get_value('sn');
        $user{'cn'}    = $entry->get_value('cn');
        if ($ext) {
            foreach my $k (@EXT_ATTRIBUTES) {
                $user{$k} = $entry->get_value($k)
                    if ( defined( $entry->get_value($k) ) );
            }
        }
        push( @users, \%user );
    }

    # lyshie_20110914: u, g, d => d should be the first priority
    if ( scalar(@users) > 1 ) {
        @users = sort { $a->{'uid'} cmp $b->{'uid'} } @users;
    }

   # lyshie_20110914: remove the above code after solving the u, g, d problems

    return \@users;
}

sub ldap_disconnect {
    my ($ldap) = @_;

    $ldap->unbind();
}

sub ldap_get_must_attr {
    my ($ldap) = @_;

    my @ocs = qw(inetOrgPerson posixAccount shadowAccount top);

    my $schema = $ldap->schema();

    foreach my $oc (@ocs) {
        my @must = $schema->must($oc);

        #print "[$oc]\n";
        #print "* ", $_->{'name'}, "\n" foreach ( sort @must );
        my @may = $schema->may($oc);

        #print "  + ", $_->{'name'}, "\n" foreach ( sort @may );
    }
}

sub ldap_add_user {
    my ( $ldap, $config, $attrs ) = @_;

    my $ret_msg = '';

    my @array = %{$attrs};
    my $result
        = $ldap->add( 'uid=' . $attrs->{'uid'} . ',' . $config->{'user_dn'},
        attr => \@array );

    if ( !$result->code() ) {
        $ret_msg .= sprintf( "完成建立新帳號 %s@%s\n",
            $attrs->{'uid'}, $config->{'realm'} );
        $ret_msg .= sprintf( "Created new account: %s@%s\n",
            $attrs->{'uid'}, $config->{'realm'} );
    }
    else {
        $ret_msg .= sprintf( "無法建立新帳號 %s@%s (%s)\n",
            $attrs->{'uid'}, $config->{'realm'}, $result->error() );
        $ret_msg .= sprintf( "Failed to create new account: %s@%s (%s)\n",
            $attrs->{'uid'}, $config->{'realm'}, $result->error() );
    }

    return ( $result->code(), $ret_msg );
}

sub ldap_get_users_by_sn {
    my ( $ldap, $config, $id, $base ) = @_;

    my $sn = lc($id);

    my @result = ();
    if ( $config->{'multi_profiles'} ) {
        my @find_profiles = ();
        if ( ref( $config->{'find_profile'} ) eq 'ARRAY' ) {
            @find_profiles = @{ $config->{'find_profile'} };
        }
        else {
            @find_profiles = ( $config->{'find_profile'} );
        }
        foreach my $p (@find_profiles) {
            my $c   = ldap_init_config($p);
            my $ref = ldap_get_users( $ldap, $c, $base,
                qq{(&(objectclass=posixAccount)(uid=*)(sn=$sn))} );
            push( @result, @$ref );
        }
    }

    return \@result;
}

sub ldap_get_users_suspended_by_sn {
    my ( $ldap, $config, $id ) = @_;

    return ldap_get_users_by_sn( $ldap, $config, $id,
        $config->{'suspended_user_dn'} );
}

=cut
sub main {
    %_CONFIG = init_config();

    my $ldap = ldap_connect( \%_CONFIG );

    #ldap_dump_user( $ldap, \%_CONFIG );
    #ldap_dump_group( $ldap, \%_CONFIG );
    ldap_disconnect($ldap);
}

main();
=cut

1;
