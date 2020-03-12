#!/usr/bin/env perl6

use v6;
use Gnome::GObject::Type;
use Gnome::GObject::Value;
use Gnome::Gtk3::Main;
use Gnome::Gtk3::Window;
use Gnome::Gtk3::Grid;
use Gnome::Gtk3::Button;
use Gnome::Gtk3::TreePath;
use Gnome::Gtk3::TreeStore;
use Gnome::Gtk3::CellRendererText;
use Gnome::Gtk3::TreeView;
use Gnome::Gtk3::TreeViewColumn;
use Gnome::Gtk3::TreeIter;
use Gnome::N::X;

use Data::Dump;

my @org;        # liste of task (and a task is a hash) 
my $file;       # harcoded todo.org # TODO to improve
my $app;        # for GTK window
my $vb_task;    # container GTK for a task

#-----------------------------------Grammar---------------------------

grammar ORG_MODE {
    rule  TOP     { ^ <tasks1> $ }
    rule  tasks1  { <task1>+ %% "\n" }
    token task1   { <level1><todo>\x20?<content>\n<tasks2> }
    token tasks2  { <task2> }               # usr "rule" do'n works, why ?
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
        my %task1=($<content>.made,$<todo>.made,'SUB_task',$<tasks2>);
        make  %task1;
#        say  $<tasks2>;
    }
    method tasks2($/) {
        make $<task2>».made ;
#        say  $<task2> ;
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

use Test;
plan 3;
ok ORG_MODE.parse('** DONE essai', :rule<task2>),
    '<task2> parses ** DONE essai';
ok ORG_MODE.parse('** DOES essai', :rule<task2>),  # curiosly it's right. No TODO/DONE et content is "DOES essai"
    '<task2> does n t parses ** DOES essai';
nok ORG_MODE.parse('* DONE essai', :rule<task2>),
    '<task2> does n t parses * DONE essai';

sub parse_file {
    my $om-actions = OM-actions.new();
#    say ORG_MODE.parse($file);exit;                              # just for test the tree
    my $match = ORG_MODE.parse($file, :actions($om-actions));
#    my @test=$match.made; say @test;  exit;       # just for test AST
    @org= $match.made.Array;  
#    say "after AST : \n",@org;
}

#--------------------------- part GTK--------------------------------

my Gnome::Gtk3::Main $m .= new;

# Class to handle signals
class AppSignalHandlers {
    method save-button-click ( ) {
        say "doesn't work, wait grammar/ast works";
    }
    method add-button-click ( ) {
        my %task=("ORG_task","task5", "ORG_todo","TODO");
        %task=create_task(%task);
        @org.push(%task);
        return; # not necessary but else I have an error
    }
    method quit-button-click ( ) {
        $m.gtk-main-quit;
    }
    method file-test-button-click ( ) {
        save("test.org");
        run 'cat','test.org';
        say "\n"; # yes, 2 lines.
    }
    method tv-button-click ( ) {
        say "test";
    }
}

class X {
  method exit-gui ( --> Int ) {
    $m.gtk-main-quit;
    1
  }
}

my Gnome::Gtk3::TreeIter $iter;

my Gnome::Gtk3::Window $w .= new(:title('List store example'));
$w.set-default-size( 270, 250);

my Gnome::Gtk3::Grid $g .= new();
$w.gtk-container-add($g);

my Gnome::Gtk3::TreeStore $ts .= new(:field-types( G_TYPE_STRING, G_TYPE_STRING));
my Gnome::Gtk3::TreeView $tv .= new(:model($ts));
$tv.set-hexpand(1);
$tv.set-vexpand(1);
$tv.set-headers-visible(1);
$tv.set-activate-on-single-click(1);
$g.gtk-grid-attach( $tv, 0, 0, 4, 1);

my Gnome::Gtk3::Button $b_add  .= new(:label('Add'));
my Gnome::Gtk3::Button $b_save .= new(:label('Save & Quit'));
my Gnome::Gtk3::Button $b_file_test .= new(:label('Save to test'));
my Gnome::Gtk3::Button $b_quit .= new(:label('Quit (no save)'));
$g.gtk-grid-attach( $b_add, 0, 1, 1, 1);
$g.gtk-grid-attach( $b_save, 1, 1, 1, 1);
$g.gtk-grid-attach( $b_file_test, 2, 1, 1, 1);
$g.gtk-grid-attach( $b_quit, 3, 1, 1, 1);

my Gnome::Gtk3::TreeViewColumn $tvc .= new();
my Gnome::Gtk3::CellRendererText $crt1 .= new();
$tvc.pack-end( $crt1, 1);
$tvc.add-attribute( $crt1, 'text', 0);
$tv.append-column($tvc);

my Gnome::Gtk3::CellRendererText $crt2 .= new();
$tvc .= new();
$tvc.pack-end( $crt2, 1);
$tvc.add-attribute( $crt2, 'text', 1);
$tv.append-column($tvc);

my Gnome::Gtk3::TreePath $tp;
my Gnome::Gtk3::TreeIter $parent-iter;

my X $x .= new;
$w.register-signal( $x, 'exit-gui', 'destroy');

my AppSignalHandlers $ash .= new;
$b_add.register-signal( $ash, 'add-button-click', 'clicked');
$b_save.register-signal( $ash, 'save-button-click', 'clicked');
$b_quit.register-signal( $ash, 'quit-button-click', 'clicked');
$b_file_test.register-signal( $ash, 'file-test-button-click', 'clicked');
#$tv.signals-added.row-activated( $ash, 'tv-button-click', 'clicked');

$w.show-all;

#--------------------------------interface---------------------------------

my $i=0;
sub create_task(%task) {
#-	my $b_task_label = GTK::Simple::Button.new(label => %task{"ORG_task"});
#-	my $b_task_todo = GTK::Simple::Button.new(label => "Change todo");
#+	my $l_task_label = GTK::Simple::Label.new(text => %task{"ORG_task"});
# 	my $l_task_todo = GTK::Simple::Label.new(text => %task{"ORG_todo"});
#-	my $b_task = GTK::Simple::VBox.new($b_task_label,$l_task_todo,$b_task_todo);
#+	my $b_task_todo = GTK::Simple::Button.new(label => "Change todo");
#+    my $e_task_modify = GTK::Simple::Entry.new;
#+	# entry my $b_task_todo = GTK::Simple::Button.new(label => "Change todo");
#+	my $b_task_modify = GTK::Simple::Button.new(label => "Modify");
#+	my $b_task_delete = GTK::Simple::Button.new(label => "Delete");
#+	my $b_task = GTK::Simple::VBox.new($l_task_label,$l_task_todo,$b_task_todo,$e_task_modify,$b_task_modify,$b_task_delete);

    my $row=[ %task{"ORG_todo"}, %task{"ORG_task"}];
    $tp .= new(:string($i++.Str));
    $parent-iter = $ts.get-iter($tp);
    $iter = $ts.insert-with-values( $parent-iter, -1, |$row.kv);
    %task{'GTK_main'}=$iter;

    # TODO finaliser les sous-tâches
    $row=[ "DONE", "Sub task $i"];
    $iter = $ts.insert-with-values( $iter, -1, |$row.kv);

#-	delete_task($b_task_label,$b_task);
#-	click_todo($b_task_todo,$l_task_todo,%task);
#+    modify_task($l_task_label,$e_task_modify,$b_task_modify,%task);
#+	delete_task($b_task_delete,$b_task);
#+	modify_todo($b_task_todo,$l_task_todo,%task);
# 	$vb_task.pack-start($b_task);
     return %task;
 }
#-----------------------------------sub-------------------------------
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
populate_task();
$m.gtk-main;
