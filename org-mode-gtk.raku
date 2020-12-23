#!/usr/bin/env perl6

use v6;
use lib "lib";
use Gtk::Main;

my Gtk::Main $m .= new;

sub MAIN ($arg = '') {
    $m.show($arg);
}
