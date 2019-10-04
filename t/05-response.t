#!perl
use 5.008;
use strict;
use warnings FATAL => 'all';
use lib 't/lib';
use Test::Exception;
use Test::More;
use Test::Exception;
use Local::Helpers;

use Net::RCON::Minecraft::Response;

# Arrays to test strip, convert, and ignore color modes, respectively.
# Left side is input string, right is expected output.
# 3rd argument is an optional description. Otherwise, stripped 2nd is used.
my %tests = (
    "Plain string"                 => {
        plain => 'Plain string',
        ansi  => "Plain string\e[0m",
    },
    "Color \x{00a7}4middle"        => {
        plain => 'Color middle',
        ansi  => "Color \e[31mmiddle\e[0m",
    },
    "\x{00a7}3Color start"         => {
        plain => 'Color start',
        ansi  => "\e[36mColor start\e[0m",
    },
    "Color end\x{00a7}5"           => {
        plain => 'Color end',
        ansi  => "Color end\e[35m\e[0m",
    },
    "\x{00a7}3\x{00a7}4"           => {
        plain => '',
        ansi  => "\e[36m\e[31m\e[0m",
    },
    "\x{00a7}3Two \x{00a7}4colors" => {
        plain => 'Two colors',
        ansi  => "\e[36mTwo \e[31mcolors\e[0m",
    },
    "\x{00a7}aBright \x{00a7}2dark \x{00a7}abright" => {
        plain => 'Bright dark bright',
        ansi  => "\e[92mBright \e[32mdark \e[92mbright\e[0m",
    },
);

for (sort keys %tests) {
    my $res = Net::RCON::Minecraft::Response->new(raw => $_);
    is $res->raw,          $_,          'Raw matches';
    is $res->ansi,  $tests{$_}{ansi},   'ANSI is correct';
    is $res->plain, $tests{$_}{plain},  'Plain is correct';
}

done_testing;
