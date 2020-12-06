#!/usr/bin/env perl6

use v6;
use lib "lib";
use Main;

my Main $m .= new;
$m.main();

sub MAIN ($arg = '') {
    $m.show($arg);
}
