use v6;
use lib “lib”;
use GramOrgMode;

use Test;
plan 42;

my $file = 
"* header";
ok OrgMode.parse($file), 'parses';
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].level   == 1         , "level 1";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].header  eq "header"  , "header 1";

$file = 
"* header
** sub-header";
ok OrgMode.parse($file), 'parses';
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].level             == 1           , "level 1";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].header            eq "header"    , "header 1";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].tasks[0].level    == 2           , "level 2";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].tasks[0].header   eq "sub-header", "sub-header";

$file = 
"* header
* header 2
* header 3";
ok OrgMode.parse($file), 'parses';
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].level    == 1           , "level 1";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].header   eq "header"    , "header 1";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[1].level    == 1           , "level 1";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[1].header   eq "header 2"  , "header 2";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[2].level    == 1           , "level 1";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[2].header   eq "header 3"  , "header 3";

$file = 
"* header
** sub-header
* header 2";
ok OrgMode.parse($file), 'parses';
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].level             == 1           , "level 1";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].header            eq "header"    , "header 1";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].tasks[0].level    == 2           , "level 2";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].tasks[0].header   eq "sub-header", "sub-header";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[1].level             == 1           , "level 1";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[1].header            eq "header 2"  , "header 2";

$file = 
"* TODO [#B] header :tag1:tag2:";
ok OrgMode.parse($file), 'parses';
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].todo     eq "TODO"    , "TODO";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].priority eq "B"       , "B";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].level    == 1         , "level 1";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].header   eq "header"  , "header 1";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].tags[0]  eq "tag1"    , "tag1";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].tags[1]  eq "tag2"    , "tag2";

$file = 
"* header

little text with blank line";
ok OrgMode.parse($file), 'parses';
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].text             eq "\nlittle text with blank line"    , "little text with blank line";

$file = 
"* header
DEADLINE: <2020-05-09 Sat>
little text";
ok OrgMode.parse($file), 'parses';
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].deadline.str     eq "2020-05-09 Sat" , "deadline";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].text             eq "little text"    , "little text";

$file = 
"* header
DEADLINE: <2020-05-09 Sat> SCHEDULED: <2020-05-09 Sat>
:PROPERTIES:
:color:    red
:END:
little text";
ok OrgMode.parse($file), 'parses';
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].properties[0][0] eq "color"          , "color";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].properties[0][1] eq "red"            , "red";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].deadline.str     eq "2020-05-09 Sat" , "deadline";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].scheduled.str    eq "2020-05-09 Sat" , "scheduled";
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].text             eq "little text"    , "little text";

$file = 
"* header
 space before little text";
ok OrgMode.parse($file), 'parses';
ok OrgMode.parse($file,:actions(OM-actions)).made.tasks[0].text             eq " space before little text"    , " space before text ";
