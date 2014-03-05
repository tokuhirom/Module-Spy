[![Build Status](https://travis-ci.org/tokuhirom/Test-Spy.png?branch=master)](https://travis-ci.org/tokuhirom/Test-Spy)
# NAME

Module::Spy - Spy for Perl5

# SYNOPSIS

Spy for class method.

    use Module::Spy;

    my $spy = spy('LWP::UserAgent', 'request');
    $spy->returns(HTTP::Response->new(200));

    my $res = LWP::UserAgent->new()->get('http://mixi.jp/');

Spy for object method

    use Module::Spy;

    my $ua = LWP::UserAgent->new();
    my $spy = spy($ua, 'request')->returns(HTTP::Response->new(200));

    my $res = $ua->get('http://mixi.jp/');

    ok $spy->called;

# DESCRIPTION

Module::Spy is spy library for Perl5.

# FUNCTIONS

- `my $spy = spy($class|$object, $method)`

    Create new spy. Returns new Module::Spy::Class or Module::Spy::Object instance.

# Module::Spy::(Class|Object) methods

- `$spy->called() :Bool`

    Returns true value if the method was called. False otherwise.

- `$spy->returns($value) : Module::Spy::Base`

    Stub the method's return value as `$value`.

    Returns `<$spy`\> itself for method chaining.

# LICENSE

Copyright (C) Tokuhiro Matsuno.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Tokuhiro Matsuno <tokuhirom@gmail.com>
