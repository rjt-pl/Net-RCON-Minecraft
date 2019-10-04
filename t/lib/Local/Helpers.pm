#!perl

# Local::Helpers - Test framework shared code for Net::RCON::Minecraft

package Local::Helpers;

use 5.008;
use strict;
use warnings;
use Test::Exception;
use Test::More;
use Test::Output;
use Test::MockModule;
use Test::Warnings ':all';
use Carp;
use Data::Dump qw/pp dd/;
use List::Util qw/min max any/;
use IO::Socket 1.18;
use IO::Select;

use Exporter 'import';
our @EXPORT = qw(cmd cmd_full rcon_mock disp_add 
                 COMMAND AUTH AUTH_RESPONSE AUTH_FAIL RESPONSE_VALUE );

# Packet type constants as defined by:
# https://developer.valvesoftware.com/wiki/Source_RCON_Protocol#Packet_Type
use constant {
    COMMAND         => 2, # Command packet type
    AUTH            => 3, # Minecraft RCON login packet type
    AUTH_RESPONSE   => 2, # Server auth response
    AUTH_FAIL       =>-1, # Auth failure (password invalid)
    RESPONSE_VALUE  => 0, # Server response
};

# Dispatch table for default (but still mocked) methods
my %default_mock = (
    #shutdown is now done in rcon_mock() so it can drain the buffer
    connected    => sub { $_[0]->{_mock}{connected} },
    send         => \&mock_send,
    sysread      => \&mock_sysread,
    read_buf     => '', 
    _mock_push   => \&_mock_push,
    _disp_find   => \&_disp_find,
    _disp_dump   => \&_disp_dump,
);

sub rcon_mock {
    my %mocks = @_;
    
    # Eventually returned
    my $mock = {
        read_dispatch   => [ ],
        read_buf        => '',
        connected       => 0,
        smock           => Test::MockModule->new('IO::Select'),
        nmock           => Test::MockModule->new('IO::Socket::INET'),
    };

    # IO::Select Mock
    my %handles;
    my $smock  = Test::MockModule->new('IO::Select');
    my %smocks = (
        new      => sub { bless [undef,0], shift },
        remove   => sub { delete @handles{@_} },
        handles  => sub { keys %handles },
        add      => sub { $handles{$_[1]} = 1 },
        can_read => sub { 
            my ($s, $timeout) = @_;
            0 < length $mock->{read_buf};
        },
    );
    $smock->mock($_ => $smocks{$_}) for keys %smocks;

    # IO::Socket::NET Mock
    my $nmock = Test::MockModule->new('IO::Socket::INET');

    %mocks = ( 
        %default_mock,
        new => sub { 
            $mock->{connected} = 1;
            shift; bless { @_, _mock => $mock }, 'IO::Socket::INET'; 
        },
        %mocks 
    );

    disp_add($mock, '1:3:secret' => sub { [1, AUTH_RESPONSE, ''] });
    $nmock->mock($_ => $mocks{$_}) for keys %mocks;
    $nmock->mock(shutdown => sub {
        $_[0]->{_mock}{connected} = 0;
        $mock->{read_buf} = '';
    });


    $mock;
}

# Install an entry into the read_dispatch. See _disp_find for details.
sub disp_add {
    my ($_mock, $check, $respond, $priority) = @_;
    $priority = 1 if not defined $priority;
    push @{$_mock->{read_dispatch}}, [ $check, $respond ];

}

# Find an entry in the read_dispatch
sub _disp_find {
    my ($s, $id, $type, $payload) = @_;

    my %r; # Responses, by priority
    for (@{$s->{_mock}{read_dispatch}}) {
        my ($check, $resp, $pri) = @$_;
        $pri = 0 if not defined $pri;
        my %info; # Any potential info extracted from check phase
       
        # $check phase. Skip this iteration if not a match
        if ('CODE' eq ref $check) {
            %info = $check->($id, $type, $payload);
            next unless scalar keys %info;
        } 
        elsif ('Regexp' eq ref $check) {
            next unless "$id:$type:$payload" =~ /$check/;
            %info = %+;
        }
        elsif ('' eq ref $check) {
            next unless "$id:$type:$payload" eq $check;
        } else { 
            croak "Expecting CODE, Regexp or scalar, got " . ref $check 
        }

        # $resp can be either an array ref [ $id, $type, $payload ]
        # or a code ref that takes $id, $type, $payload, %info and 
        # returns an array ref [ $id, $type, $payload ]
        $r{$pri} = $resp->($id, $type, $payload, %info) if 'CODE' eq ref $resp;
        $r{$pri} = $resp if 'ARRAY' eq ref $resp;
    }

    # Croak if nothing found. (Install a default that always matches, if this
    # is undesirable).
    $s->_disp_dump("Don't know how to respond to <$id:$type:$payload>") unless %r;

    $r{ max keys %r }; # Highest priority response
}

