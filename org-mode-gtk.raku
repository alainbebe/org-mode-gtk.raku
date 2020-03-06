#!/usr/bin/env perl6

use v6;
use GTK::Simple;
use GTK::Simple::App;
use Data::Dump;

my @org;        # liste of task (and a task is a hash) 
my $file;       # harcoded todo.org # TODO to improve
my $app;        # for GTK window
my $vb_task;    # container GTK for a task

#-----------------------------------Grammar---------------------------

grammar ORG_MODE {
    rule  TOP     { ^ <tasks> $ }
    rule  tasks  { <task>+ %% "\n" }
    token task   { <level><todo>\x20?<content> }
    token level  { \*" " }
    token todo  { ["TODO" | "DONE"]? }
    token content { <-[\n]>+ }
}

class OM-actions {
    method TOP($/) {
        make $<tasks>.made;
    }
    method tasks($/) {
        make $<task>».made ;
    }
    method task($/) {
        my %task=($<content>.made,$<todo>.made);
        make  %task;
    }
    method todo($/) {
        make  "ORG_todo" => ~$/.Str;
    }
    method content($/) {
        make "ORG_task" =>  ~$/.Str ;
    }
}

sub parse_file {
    my $om-actions = OM-actions.new();
    #say ORG_MODE.parse($file);exit;                              # just for test the tree
    my $match = ORG_MODE.parse($file, :actions($om-actions));
    #my @test=$match.made; say @test; say Dump @test; exit;       # just for test AST
    @org= $match.made.Array;  
    say "after AST : \n",@org;
}

#---------------------------sub--------------------------------

sub create_window {
    $app = GTK::Simple::App.new( title => "Org-mode with GTK and Raku" );
    $app.set-content(
        my $gtk = GTK::Simple::HBox.new(
            my $gtk1 = GTK::Simple::VBox.new(
                my $new = GTK::Simple::Entry.new,
                my $add       = GTK::Simple::Button.new(label => "Add"),
                my $save_quit = GTK::Simple::Button.new(label => "Save & Quit"),
                my $save_test = GTK::Simple::Button.new(label => "Save in test.org"),   # uncomment for testing
                my $quit      = GTK::Simple::Button.new(label => "Quit (don't save)"),
            ),
            my $gtk2 = GTK::Simple::VBox.new(
                $vb_task      = GTK::Simple::VBox.new(),            # populate after
            )
        )
    );
    $add.clicked.tap({ 
        my %task= 'ORG_task' => $new.text , 'ORG_todo' => '';
        @org.push(create_task(%task)) if $new.text;
    });

    $save_test.clicked.tap({
        save("test.org");
        run 'cat','test.org';
        say "\n"; # yes, 2 lines.
    });

    $save_quit.clicked.tap({
        save("todo.org");
        $app.exit; 
    });

    $quit.clicked.tap({
        $app.exit;
    });
}
# change state of a task TODO -> DONE -> ''
sub click_todo ($b_todo,$l_todo,%task) {
	$b_todo.clicked.tap({ 
        given $l_todo.text {
            when "TODO" {$l_todo.text="DONE"}
            when "DONE" {$l_todo.text=""}
            default     {$l_todo.text="TODO"}
        }
        %task{"ORG_todo"}=$l_todo.text;
	})
}

sub create_task(%task) {
	my $b_task_label = GTK::Simple::Button.new(label => %task{"ORG_task"});
	my $b_task_todo = GTK::Simple::Button.new(label => "Change todo");
	my $l_task_todo = GTK::Simple::Label.new(text => %task{"ORG_todo"});
	my $b_task = GTK::Simple::VBox.new($b_task_label,$l_task_todo,$b_task_todo);
    %task{'GTK_main'}=$b_task;
	delete_task($b_task_label,$b_task);
	click_todo($b_task_todo,$l_task_todo,%task);
	$vb_task.pack-start($b_task);
    return %task;
}

sub delete_task ($b_label,$b_master) {
	$b_label.clicked.tap({ 
		@org=grep { $_{'GTK_main'} !~~ /$b_master/ },@org;
		$b_master.destroy;
	})
}

sub read_file {
    $file = slurp "todo.org";
    spurt "todo.bak",$file;
}

sub populate_task {
    @org = map {create_task($_)}, @org;
    say "after create task : \n",@org;
}

sub save($file) {
	spurt $file  , (
        map { 
            join(" ",
                grep {$_}, ("*",$_{"ORG_todo"},$_{"ORG_task"})
            ) 
        }, @org
    ).join("\n");
}

#--------------------------main--------------------------------

read_file();
parse_file();
create_window();
populate_task();
$app.run;
