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
    rule  TOP     { ^ <tasks1> $ }
    rule  tasks1  { <task1>+ %% "\n" }
    token task1   { <level1><todo>\x20?<content>(\n<tasks2>)? }
    token tasks2  { <task2>+ }
    token task2   { <level2><todo>\x20?<content> }
    token level1  { "* " }
    token level2  { "** " }
    token todo  { ["TODO"|"DONE"]? }
    token content { .*? $$ }
}

class OM-actions {
    method TOP($/) {
        make $<tasks1>.made;
    }
    method tasks1($/) {
        make $<task1>».made ;
    }
    method task1($/) {
#        my %task1=($<content>.made,$<todo>.made,'SUB_TASK',$<tasks2>.made);
        my %task1=($<content>.made,$<todo>.made);
        make  %task1;
    }
    method tasks2($/) {
        make $<task2>».made ;
    }
    method task2($/) {
        my %task2=($<content>.made,$<todo>.made);
        make  %task2;
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
    say ORG_MODE.parse($file);exit;                              # just for test the tree
    my $match = ORG_MODE.parse($file, :actions($om-actions));
    my @test=$match.made; say @test; say Dump @test; exit;       # just for test AST
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

sub create_task(%task) {
	my $l_task_label = GTK::Simple::Label.new(text => %task{"ORG_task"});
	my $l_task_todo = GTK::Simple::Label.new(text => %task{"ORG_todo"});
	my $b_task_todo = GTK::Simple::Button.new(label => "Change todo");
    my $e_task_modify = GTK::Simple::Entry.new;
	# entry my $b_task_todo = GTK::Simple::Button.new(label => "Change todo");
	my $b_task_modify = GTK::Simple::Button.new(label => "Modify");
	my $b_task_delete = GTK::Simple::Button.new(label => "Delete");
	my $b_task = GTK::Simple::VBox.new($l_task_label,$l_task_todo,$b_task_todo,$e_task_modify,$b_task_modify,$b_task_delete);
    %task{'GTK_main'}=$b_task;
    modify_task($l_task_label,$e_task_modify,$b_task_modify,%task);
	delete_task($b_task_delete,$b_task);
	modify_todo($b_task_todo,$l_task_todo,%task);
	$vb_task.pack-start($b_task);
    return %task;
}

sub modify_task($l_label,$e_modify,$b_modify,%task) {
	$b_modify.clicked.tap({ 
        $l_label.text=$e_modify.text;
        %task{"ORG_task"}=$l_label.text;
	})
}

sub delete_task ($b_label,$b_master) {
	$b_label.clicked.tap({ 
		@org=grep { $_{'GTK_main'} !~~ /$b_master/ },@org;
		$b_master.destroy;
	})
}

# change state of a task TODO -> DONE -> ''
sub modify_todo ($b_todo,$l_todo,%task) {
	$b_todo.clicked.tap({ 
        given $l_todo.text {
            when "TODO" {$l_todo.text="DONE"}
            when "DONE" {$l_todo.text=""}
            default     {$l_todo.text="TODO"}
        }
        %task{"ORG_todo"}=$l_todo.text;
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
