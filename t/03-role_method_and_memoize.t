use strict;
use Test::More;

use lib "lib";

use Benchmark qw(:all);
use Mason;

my $interp1 = Mason->new(
    comp_root => "t/comp",
    plugins => [
        "WithRole",
    ],
);

my $interp2 = Mason->new(
    comp_root => "t/comp",
    plugins => [
        #"WithRole",
    ],
);

my $interp3 = Mason->new(
    comp_root => "t/comp",
    plugins => [
        "WithRole",
    ],
);

ok( $interp1->can('load') != $interp2->can('load') );
ok( $interp1->can('load') == $interp3->can('load') );

done_testing();
