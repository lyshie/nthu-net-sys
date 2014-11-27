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

use File::stat;
use MIME::Lite;
use FindBin qw($Bin);
use File::Basename;

my %ADMINS = ( 'lyshie@mx.nthu.edu.tw' => 'Shie, Li-Yi', );

my $ABS_PATH = $Bin;
$ABS_PATH =~ s/\/ldap\-uas.*$//g;

my %PATHS = (
    "$ABS_PATH/ldap-uas/bugs" => '[LDAP-UAS] Bug Report',
    "$ABS_PATH/portal/bugs"   => '[Portal] Bug Report',
    "$ABS_PATH/ldap-uas/logs" => '[LDAP-UAS] Logs',
);

my $NOW = time();

sub get_files {
    my @files = ();

    foreach my $path ( sort keys(%PATHS) ) {
        next if ( !-d $path );
        opendir( DH, $path );
        my @fs = grep { -f "$path/$_" } readdir(DH);
        closedir(DH);
        foreach (@fs) {
            my $filename = "$path/$_";
            if ( $NOW - ( stat($filename) )->ctime() < 86400 ) {
                push( @files, $filename );
            }
        }
    }

    return @files;
}

sub mail_send {
    my @files = @_;

    my $msg = MIME::Lite->new(
        From    => 'root@ua.net.nthu.edu.tw',
        To      => join( ', ', keys(%ADMINS) ),
        Subject => sprintf( '[LDAP-UAS] Daily Report (%s)',
            scalar( localtime($NOW) ) ),
        Type => 'multipart/mixed',
    );

    $msg->attach(
        Type => 'TEXT',
        Data => sprintf( "[LDAP-UAS] Daily Report (%s)\n\n",
            scalar( localtime($NOW) ) )
            . join( "\n", @files ),
    );

    my $i = 0;
    foreach (@files) {
        $i++;
		my $fn = basename($_);
        $msg->attach(
            Type        => 'TEXT',
            Path        => $_,
            Filename    => $fn . '.txt',
            Disposition => 'attachment',
            Encoding    => 'base64',
        );

    }

    $msg->send( 'smtp', 'antispam.net.nthu.edu.tw' );
}

sub main {
    my @fs = get_files();

    mail_send(@fs);
}

main;
