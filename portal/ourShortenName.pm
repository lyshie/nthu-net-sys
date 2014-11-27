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

BEGIN { $INC{'ourShortenName.pm'} ||= __FILE__ }

use strict;
use warnings;

use Exporter;
use FindBin qw($Bin);
use lib "$Bin";

our @ISA    = qw(Exporter);
our @EXPORT = qw(
    getShortenNames
);

sub _capital {
    my ($str) = @_;

    $str = defined($str) ? $str : "";

    $str =~ s/   (
               (^\w)    # at the beginning of the line
                 |      # or
               (\s\w)   # preceded by whitespace
                 )
              /\U$1/xg;
    $str =~ s/([\w']+)/\u\L$1/g;

    return $str;
}

sub _capitalAll {
    my (@a) = @_;

    my @result = ();

    foreach (@a) {
        push( @result, _capital($_) );
    }

    return @result;
}

sub getShortenNames {
    my ($name) = @_;
    $name = $name ? lc($name) : "";

    my ( $h_part, $t_part );

    if ( ( $name !~ m/,/ ) && ( $name =~ m/^\S+\s+\S+$/ ) ) {    # Li-Yi SHIE
        ( $t_part, $h_part ) = split( /\s+/, $name, 2 );
    }
    else {                                                       # SHIE, Li-Yi
        ( $h_part, $t_part ) = split( /,/, $name, 2 );
    }

    if ( !defined($h_part) ) {
        $h_part = "";
    }

    if ( !defined($t_part) ) {
        $t_part = $h_part;
        $h_part = "";
    }

    my @result   = ();
    my @h_tokens = split( /[^a-z]+/, $h_part );
    my @t_tokens = split( /[^a-z]+/, $t_part );
    my $h_count  = scalar(@h_tokens);
    my $t_count  = scalar(@t_tokens);

    my $temp = "";

    # case 1: Ou Yang, Fei Fei => FFOuYang
    $temp = "";
    for my $i ( 0 .. $t_count - 1 ) {
        $temp .= _capital( substr( $t_tokens[$i], 0, 1 ) );
    }
    for my $i ( 0 .. $h_count - 1 ) {
        $temp .= _capital( $h_tokens[$i] );
    }
    push( @result, $temp ) if ($temp);

    # case 1.1: Ou Yang, Fei Fei => FF.OuYang
    foreach my $c (qw(. - _)) {
        $temp = "";
        for my $i ( 0 .. $t_count - 1 ) {
            $temp .= _capital( substr( $t_tokens[$i], 0, 1 ) );
        }
        $temp .= $c;
        for my $i ( 0 .. $h_count - 1 ) {
            $temp .= _capital( $h_tokens[$i] );
        }
        push( @result, $temp ) if ($temp);
    }

    # case 2: Ou Yang, Fei Fei => OUYangFF
    $temp = "";
    for my $i ( 0 .. $h_count - 1 ) {
        $temp .= _capital( $h_tokens[$i] );
    }
    for my $i ( 0 .. $t_count - 1 ) {
        $temp .= _capital( substr( $t_tokens[$i], 0, 1 ) );
    }
    push( @result, $temp ) if ($temp);

    # case 2.1: Ou Yang, Fei Fei => OUYang.FF
    foreach my $c (qw(. - _)) {
        $temp = "";
        for my $i ( 0 .. $h_count - 1 ) {
            $temp .= _capital( $h_tokens[$i] );
        }
        $temp .= $c;
        for my $i ( 0 .. $t_count - 1 ) {
            $temp .= _capital( substr( $t_tokens[$i], 0, 1 ) );
        }
        push( @result, $temp ) if ($temp);
    }

    # case 3: Ou Yang, Fei Fei => FeiFei
    $temp = "";
    for my $i ( 0 .. $t_count - 1 ) {
        $temp .= _capital( $t_tokens[$i] );
    }
    push( @result, $temp ) if ($temp);

    # case 4: Ou Yang, Fei Fei => OuYangFeiFei
    $temp = "";
    for my $i ( 0 .. $t_count - 1 ) {
        $temp .= _capital( $t_tokens[$i] );
    }
    for my $i ( 0 .. $h_count - 1 ) {
        $temp .= _capital( $h_tokens[$i] );
    }
    push( @result, $temp ) if ($temp);

    # case 4.1: Ou Yang, Fei Fei => OuYang.FeiFei
    foreach my $c (qw(. - _)) {
        $temp = "";
        for my $i ( 0 .. $t_count - 1 ) {
            $temp .= _capital( $t_tokens[$i] );
        }
        $temp .= $c;
        for my $i ( 0 .. $h_count - 1 ) {
            $temp .= _capital( $h_tokens[$i] );
        }
        push( @result, $temp ) if ($temp);
    }

    # case 5: Ou Yang, Fei Fei => FeiFeiOuYang
    $temp = "";
    for my $i ( 0 .. $h_count - 1 ) {
        $temp .= _capital( $h_tokens[$i] );
    }
    for my $i ( 0 .. $t_count - 1 ) {
        $temp .= _capital( $t_tokens[$i] );
    }
    push( @result, $temp ) if ($temp);

    # case 5.1: Ou Yang, Fei Fei => FeiFei.OuYang
    foreach my $c (qw(. - _)) {
        $temp = "";
        for my $i ( 0 .. $h_count - 1 ) {
            $temp .= _capital( $h_tokens[$i] );
        }
        $temp .= $c;
        for my $i ( 0 .. $t_count - 1 ) {
            $temp .= _capital( $t_tokens[$i] );
        }
        push( @result, $temp ) if ($temp);
    }

    # case 6: Otherwise
    $temp = "";
    if ( $h_count == 0 ) {
        for my $i ( 0 .. $t_count - 2 ) {
            $temp .= _capital( substr( $t_tokens[$i], 0, 1 ) );
        }
        $temp .= $t_tokens[ $t_count - 1 ];
        push( @result, $temp ) if ($temp);
    }
    else {
        for my $i ( 0 .. $h_count - 2 ) {
            $temp .= _capital( substr( $h_tokens[$i], 0, 1 ) );
        }
        $temp .= $h_tokens[ $h_count - 1 ];
        push( @result, $temp ) if ($temp);
    }

    my %uniq = map { lc($_) => 1 } @result;
    @result = sort( keys(%uniq) );

    open( FH, ">/tmp/fs" );
    print FH join( "\n", @result );
    close(FH);

    return @result;
}

1;
