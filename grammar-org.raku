#!/usr/bin/env perl6

use v6;
use Data::Dump;
use Grammar::Tracer;

my $level;
grammar OrgMode {
    rule  TOP       { ^ <tasks> $ }
    rule  tasks     {  <task>+ } 
    token task      { <content> <tasks>? {$level=$level.substr(0,*-1)}}
    token content   { ^^ ($level "*"+)" " {$level=$0} 
                        <todo>?
                        <priority>?
                        <header>
                    }   
    token header    { .+? <dp-tags>? <text>  <?before ^^"*" || $ > }
    token todo      { ["TODO"|"DONE"]" " }
    token priority  { "[#" (A || B || C) "] " }
    token dp-tags   { " :" <tag>+ } # match mais pas optimal, de plus je ne récupère pas les valeurs
    token tag       { .*?":" }
    token text      { \n.+? }
}

class OM-actions {
    method TOP($/) {
        make $<tasks>.made;
    }
    method tasks($/) {
        make $<task>».made ;
    }
    method task($/) {
        my %task;
        %task=$<content>.made;
        %task{"sub-task"}=$<tasks>.made if $<tasks>.made;
        make %task;
    }
    method content($/) {
        my %task;
        %task=$<header>.made;  # il y a tjs un header
say "tsak ",%task;
        %task{"todo"}    =$<todo>.made     if $<todo>.made;
        %task{"priority"}=$<priority>.made if $<priority>.made;
        make %task;
    }
    method header($/) {
        my %task;
        %task{"header"}  = $/.Str;
    say "dp ts",$<dp-tags>».made ;
        %task{"tags"}  = $<dp-tags>.made if $<dp-tags>.made ;
        make %task;
    }
    method todo($/) {
        make $/.Str;
    }
    method priority($/) {
        make $0.Str;
    }
    method dp-tags($/) {
        say "dp ",$<tag>».made ;
        say "dp ",$<tag>».made.Str ;
        make "ici"; #$<tag>».made.Str;
    }
    method tag($/) {
        say chop($/.Str);
        make chop($/.Str);
    }
    method text($/) {
        say $/.Str;
        make $/.Str;
    }
}

my $file =
"* juste un header 1 

* juste deux header 1 
* header 2 

* juste 3 header 1 
* header 2 
* header 3 

* juste un header 1 et un sub 
** sub-header 1 

* juste un header 1 et deux sub * 
** sub-header 1 
** sub-header 2

* juste un header 1 et un sub et un sub-sub 
** sub-header 1 
*** sub-sub-header 1 

* 2 header 1 et un sub au milieu 
** sub-header 1 
* header 2 

* 2 header 1 et un sub chacun 
** sub-header 1 
* header 2 
** sub-header 2

* 2 header 1 et un sub sub 
** sub-header 1 
*** sub sub-header 1 
** sub header 1.2
*** sub sub-header 1 
* header 2 
** sub-header 2"
;

$file =
"* DONE juste un header 1

* TODO header 1

* header 1

* [#B] header 1

* [#B] header 1 :assai:essai:
texte"
;
 
say "\n" x 10;
sub parse_file($file) {
    say $file;
    say "";
    $level="";
#    say OrgMode.parse($file);
    say Dump OrgMode.parse($file,:actions(OM-actions)).made;
    say "---------------------------------------------------------------------------------------";
}

parse_file($_) for split("\n\n",$file);
