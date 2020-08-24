#use Grammar::Tracer;
use DateOrg;
use GtkTask;
use Data::Dump;

grammar Content {
    token TOP        { ^ <level> <todo>? <priority>? <header> <tags>? \n? <deadline>? <scheduled>? <properties>? <text> $ }
    token level      { "*"+ )> " "};
    token todo       { ["TODO"|"DONE"] )> " " }
    token priority   { "[#" <( [A|B|C] )> "] " }
    token header     { .*? <?before " :"\S || $$ > };   # TODO fail if "* blabla :e ",  
    token tags       {  " :"(\S+?":")+ }
    token deadline   { "DEADLINE: <" <dateorg> ">" \n? }
    token scheduled  { " "? "SCHEDULED: <" <dateorg> ">\n" }
    token properties { ^^ ":PROPERTIES:\n" (.*?\n) ":END:\n" }
    token text       { .* };
}
sub split-properties($properties) {
    $properties ~~ /":"(.*?)":"" "+(.*)\n/;
    return $0.Str,$1.Str;
}
class Content-actions {
    method TOP($/) {
        my GtkTask $task.=new(:header($<header>.made),:level($<level>.made));
        $task.todo       =$<todo>.made.Str if $<todo>;
        $task.priority   =$<priority>.made.Str if $<priority>;
        $task.tags       =split(/\:/,$<tags>.Str)[1..^*-1] if $<tags>;
        $task.deadline   =date-from-dateorg($<deadline>{'dateorg'}) if $<deadline>;
        $task.scheduled  =date-from-dateorg($<scheduled>{'dateorg'}) if $<scheduled>;
        $task.properties.push($<properties>.made) if $<properties>;
        $task.text       =$<text>.made if $<text> && $<text>.made.chars>0;
        make $task;
    }
    method header($/) {
        make $/.Str ;
    }
    method level($/) {
        make $/.Str.chars;
    }
    method todo($/) {
        make $/.Str;
    }
    method priority($/) {
        make $/.Str;
    }
    method tags($/) {
        make $/.Str;
    }
    method deadline($/) {
        make $/.Str;
    }
    method scheduled($/) {
        make $/.Str;
    }
    method properties($/) {
        make split-properties($0.Str);
    }
    method text($/) {
        make chomp($/.Str);   # TODO rewrite to accept one blank line after text
    }
}

my $level="";
grammar OrgMode {
    rule  TOP       { ^ <properties>? <preface>? <tasks> $ }
    token properties { ^^ ":PROPERTIES:\n" (.*?\n) ":END:" $$ }
#    rule  preface   {  ^^ <!after ^^"*"> .*  <?before ^^"*"> } 
#    rule  preface   {  [^"*"]+? <?before ^^"*"> } 
    rule  preface   {  .*? <?before ^^"*"> } 
    rule  tasks     {  <task>+ } 
    token task      { <content> <tasks>? {$level=$level.substr(0,*-1)}}
    rule  content   { ^^ 
                        ($level "*"+)" " {$level=$0} 
                        .*?  
                        <?before ^^"*" || $ >  
                    }   
}
sub analyse-content($content) {
        my $task=Content.parse($content,:actions(Content-actions)).made;
        return $task;
}
class OM-actions {
    method TOP($/) {
        my GtkTask $task.=new(:level(0));
        $task.properties.push($<properties>.made) if $<properties>;
        $task.text = $<preface>.made if $<preface> && $<preface>.made.chars>0;
        $task.tasks=$<tasks>.made if $<tasks>;
        $_.darth-vader=$task for $task.tasks;
        make $task;
    }
    method preface($/) {
        make chomp($/.Str);
    }
    method tasks($/) {
        make $<task>».made ;
     }
    method task($/) {
        my $task;
        $task=$<content>.made;
        $task.tasks=$<tasks>.made if $<tasks>.made;
        $_.darth-vader=$task for $task.tasks;
        make $task;
    }
    method content($/) {
        my $task = analyse-content($/.Str);
        make $task;
    }
    method properties($/) {
        make split-properties($0.Str);
    }
}