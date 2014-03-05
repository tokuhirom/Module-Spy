package Module::Spy;
use 5.008005;
use strict;
use warnings;
use Scalar::Util ();

our $VERSION = "0.01";

use parent qw(Exporter);

our @EXPORT = qw(spy);

sub spy {
    my ($stuff, $method) = @_;

    if (Scalar::Util::blessed($stuff)) {
        Module::Spy::Object->new($stuff, $method);
    } else {
        Module::Spy::Class->new($stuff, $method);
    }
}

package Module::Spy::Base;

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

package Module::Spy::Object;
our @ISA=('Module::Spy::Base');

my $SINGLETON_ID = 0;

sub new {
    my $class = shift;
    my ($stuff, $method) = @_;

    my $self = bless { stuff => $stuff, method => $method }, $class;

    my $orig = $self->stuff->can($self->method)
        or die "Missing $method";
    $self->{orig} = $orig;

    my $spy = Module::Spy::Sub->new($orig);
    $self->{spy} = $spy;

    {
        no strict 'refs';
        no warnings 'redefine';

        my $klass = "Module::Spy::Singleton" . $SINGLETON_ID++;
        unshift @{"${klass}::ISA"}, ref($stuff);
        *{"${klass}::${method}"} = $spy;
        bless $stuff, $klass; # rebless
    }

    return $self;
}

package Module::Spy::Class;
our @ISA=('Module::Spy::Base');

sub new {
    my $class = shift;
    my ($stuff, $method) = @_;

    my $self = bless { stuff => $stuff, method => $method }, $class;

    my $orig = $self->stuff->can($self->method)
        or die "Missing $method";
    $self->{orig} = $orig;

    my $spy = Module::Spy::Sub->new($orig);
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

package Module::Spy::Sub;
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

Module::Spy - Spy for Perl5

=head1 SYNOPSIS

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

=head1 DESCRIPTION

Module::Spy is spy library for Perl5.

=head1 FUNCTIONS

=over 4

=item C<< my $spy = spy($class|$object, $method) >>

Create new spy. Returns new Module::Spy::Class or Module::Spy::Object instance.

=back

=head1 Module::Spy::(Class|Object) methods

=over 4

=item C<< $spy->called() :Bool >>

Returns true value if the method was called. False otherwise.

=item C<< $spy->returns($value) : Module::Spy::Base >>

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

