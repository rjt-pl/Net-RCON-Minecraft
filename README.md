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
    
    my $rcon = Net::RCON::Minecraft->new(     host => 'mc.example.com', 
                                          password => 'secret' );
    
    eval { $rcon->connect } or die "Connection failed: $@";
    
    my $response = eval { $rcon->command('kill @a') };
    if ($@) {
        warn "Command failed: $@";
    } else {
        say "Command response: " . $response->ansi;
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

# WORK IN PROGRESS

## Todo

 - [ ] Unit tests for `bin/rcon-minecraft`
 - [ ] `bin/rcon-minecraft` goes straight to prompt now that we don't connect.
       Should we have a password prompt?
 - [ ] [Term::ReadLine::Zoid](https://metacpan.org/pod/Term::ReadLine::Zoid)
       might be an expensive prerequisite. Check deps, and maybe make it
       an optional include, or rethink the need for interactivity.
 - [ ] A lot more integration testing needs to be done.
 - [ ] Consider adding live network tests if $ENV{RCON} = "host:port:password"
 - [ ] IPv6 testing

# Support

 - [RT, CPAN's request tracker](https://rt.cpan.org/NoAuth/Bugs.html?Queue=Net-RCON-Minecraft): Please report bugs here.
 - [GitHub Repository](https://github.com/rjt-pl/Net-RCON-Minecraft)

# License and Copyright

Copyright (C) Ryan J Thompson <<rjt@cpan.org>>

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

[Perl Artistic License](http://dev.perl.org/licenses/artistic.html)
