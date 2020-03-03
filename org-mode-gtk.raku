#!/usr/bin/env perl6

use v6;
use GTK::Simple;
use GTK::Simple::App;
use Data::Dump;

#-----------------------------------Grammar---------------------------

grammar ORG_MODE {
    rule  TOP     { ^ <tasks> $ }
    rule  tasks  { <task>+ %% "\n" }
    token task   { <level><todo><content> }
    token level  { \*" " }
    token todo  { ["TODO " | "DONE "]? }
    token content { <-[\n]>+ }
}

class OM-actions {
    method TOP($/) {
        make $<tasks>.made;
    }
    method tasks($/) {
        make $<task>».made;
    }
    method task($/) {
        make  $<content>.made =>  $<todo>.made 
    }
    method todo($/) {
        make { "TODOACT" => ~$/.Str.substr(0,4) } if $/.Str;
        make { "TODOACT" => "" } if !$/.Str;
    }
    method content($/) {
        make $/.Str;
    }
}

#---------------------------sub--------------------------------

my @tasks;
my $vb_tasks;

sub click_todo ($b_todo,$l_todo) {
	$b_todo.clicked.tap({ 
        given $l_todo.text {
            when "TODO" {$l_todo.text="DONE"}
            when "DONE" {$l_todo.text=""}
            default     {$l_todo.text="TODO"}
        }
	})
}
sub click_delete ($b_label,$b_master) {
	$b_label.clicked.tap({ 
		@tasks=grep { $_ !~~ /$b_master/ },@tasks;
		$b_master.destroy;
	})
}
sub create_task(%task) {
	my $b_task_label = GTK::Simple::Button.new(label => %task.key);
	my $b_task_todo = GTK::Simple::Button.new(label => "Change todo");
	my $l_task_todo = GTK::Simple::Label.new(text => %task.value{"TODOACT"});
	my $b_task = GTK::Simple::VBox.new($b_task_label,$l_task_todo,$b_task_todo);
	@tasks.push($b_task);
	click_delete($b_task_label,$b_task);
	click_todo($b_task_todo,$l_task_todo);
	$vb_tasks.pack-start($b_task);
}

sub create_task2($task,$todo) {
	my $b_task_label = GTK::Simple::Button.new(label => $task);
	my $b_task_todo = GTK::Simple::Button.new(label => "Change todo");
	my $l_task_todo = GTK::Simple::Label.new(text => $todo);
	my $b_task = GTK::Simple::VBox.new($b_task_label,$l_task_todo,$b_task_todo);
	@tasks.push($b_task);
	click_delete($b_task_label,$b_task);
	click_todo($b_task_todo,$l_task_todo);
	$vb_tasks.pack-start($b_task);
}

#--------------------------main--------------------------------

my $file = slurp "todo.org";
spurt "todo.bak",$file;

my $om-actions = OM-actions.new();
#say ORG_MODE.parse($file);exit;                           # just for test the tree
my $match = ORG_MODE.parse($file, :actions($om-actions));
#say $match.made;say Dump $match.made.hash;exit;           # just for test AST

my $app = GTK::Simple::App.new( title => "Org-mode with GTK and Raku" );
$app.set-content(
    my $gtk = GTK::Simple::HBox.new(
        my $gtk1 = GTK::Simple::VBox.new(
            my $new = GTK::Simple::Entry.new,
            my $add       = GTK::Simple::Button.new(label => "Add"),
            my $save_quit = GTK::Simple::Button.new(label => "Save & Quit"),
            my $quit      = GTK::Simple::Button.new(label => "Quit (don't save)"),
        ),
        my $gtk2 = GTK::Simple::VBox.new(
            $vb_tasks    = GTK::Simple::VBox.new(),            # populate after
        )
    )
);
create_task($_) for $match.made.hash;

# to merge with create_task but i have problem with hash
# I have "{essai => {TODOACT => TODO}}" and not "essai => {TODOACT => TODO}"
$add.clicked.tap({ 
	create_task2($new.text , "" ) if $new.text;
});

$save_quit.clicked.tap({
	spurt "todo1.org", (map { "* "~$_.label }, @tasks).join("\n");
	$app.exit; 
});

$quit.clicked.tap({
	$app.exit;
});

$app.run;
