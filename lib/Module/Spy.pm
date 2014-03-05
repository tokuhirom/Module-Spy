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

sub call_through {
    my $self = shift;
    $self->{spy}->call_through;
    return $self;
}

sub call_fake {
    my ($self, $code) = @_;
    $self->{spy}->call_fake($code);
    return $self;
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

    $self->{orig_class} = ref($stuff);

    {
        no strict 'refs';
        no warnings 'redefine';

        $SINGLETON_ID++;
        my $klass = "Module::Spy::Singleton::" . $SINGLETON_ID;
        $self->{id} = $SINGLETON_ID;
        $self->{anon_class} = $klass;
        $self->{isa} = do { \@{"${klass}::ISA"} };
        unshift @{$self->{isa}}, ref($stuff);
        *{"${klass}::${method}"} = $spy;
        bless $stuff, $klass; # rebless
    }

    return $self;
}

sub get_stash {
    my $klass = shift;

    my $pack = *main::;
    foreach my $part (split /::/, $klass){
        return undef unless $pack = $pack->{$part . '::'};
    }
    return *{$pack}{HASH};
}

sub DESTROY {
    my $self = shift;

    # Restore the object's type.
    if (ref($self->stuff) eq $self->{anon_class}) {
        bless $self->stuff, $self->{orig_class};
    }

    @{$self->{isa}} = ();

    my $original_stash = get_stash("Module::Spy::Singleton");
    my $sclass_stashgv = delete $original_stash->{$self->{id} . '::'};
    %{$sclass_stashgv} = ();

    undef $self->{spy};
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

    undef $self->{spy};
}

package Module::Spy::Sub;
use Scalar::Util qw(refaddr);

# inside-out
our %COUNTER;
our %RETURNS;
our %CALL_THROUGH;
our %CALL_FAKE;

sub new {
    my ($class, $orig) = @_;

    my $body;
    my $code = sub { goto $body };

    my $code_addr = refaddr($code);
    $body = sub {
        $COUNTER{$code_addr}++;

        if (my $fake = $CALL_FAKE{$code_addr}) {
            goto $fake;
        }

        if (exists $RETURNS{$code_addr}) {
            return $RETURNS{$code_addr};
        }

        if ($CALL_THROUGH{$code_addr}) {
            goto $orig;
        }

        return;
    };

    my $self = bless $code, $class;
    return $self;
}

sub DESTROY {
    my $self = shift;
    my $code_addr = refaddr($self);

    delete $COUNTER{$code_addr};
    delete $RETURNS{$code_addr};
    delete $CALL_FAKE{$code_addr};
    delete $CALL_THROUGH{$code_addr};
}

sub called {
    my $self = shift;
    !!$COUNTER{refaddr($self)};
}

sub returns {
    my ($self, $value) = @_;
    $RETURNS{refaddr($self)} = $value;
}

sub call_through {
    my $self = shift;
    $CALL_THROUGH{refaddr($self)}++;
}

sub call_fake {
    my ($self, $code) = @_;
    $CALL_FAKE{refaddr($self)} = $code;
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

=head1 STABILITY

B<This module is under development. I will change API without notice.>

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

