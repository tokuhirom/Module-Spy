use strict;
use warnings;
use utf8;
use Test::More;
use Module::Spy;
use Scalar::Util qw(refaddr);

{
    package X;
    sub new { bless {}, shift }
    sub y { 'yyy' }
}

subtest 'Spy class method', sub {
    subtest 'Not called yet', sub {
        # Given set spy
        my $spy = spy('X', 'y');

        # Then, it's not called
        ok !$spy->called;
    };

    subtest 'Called', sub {
        # Given set spy
        my $spy = spy('X', 'y');

        # When call the method
        X->y;

        # Then, it's called.
        ok $spy->called;
    };

    subtest 'Restored', sub {
        {
            # Given set spy
            my $spy = spy('X', 'y');
        }

        # When it's out-scoped

        # Then, it's restored
        is ref(X->can('y')), 'CODE';
    };

    subtest 'Stub-out by value', sub {
        # Given set spy
        my $spy = spy('X', 'y');

        # When set return value as 3
        is refaddr($spy->returns(3)), refaddr($spy);

        # Then return value is 3
        is(X->y, 3);
    };
};

subtest 'Spy instance method', sub {
    subtest 'Not called yet', sub {
        # Given object
        my $obj = X->new;

        # Given set spy
        my $spy = spy($obj, 'y');

        # Then, it's not called
        ok !$spy->called;
    };

    subtest 'Called', sub {
        # Given object
        my $obj = X->new;

        # Given set spy
        my $spy = spy($obj, 'y');

        # When call the method
        is $obj->y, 'yyy';

        # Then, it's called.
        ok $spy->called;
    };

    subtest "It's not affected for another object", sub {
        # Given object
        my $obj = X->new;

        # Given another object
        my $another_obj = X->new;

        # Given set spy
        my $spy = spy($obj, 'y');

        # Then, $obj was spyed
        is ref($obj->can('y')), 'Module::Spy::Sub';

        # Then, but $another_obj was *not* spyed
        is ref($another_obj->can('y')), 'CODE';
    };
};

done_testing;

