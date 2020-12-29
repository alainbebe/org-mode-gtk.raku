use v6;
use lib “lib”;
use OrgMode::Grammar;

use Test;
plan 55; # TODO write other type of test, writing,... :0.x:

my $file = 
"* title";
ok OrgMode.parse($file), 'parses';
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].stars   == 1         , "stars 1";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].title  eq "title"  , "title 1";

$file = 
"* title
** sub-title";
ok OrgMode.parse($file), 'parses';
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].stars             == 1           , "stars 1";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].title            eq "title"    , "title 1";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].tasks[0].stars    == 2           , "stars 2";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].tasks[0].title   eq "sub-title", "sub-title";

$file = 
"* title
* title 2
* title 3";
ok OrgMode.parse($file), 'parses';
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].stars    == 1           , "stars 1";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].title   eq "title"    , "title 1";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[1].stars    == 1           , "stars 1";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[1].title   eq "title 2"  , "title 2";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[2].stars    == 1           , "stars 1";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[2].title   eq "title 3"  , "title 3";

$file = 
"* title
** sub-title
* title 2";
ok OrgMode.parse($file), 'parses';
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].stars             == 1           , "stars 1";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].title            eq "title"    , "title 1";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].tasks[0].stars    == 2           , "stars 2";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].tasks[0].title   eq "sub-title", "sub-title";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[1].stars             == 1           , "stars 1";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[1].title            eq "title 2"  , "title 2";

$file = 
"* TODO [#B] title :tag1:tag2:";
ok OrgMode.parse($file), 'parses';
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].keyword     eq "TODO"    , "TODO";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].priority eq "B"       , "B";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].stars    == 1         , "stars 1";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].title   eq "title"  , "title";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].tags[0]  eq "tag1"    , "tag1";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].tags[1]  eq "tag2"    , "tag2";

$file = 
"* TODO [#B] Space before tag         :tag1:";
ok OrgMode.parse($file), 'parses';
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].title   eq "Space before tag"  , "Space before tag";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].tags[0]  eq "tag1"    , "tag1";

$file = 
"* title

little text with blank line";
ok OrgMode.parse($file), 'parses';
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].text             eq "\nlittle text with blank line"    , "little text with blank line";

$file = 
"* title
CLOSED: [2020-05-09 Sat]
little text";
ok OrgMode.parse($file), 'parses';
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].closed.str     eq "2020-05-09 Sat" , "closed";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].text           eq "little text"    , "little text";

$file = 
"* title
DEADLINE: <2020-05-09 Sat>
little text";
ok OrgMode.parse($file), 'parses';
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].deadline.str     eq "2020-05-09 Sat" , "deadline";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].text             eq "little text"    , "little text";

$file = 
"* title
  DEADLINE: <2020-05-09 Sat>
little text";
ok OrgMode.parse($file), 'parses';
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].deadline.str     eq "2020-05-09 Sat" , "deadline";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].text             eq "little text"    , "little text";

$file = 
"* title
CLOSED: [2020-05-09 Sat] DEADLINE: <2020-05-09 Sat> SCHEDULED: <2020-05-09 Sat>
:PROPERTIES:
:color:    red
:END:
little text";
ok OrgMode.parse($file), 'parses';
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].closed.str       eq "2020-05-09 Sat" , "closed";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].deadline.str     eq "2020-05-09 Sat" , "deadline";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].scheduled.str    eq "2020-05-09 Sat" , "scheduled";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].properties[0][0] eq "color"          , "color";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].properties[0][1] eq "red"            , "red";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].text             eq "little text"    , "little text";

$file = 
"* title
:PROPERTIES:
:just_key:
:END:";
ok OrgMode.parse($file), 'parses';
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].properties[0][0] eq "just_key"          , "just_key";
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].properties[0][1] eq ""                  , "no value";

$file = 
"* title
 space before little text";
ok OrgMode.parse($file), 'parses';
ok OrgMode.parse($file,:actions(OrgMode::Actions)).made.tasks[0].text             eq " space before little text"    , " space before text ";