# Dump the dispatch table (uses diag)
sub _disp_dump {
    my ($s, $err) = @_;

    diag "Dispatch table:";
    my $len = min 40, max map { length $_->[0] } @{$s->{_mock}{read_dispatch}};

    for (@{$s->{_mock}{read_dispatch}}) {
        my ($call, $resp) = @$_;
        $resp = 'sub { ... }' if 'CODE' eq ref $resp;
        diag sprintf("  %${len}s => %s", $call, $resp);
    }
    croak $err if $err;

}

# Mock send by looking at the packet received, pulling it apart, and
# barfing if it is malformed in any way. If it is OK, then we look at
# the read_dispatch table and put the appropriate response on the
# read_buf
sub mock_send {
    my ($s, $pkt) = @_;

    my ($size, $id, $type, $text) = _decode_packet($pkt);

    $s->_mock_push(@{$s->_disp_find($id, $type, $text)});

    return 1;
}

# Push a response onto the receive buffer. Normally called by mock_send.
# This will be put into the appropriate RCON packet format automatically
# **and will be fragmented if the payload length exceeds 4096.** Submit
# payloads of 4095 bytes or less to avoid fragmentation.
sub _mock_push {
    my ($s, $id, $type, $payload) = @_;

    if (length $payload > 4096) {
        $s->_mock_push($id, $type, substr($payload, 0, 4096));
        $s->_mock_push($id, $type, substr($payload, 4096));
        return;
    }

    my $pkt = pack('V!V' => $id, $type) . $payload . "\0\0";
    my ($len_pack) = (pack V => length($pkt));
    croak "len_pack <$len_pack> is not a valid length" unless 4 == length $len_pack;
    $s->{_mock}{read_buf} .= $len_pack . $pkt;

}

# Mock read by pulling from the read_buf created by mock_send.
# Basic error handling if we are not connected or the buf
# is empty. (Instead of blocking, we croak()) 
sub mock_sysread { 
    my ($s, undef, $len) = @_;

    confess "Buffer not defined" if not exists $s->{_mock}{read_buf};
    #croak "sysread() would block forever" if $len > length $s->{_mock}{read_buf};
    $len = min $len, length $s->{_mock}{read_buf};

    my $buf  = substr $s->{_mock}{read_buf}, 0, $len;
    my $rest = substr $s->{_mock}{read_buf}, $len;
    $s->{_mock}{read_buf} = $rest;

    $_[1] = $buf;

}

# Decode a packet
sub _decode_packet {
    my ($pkt) = @_;
    die 'Short packet received.' if length $pkt < 12;

    my ($size, $id, $type, $text) = unpack 'VV!Va*' => $pkt;
    die '[Mock] Received packet missing terminator' if $text !~ s/\0\0$//;

    ($size, $id, $type, $text);
}

# Return command response from server, with full control of response.
# e.g.: cmd('help', [ '2:2:help' => [2, RESPONSE_VALUE, 'help!' ]])
sub cmd_full($@) {
    my $cmd = shift;
    my $mock = rcon_mock();
    my $rcon = Net::RCON::Minecraft->new(password => 'secret');
    disp_add($mock, @$_) for @_;
    disp_add($mock, qr/(?<id>\d+):(?<nonce>\d+):nonce/ => sub {
        my ($id, $type, $payload, %p) = @_; 
        [ $p{id}, RESPONSE_VALUE, sprintf("Unknown request %x", $p{nonce}) ]
    });

    #ok $rcon->connect, 'Connects before ' . $cmd;
    
    local $Carp::CarpLevel = 2;
    my $res = $rcon->command($cmd);

    is ref($res), 'Net::RCON::Minecraft::Response';

    $res->plain;
}

# Short form for most common case of simply having a command return a 
# specific response
sub cmd($$) {
    my ($cmd, $resp) = @_;

    cmd_full($cmd, [ "2:2:$cmd" => [2, RESPONSE_VALUE, $resp ] ] );
}

1;
