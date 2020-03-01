#!/usr/bin/env perl6

use v6;
use GTK::Simple;
use GTK::Simple::App;

#-----------------------------------Grammar---------------------------

grammar ORG_MODE {
    rule  TOP     { ^ <tasks> $ }
    rule  tasks  { <task>+ %% "\n" }
    token task   { <level><content> }
    token level  { \*" " }
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
        make $<content>.made;
    }
    method content($/) {
        make $/.Str;
    }
}

#---------------------------sub--------------------------------

my @tasks;
my $vb_tasks;

sub click_delete ($button) {
	$button.clicked.tap({ 
		@tasks=grep { $_ !~~ /$button/ },@tasks;
		$button.destroy;
	})
}
sub create_task($task) {
	my $b_task = GTK::Simple::Button.new(label => $task);
	@tasks.push($b_task);
	click_delete($b_task);
	$vb_tasks.pack-start($b_task);
}

#--------------------------main--------------------------------

my $file = slurp "todo.txt";
spurt "todo.bak",$file;

my $om-actions = OM-actions.new();
#say ORG_MODE.parse($file);exit;                           # just for test the tree
my $match = ORG_MODE.parse($file, :actions($om-actions));
#say $match.made;exit;                                     # just for test AST

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
create_task($_) for $match.made;

$add.clicked.tap({ 
	create_task($new.text) if $new.text;
});

$save_quit.clicked.tap({
	spurt "todo.txt", (map { "* "~$_.label }, @tasks).join("\n");
	$app.exit; 
});

$quit.clicked.tap({
	$app.exit;
});

$app.run;
