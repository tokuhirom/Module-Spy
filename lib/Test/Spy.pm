package Test::Spy;
use 5.008005;
use strict;
use warnings;
use Scalar::Util ();
use Class::Monadic;

our $VERSION = "0.01";

use parent qw(Exporter);

our @EXPORT = qw(spy);

sub spy {
    my ($stuff, $method) = @_;

    if (Scalar::Util::blessed($stuff)) {
        Test::Spy::Object->new($stuff, $method);
    } else {
        Test::Spy::Class->new($stuff, $method);
    }
}

package Test::Spy::Base;

sub stuff { shift->{stuff} }
sub method { shift->{method} }

sub called {
    my $self = shift;
    $self->{spy}->called;
}

sub returns {
    my $self = shift;
    $self->{spy}->returns(@_);
    return $self;
}

package Test::Spy::Object;
our @ISA=('Test::Spy::Base');

my $SINGLETON_ID = 0;

sub new {
    my $class = shift;
    my ($stuff, $method) = @_;

    my $self = bless { stuff => $stuff, method => $method }, $class;

    my $orig = $self->stuff->can($self->method)
        or die "Missing $method";
    $self->{orig} = $orig;

    my $spy = Test::Spy::Sub->new($orig);
    $self->{spy} = $spy;

    {
        no strict 'refs';
        no warnings 'redefine';

        my $klass = "Test::Spy::Singleton" . $SINGLETON_ID++;
        unshift @{"${klass}::ISA"}, ref($stuff);
        *{"${klass}::${method}"} = $spy;
        bless $stuff, $klass; # rebless
    }

    return $self;
}

package Test::Spy::Class;
our @ISA=('Test::Spy::Base');

sub new {
    my $class = shift;
    my ($stuff, $method) = @_;

    my $self = bless { stuff => $stuff, method => $method }, $class;

    my $orig = $self->stuff->can($self->method)
        or die "Missing $method";
    $self->{orig} = $orig;

    my $spy = Test::Spy::Sub->new($orig);
    $self->{spy} = $spy;

    {
        no strict 'refs';
        no warnings 'redefine';
        *{$self->stuff . '::' . $self->method} = $spy;
    }

    return $self;
}

sub DESTROY {
    my $self = shift;
    my $stuff = $self->{stuff};
    my $method = $self->{method};
    my $orig = $self->{orig};

    no strict 'refs';
    no warnings 'redefine';
    *{"${stuff}::${method}"} = $orig;
}

package Test::Spy::Sub;
use Scalar::Util qw(refaddr);

# inside-out
our %COUNTER;
our %RETURNS;

sub new {
    my ($class, $orig) = @_;

    my $body;

    my $code = sub { goto $body };
    $body = sub {
        $COUNTER{refaddr($code)}++;

        if (exists $RETURNS{refaddr($code)}) {
            return $RETURNS{refaddr($code)};
        }

        goto $orig;
    };

    my $self = bless $code, $class;
    return $self;
}

sub called {
    my $self = shift;
    !!$COUNTER{refaddr($self)};
}

sub returns {
    my ($self, $value) = @_;
    $RETURNS{refaddr($self)} = $value;
}

1;
__END__

=encoding utf-8

=head1 NAME

Test::Spy - Spy for Perl5

=head1 SYNOPSIS

Spy for class method.

    use Test::Spy;

    my $spy = spy('LWP::UserAgent', 'request');
    $spy->returns(HTTP::Response->new(200));

    my $res = LWP::UserAgent->new()->get('http://mixi.jp/');

Spy for object method

    use Test::Spy;

    my $ua = LWP::UserAgent->new();
    my $spy = spy($ua, 'request')->returns(HTTP::Response->new(200));

    my $res = $ua->get('http://mixi.jp/');

    ok $spy->called;

=head1 DESCRIPTION

Test::Spy is spy library for Perl5.

=head1 FUNCTIONS

=over 4

=item C<< my $spy = spy($class|$object, $method) >>

Create new spy. Returns new Test::Spy::Class or Test::Spy::Object instance.

=back

=head1 Test::Spy::(Class|Object) methods

=over 4

=item C<< $spy->called() :Bool >>

Returns true value if the method was called. False otherwise.

=item C<< $spy->returns($value) : Test::Spy::Base >>

Stub the method's return value as C<$value>.

Returns C<<$spy>> itself for method chaining.

=back

=head1 LICENSE

Copyright (C) Tokuhiro Matsuno.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom@gmail.comE<gt>

=cut

