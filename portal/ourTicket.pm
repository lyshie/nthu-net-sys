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
package ourTicket;

BEGIN { $INC{'ourTicket.pm'} ||= __FILE__ }

use strict;
use warnings;

use FindBin qw($Bin);
use YAML::Syck;
use MIME::Base64;
use File::Spec;
use File::Basename;
use File::stat;
use Digest::MD5 qw(md5_hex);
use Crypt::CBC;
use List::Util qw(min max);
use lib "$Bin";

our @ISA    = qw(Exporter);
our @EXPORT = qw(
    getTicketNumber
    getTicketPath
    isTicketPathOK
    isTicketExist
    isTicketExpired
    createTicket
    readTicket
    deleteTicket
    recycleTicket
    encryptTicket
    decryptTicket
);

my $SECRET_KEY = '';
my $MAX_TTL    = 60 * 30;                                        # 30 minutes

sub getTicketNumber {
    my $entropy = rand(859) . time() . rand(859);

    return md5_hex($entropy);
}

sub getTicketPath {
    my $target = 'ldap-uas';
    my $ticket = 'tickets';

    my $file   = basename($Bin);
    my $parent = dirname($Bin);

    if ( $file ne $target ) {
        return File::Spec->join( $parent, $target, $ticket );
    }
    else {
        return File::Spec->join( $Bin, $ticket );
    }
}

sub isTicketPathOK {
    my $dir = getTicketPath();

    if ( -r $dir && -w $dir ) {
        return $dir;
    }
    else {
        return undef;
    }
}

sub isTicketExist {
    my ($ticket_number) = @_;

    if ( my $dir = isTicketPathOK() ) {
        my $filename = File::Spec->join( $dir, $ticket_number );

        if ( -r $filename ) {
            return $filename;
        }
        else {
            return undef;
        }
    }
    else {
        return undef;
    }
}

sub isTicketExpired {
    my ( $filename, $ttl, $now ) = @_;

    $ttl = defined($ttl) ? $ttl : $MAX_TTL;
    $now = defined($now) ? $now : time();

    $ttl = min( $MAX_TTL, $ttl );

    my $st = stat($filename) or return undef;

    if ( ( $now - $st->ctime() ) > $ttl ) {
        return $st->ctime();    # expired
    }
    else {
        return undef;           # still alive
    }
}

sub createTicket {
    my ($data) = @_;

    if ( my $dir = isTicketPathOK() ) {
        my $ticket_number = getTicketNumber();
        my $yaml          = Dump($data);
        my $data          = encode_base64( encryptTicket($yaml) );

        my $filename = File::Spec->join( $dir, $ticket_number );
        open( FH, ">", $filename );
        print FH $data;
        close(FH);

        return $ticket_number;
    }
    else {
        return "";
    }
}

sub readTicket {
    my ($ticket_number) = @_;

    if ( my $filename = isTicketExist($ticket_number) ) {
        my $data = '';
        open( FH, "<", $filename );
        do {
            local $/ = undef;
            $data = <FH>;
        };
        close(FH);

        my $yaml   = decryptTicket( decode_base64($data) );
        my $result = Load($yaml);

        return $result;

    }
    else {
        return undef;
    }
}

sub deleteTicket {
    my ($ticket_number) = @_;

    if ( my $filename = isTicketExist($ticket_number) ) {
        unlink($filename);
        recycleTicket();

        return $filename;
    }
    else {
        return undef;
    }
}

sub recycleTicket {
    my $count = 0;
    my $now   = time();

    if ( my $dir = isTicketPathOK() ) {
        opendir( DH, $dir );
        my @tickets = grep { -f File::Spec->join( $dir, $_ ) } readdir(DH);
        closedir(DH);

        my @deleted = ();
        foreach my $ticket (@tickets) {
            my $filename = File::Spec->join( $dir, $ticket );

            if ( isTicketExpired( $filename, $MAX_TTL, $now ) ) {
                push( @deleted, $filename );
                unlink($filename);
            }
        }

        return scalar(@deleted);
    }

    return $count;
}

sub _getCipher {
    my $cipher = Crypt::CBC->new(
        -key    => $SECRET_KEY,
        -cipher => 'Blowfish',
    );

    return $cipher;
}

sub encryptTicket {
    my ($plain) = @_;

    my $cipher = _getCipher();

    return $cipher->encrypt($plain);
}

sub decryptTicket {
    my ($secret) = @_;

    my $cipher = _getCipher();

    return $cipher->decrypt($secret);
}

1;
