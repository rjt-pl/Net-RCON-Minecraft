# About Net::RCON::Minecraft

`Net::RCON::Minecraft` is a Minecraft-specific implementation of the RCON
protocol, used to automate sending commands and receiving responses from a
Minecraft server.

With a properly configured server, you can use this module to automate many
tasks, and extend the functionality of your server without the need to mod
the server itself.

# Synopsis

```perl
    use Net::RCON::Minecraft;

    my $rcon = Net::RCON::Minecraft->new(password => 'secret',
                                             host => 'mc.example.com');

    eval { $rcon->connect } or die "Connection failed: $@";

    my $response = eval { $rcon->command('kill @a') };
    if ($@) {
        warn "Command failed: $@";
    } else {
        say "Command response: " . $response->ansi;
        say "  Plain response: " . $response; # or $response->plain
    }
```

# Documentation

Once this module is installed, full documentation is available via `perldoc
Net::RCON::Minecraft` on your local system. Documentation for all public
releases is also available on
[MetaCPAN](https://metacpan.org/pod/Net::RCON::Minecraft)

# Installation

If you simply want the latest public release, install via CPAN.

If you need to build and install from this distribution directory itself,
run the following commands:

```sh
    perl Makefile.PL
    make
    make test
    make install
```

You may need to follow your system's usual build instructions if that doesn't
work. For example, Windows users will probably want to use `gmake` instead of
`make`. Otherwise, the instructions are the same.

# WORK IN PROGRESS

## Todo

 - [ ] Unit tests for `bin/rcon-minecraft`
 - [ ] A lot more integration testing needs to be done.

# Support

 - [RT, CPAN's request tracker](https://rt.cpan.org/NoAuth/Bugs.html?Queue=Net-RCON-Minecraft): Please report bugs here.
 - [GitHub Repository](https://github.com/rjt-pl/Net-RCON-Minecraft)

# License and Copyright

Copyright (C) Ryan J Thompson <<rjt@cpan.org>>

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

[Perl Artistic License](http://dev.perl.org/licenses/artistic.html)
