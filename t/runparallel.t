#!/usr/bin/perl ## no critic (RequireVersionVar)
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../src";

use Test::More;

use_ok( 'runparallel', 'module load' );

use runparallel;

is( 1, 1, 'one is one' );

done_testing();    # reached the end safely
