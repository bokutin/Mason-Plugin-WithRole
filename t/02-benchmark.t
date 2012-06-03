use strict;
use Test::More;

use lib "lib";

use Benchmark qw(:all);
use Mason;

my $interp1 = Mason->new(
    comp_root => "t/comp",
    plugins => [
        #"WithRole",
    ],
);

my $interp2 = Mason->new(
    comp_root => "t/comp",
    plugins => [
        "WithRole",
    ],
);

$interp1->run("/method100")->output;
$interp2->run("/method100")->output;

my $count = 1;
my $t1 = countit($count, sub {
    $interp1->run("/method100")->output;
});
#diag timestr($t1);
my $t2 = countit($count, sub {
    $interp2->run("/method100")->output;
});
#diag timestr($t2);

#use Data::Dumper;
#warn Dumper [$t1,$t2];
my $n1 = $t1->[5];
my $n2 = $t2->[5];
ok( $n1*0.8 < $n2 and $n2 < $n1*1.2 ? 1 : 0, sprintf("%f < %f < %f", $n1*0.8, $n2, $n1*1.2));

done_testing();
