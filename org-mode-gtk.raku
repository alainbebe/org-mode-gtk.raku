#!/usr/bin/env perl6

use v6;

use Gnome::N::N-GObject;
use Gnome::GObject::Type;
use Gnome::GObject::Value;
use Gnome::Gtk3::Main;
use Gnome::Gtk3::Window;
use Gnome::Gtk3::Grid;
use Gnome::Gtk3::Button;
use Gnome::Gtk3::RadioButton;
use Gnome::Gtk3::Label;
use Gnome::Gtk3::Entry;
use Gnome::Gtk3::TreePath;
use Gnome::Gtk3::TreeStore;
use Gnome::Gtk3::CellRendererText;
use Gnome::Gtk3::TreeView;
use Gnome::Gtk3::TreeViewColumn;
use Gnome::Gtk3::TreeIter;
use Gnome::Gtk3::MenuBar;
use Gnome::Gtk3::Menu;
use Gnome::Gtk3::MenuItem;
use Gnome::Gtk3::Dialog;
use Gnome::Gtk3::MessageDialog;
use Gnome::Gtk3::AboutDialog;
use Gnome::Gtk3::Box;
use NativeCall;
use Gnome::N::X;

use Data::Dump;

my @org;        # list of tasks (and a task is a hash) 
my $file;       # for reading demo.org # TODO to improve
my $change=0;   # for ask question to save when quit
my $debug=0;    # to debug =1

#-----------------------------------Grammar---------------------------

grammar ORG_MODE {
    rule  TOP       { ^ <tasks> $ }
    rule  tasks     { <task>+ %% "\n" }
    token task      { <level1><todo>\x20?<content>(\n<sub_tasks>)* }
    token sub_tasks { "*"<task> }               # use "rule" doesn't work, why ?
    token level1    { "* " }
    token todo      { ["TODO"|"DONE"]? }
    token content   { .*? $$ }
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
        say $<sub_tasks>>>.made;
        %task=('SUB_task',$<sub_tasks>.made) if $<sub_tasks>.made;
        make  %task;
    }
    method sub_tasks($/) {
        my %sts=$<task>.made ;
        make %sts;
    }
    method todo($/) {
        make  "ORG_todo" => ~$/.Str;
    }
    method content($/) {
        make "ORG_task" =>  ~$/.Str ;
    }
}

#use Test;
#plan 3;
#ok ORG_MODE.parse('* DONE essai', :rule<task>),
#    '<task> parses * DONE essai';
#ok ORG_MODE.parse('* DOES essai', :rule<task>),  # curiosly it's right. No TODO/DONE et content is "DOES essai"
#    '<task> parses * DOES essai';
#nok ORG_MODE.parse('** DONE essai', :rule<task>),
#    '<task> does n t parses ** DONE essai';

sub parse_file {
    my $om-actions = OM-actions.new();
    say ORG_MODE.parse($file);#exit;                              # just for test the grammar
    my $match = ORG_MODE.parse($file, :actions($om-actions));
    my @test=$match.made; say @test; say Dump @test;  exit;       # just for test the AST
    @org= $match.made.Array;  
#    say "after AST : \n",@org;
}

sub demo_procedural_read {
    # TODO to remove, improve grammar/AST
    my token content2 { .*? $$ };

    for "demo.org".IO.lines {
        if ($_~~/^"* "((["TODO"|"DONE"])" ")?<content2>/) {
            my %task=("ORG_task",$<content2>.Str);
            %task{"ORG_todo"}=$0[0].Str if $0[0];
            push(@org,%task);
        }
        if ($_~~/^"** "((["TODO"|"DONE"])" ")?<content2>/) {
            my %task=pop(@org);
            my %sub_task=("ORG_task",$<content2>.Str);
            %sub_task{"ORG_todo"}=$0[0].Str if $0[0];
            push(%task{"SUB_task"},%sub_task);
            push(@org,%task);
        }
    }
#    say "after : \n", Dump @org;
}

#--------------------------- part GTK--------------------------------

my Gnome::Gtk3::Main $m .= new;
my Gnome::Gtk3::MessageDialog $md .=new(:message('Voulez-vous sauvez votre fichier ?'),:buttons(GTK_BUTTONS_YES_NO));

class X {
  method exit-gui ( --> Int ) {
        if $change {
            if $md.run==-8 {
                save("demo.org");
            }
            $md.destroy;
        }
    $m.gtk-main-quit;
    1
  }
}

my Gnome::Gtk3::TreeIter $iter;

my Gnome::GObject::Type $type .= new;
my int32 $menu-shell-gtype = $type.g_type_from_name('GtkMenuShell');


my Gnome::Gtk3::Window $top-window .= new(:title('Org-Mode with GTK and raku'));
$top-window.set-default-size( 270, 250);

my Gnome::Gtk3::Grid $g .= new();
$top-window.gtk-container-add($g);

my Gnome::Gtk3::Menu $list-file-menu = make-menubar-list-file();
my Gnome::Gtk3::Menu $list-help-menu = make-menubar-list-help();

my Gnome::Gtk3::MenuItem $but-file-menu .= new(:label('File'));
$but-file-menu.set-submenu($list-file-menu);
my Gnome::Gtk3::MenuItem $but-help-menu .= new(:label('Help'));
$but-help-menu.set-submenu($list-help-menu);

my Gnome::Gtk3::MenuBar $menu-bar .= new;
$g.gtk_grid_attach( $menu-bar, 0, 0, 1, 1);
$menu-bar.gtk-menu-shell-append($but-file-menu);
$menu-bar.gtk-menu-shell-append($but-help-menu);

my Gnome::Gtk3::TreeStore $ts .= new(:field-types( G_TYPE_STRING, G_TYPE_STRING));
my Gnome::Gtk3::TreeView $tv .= new(:model($ts));
$tv.set-hexpand(1);
$tv.set-vexpand(1);
$tv.set-headers-visible(1);
$tv.set-activate-on-single-click(1);
$g.gtk-grid-attach( $tv, 0, 1, 4, 1);

my Gnome::Gtk3::Entry $e_add  .= new();
my Gnome::Gtk3::Button $b_add  .= new(:label('Add task'));
my Gnome::Gtk3::Label $l_del  .= new(:text('Click on task to manage'));
$g.gtk-grid-attach( $e_add, 0, 2, 1, 1);
$g.gtk-grid-attach( $b_add, 1, 2, 1, 1);
$g.gtk-grid-attach( $l_del, 2, 2, 1, 1);

my Gnome::Gtk3::TreeViewColumn $tvc .= new();
my Gnome::Gtk3::CellRendererText $crt1 .= new();
$tvc.pack-end( $crt1, 1);
$tvc.add-attribute( $crt1, 'markup', 0);
$tv.append-column($tvc);

my Gnome::Gtk3::CellRendererText $crt2 .= new();
$tvc .= new();
$tvc.pack-end( $crt2, 1);
$tvc.add-attribute( $crt2, 'text', 1);
$tv.append-column($tvc);

my Gnome::Gtk3::TreePath $tp;
my Gnome::Gtk3::TreeIter $parent-iter;

my Gnome::Gtk3::AboutDialog $about .= new;
$about.set-program-name('org-mode-gtk.raku');
$about.set-version('0.1');
$about.set-license-type(GTK_LICENSE_GPL_3_0);
$about.set-website("http://www.barbason.be");
$about.set-website-label("http://www.barbason.be");

my Gnome::Gtk3::Entry $e_add2;
my Gnome::Gtk3::Dialog $dialog;

$about.set-authors(CArray[Str].new('Alain BarBason'));

my X $x .= new;
$top-window.register-signal( $x, 'exit-gui', 'destroy');

sub  add2-branch($iter) {
    if $e_add2.get-text {
        $change=1;
        my Array[Gnome::GObject::Value] $v = $ts.tree-model-get-value( $iter, 1);
        @org = map {
            if ($ts.tree-model-get-value( $_{'GTK_iter'}, 1)[0].get-string   # not good, but in waiting...
                    eq $ts.tree-model-get-value( $iter, 1)[0].get-string ) {
                my %task=("ORG_task",$e_add2.get-text, "ORG_todo","TODO");
                create_sub_task(%task,$iter);
                push($_{'SUB_task'},%task);
            } ; $_
        }, @org;
    #{say $_} for @org;
        $dialog.gtk_widget_destroy;
    }
}

sub  search-task-in-org-from($iter) {
    my Array[Gnome::GObject::Value] $v = $ts.tree-model-get-value( $iter, 1);
    my Str $data-key = $v[0].get-string // '';
#    say $data-key;
#        @org = grep {  $_{'GTK_iter'} ne $iter }, @org; # TODO doesn't work, why ?
    my @org_tmp = grep { $ts.tree-model-get-value( $_{'GTK_iter'}, 1)[0].get-string   # not good, but in waiting...
            eq $ts.tree-model-get-value( $iter, 1)[0].get-string }, @org;
    # for subtask, find a recusive method
    if (!@org_tmp) { # not found, find in sub
        for @org -> %task {
            if %task{'SUB_task'} && !@org_tmp {
                @org_tmp = grep { $ts.tree-model-get-value( $_{'GTK_iter'}, 1)[0].get-string  
                    eq $ts.tree-model-get-value( $iter, 1)[0].get-string }, %task{"SUB_task"}.Array;
            }
        }
    }
    return pop(@org_tmp);
}

sub  set-task-in-org-from($iter,$key,$value) {
    my Array[Gnome::GObject::Value] $v = $ts.tree-model-get-value( $iter, 0);
    my Str $data-key = $v[0].get-string // '';
#        @org = grep {  $_{'GTK_iter'} ne $iter }, @org; # TODO doesn't work, why ?
    @org = map { $_{$key}=$value if 
                $ts.tree-model-get-value( $_{'GTK_iter'}, 1)[0].get-string   # not good, but in waiting...
                eq $ts.tree-model-get-value( $iter, 1)[0].get-string ;
                $_ 
    }, @org;
    # for subtask, find a recusive method
    for @org -> %task {
        if %task{'SUB_task'} {
            %task{'SUB_task'} = map { $_{$key}=$value if 
                        $ts.tree-model-get-value( $_{'GTK_iter'}, 1)[0].get-string   # not good, but in waiting...
                        eq $ts.tree-model-get-value( $iter, 1)[0].get-string ;
                        $_ 
            }, %task{'SUB_task'}.Array;
        }
    }
}

sub  delete-branch($iter) {
    $change=1;
    my Array[Gnome::GObject::Value] $v = $ts.tree-model-get-value( $iter, 1);
    my Str $data-key = $v[0].get-string // '';
#        @org = grep {  $_{'GTK_iter'} ne $iter }, @org; # TODO doesn't work, why ?
    @org = grep { $ts.tree-model-get-value( $_{'GTK_iter'}, 1)[0].get-string   # not good, but in waiting...
            ne $ts.tree-model-get-value( $iter, 1)[0].get-string }, @org;

    # for subtask, find a recusive method
    for @org -> %task {
        my @org_sub;
        if %task{'SUB_task'} {
            for %task{"SUB_task"}.Array {
                push(@org_sub,$_) if $ts.tree-model-get-value( $_{'GTK_iter'}, 1)[0].get-string # TODO, see before
                    ne $ts.tree-model-get-value( $iter, 1)[0].get-string 
            }
        }
        if @org_sub {
            %task{'SUB_task'}=@org_sub;
        } else {
            %task{'SUB_task'}:delete;
        }
    }
    $ts.gtk-tree-store-remove($iter);
    $dialog.gtk_widget_destroy;
}

my Gnome::Gtk3::Button $b_del;
my Gnome::Gtk3::Button $b_add2;
my Gnome::Gtk3::RadioButton $rb_td1;
my Gnome::Gtk3::RadioButton $rb_td2;
my Gnome::Gtk3::RadioButton $rb_td3;

# Class to handle signals
class AppSignalHandlers {
    has Gnome::Gtk3::Window $!top-window;
    submethod BUILD ( Gnome::Gtk3::Window :$!top-window ) { }

    method file-save( ) {
        $change=0;
        save("demo.org");
    }
    method file-save-test( ) {
        save("test.org");
        run 'cat','test.org';
        say "\n"; # yes, 2 lines.
    }
    method file-quit( ) {
        if $change {
            if $md.run==-8 {
                save("demo.org");
            }
            $md.destroy;
        }
        $m.gtk-main-quit;
    }
    method help-about( ) {
        $about.gtk-dialog-run;
        $about.gtk-widget-hide;
    }
    method add-button-click ( ) {
        if $e_add.get-text {
            $change=1;
            my %task=("ORG_task",$e_add.get-text, "ORG_todo","TODO");
            $e_add.set-text("");
            %task=create_task(%task);
            @org.push(%task);
        }
        1
    }
    method add2-button-click ( :$iter --> Int ) {
        add2-branch($iter);
        1
    }
    method todo-button-click ( :$iter,:$todo --> Int ) {
        $change=1;
        $ts.set_value( $iter, 0,$todo);
        set-task-in-org-from($iter,"ORG_todo",$todo);
        1
    }
    method del-button-click ( :$iter --> Int ) {
        delete-branch($iter);
        1
    }
    method tv-button-click (N-GtkTreePath $path, N-GObject $column ) {
        my Gnome::Gtk3::TreePath $tree-path .= new(:native-object($path));
        my Gnome::Gtk3::TreeIter $iter = $ts.tree-model-get-iter($tree-path);
        # Dialog to manage task
        $dialog .= new(
            :title("Manage task"), 
            :parent($!top-window),
            :flags(GTK_DIALOG_DESTROY_WITH_PARENT),
            :button-spec( "Ok", GTK_RESPONSE_NONE)
        );
        my Gnome::Gtk3::Box $content-area .= new(:native-object($dialog.get-content-area));

        # To manage TODO/DONE
        my %task=search-task-in-org-from($iter);
        my Gnome::Gtk3::Grid $g_todo .= new;
        $content-area.gtk_container_add($g_todo);
        $rb_td1 .= new(:label('-'));
        $rb_td2 .= new( :group-from($rb_td1), :label('TODO'));
        $rb_td3 .= new( :group-from($rb_td1), :label('DONE'));
        if    (!%task{'ORG_todo'})          { $rb_td1.set-active(1);}
        elsif (%task{'ORG_todo'} eq 'TODO') { $rb_td2.set-active(1);}
        elsif (%task{'ORG_todo'} eq 'DONE') { $rb_td3.set-active(1);} 
        $g_todo.gtk-grid-attach( $rb_td1, 0, 0, 1, 1);
        $g_todo.gtk-grid-attach( $rb_td2, 1, 0, 1, 1);
        $g_todo.gtk-grid-attach( $rb_td3, 2, 0, 1, 1);
        b_rb-register-signal($iter);

        $e_add2  .= new();
        $content-area.gtk_container_add($e_add2);
        $b_add2  .= new(:label('Add sub-task'));
        $content-area.gtk_container_add($b_add2);
        b_add2-register-signal($iter);
        $b_del  .= new(:label('Delete task (and sub-tasks)'));
        $content-area.gtk_container_add($b_del);
        b_del-register-signal($iter);

        # Show the dialog. After return (Ok pressed) the dialog widget
        # is destroyed. show-all() must be called, otherwise the message
        # will not be seen.
        $dialog.show-all;
        $dialog.gtk-dialog-run;
        $dialog.gtk_widget_destroy;
        1
    }
}

my AppSignalHandlers $ash .= new(:$top-window);
$b_add.register-signal( $ash, 'add-button-click', 'clicked');
$tv.register-signal( $ash, 'tv-button-click', 'row-activated');
sub b_add2-register-signal ($iter) {
    $b_add2.register-signal( $ash, 'add2-button-click', 'clicked',:iter($iter));
}
sub b_del-register-signal ($iter) {
    $b_del.register-signal( $ash, 'del-button-click', 'clicked',:iter($iter));
}
sub b_rb-register-signal($iter) {
    $rb_td1.register-signal( $ash, 'todo-button-click', 'clicked',:iter($iter),:todo(""));
    $rb_td2.register-signal( $ash, 'todo-button-click', 'clicked',:iter($iter),:todo("TODO"));
    $rb_td3.register-signal( $ash, 'todo-button-click', 'clicked',:iter($iter),:todo("DONE"));
}

# Create menu for the menu bar
sub make-menubar-list-file( ) {
    my Gnome::Gtk3::Menu $menu .= new;
    my Gnome::Gtk3::MenuItem $menu-item .= new(:label("Save"));
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, 'file-save', 'activate');
    $menu-item .= new(:label("Save to test"));
    $menu.gtk-menu-shell-append($menu-item) if $debug;
    $menu-item.register-signal( $ash, 'file-save-test', 'activate');
    $menu-item .= new(:label("Quit"));
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, 'file-quit', 'activate');
    $menu
}

sub make-menubar-list-help ( ) {
    my Gnome::Gtk3::Menu $menu .= new;
    my Gnome::Gtk3::MenuItem $menu-item .= new(:label("About"));
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, 'help-about', 'activate');
    $menu
}

$top-window.show-all;

#--------------------------------interface---------------------------------

sub create_sub_task(%task,$iter) {
    my $str_todo;
    if (!%task{"ORG_todo"})             {$str_todo=' '}
    elsif (%task{"ORG_todo"} eq "TODO") {$str_todo='<span foreground="red"> TODO</span>'}
    elsif (%task{"ORG_todo"} eq "DONE") {$str_todo='<span foreground="green"> DONE</span>'}
    my $row=[$str_todo, %task{"ORG_task"}];
    my $iter_st = $ts.insert-with-values( $iter, -1, |$row.kv);
    %task{'GTK_iter'}=$iter_st;
}

my $i=0;
sub create_task(%task) {
    my $str_todo;
    if (!%task{"ORG_todo"})             {$str_todo=' '}
    elsif (%task{"ORG_todo"} eq "TODO") {$str_todo='<span foreground="red"> TODO</span>'}
    elsif (%task{"ORG_todo"} eq "DONE") {$str_todo='<span foreground="green"> DONE</span>'}
    my $row=[$str_todo, %task{"ORG_task"}];
    $tp .= new(:string($i++.Str));
    $parent-iter = $ts.get-iter($tp);
    $iter = $ts.insert-with-values( $parent-iter, -1, |$row.kv);
    %task{'GTK_iter'}=$iter;

    # TODO create a recursive sub 
    if (%task{"SUB_task"}) {
        for %task{"SUB_task"}.Array {
            create_sub_task($_,$iter);
        }
    }
    return %task;
}
#-----------------------------------sub-------------------------------
sub read_file {
    $file = slurp "demo.org";
    spurt "demo.bak",$file;
}

sub populate_task {
    @org = map {create_task($_)}, @org;
#    say "after create task : \n",@org;
}

sub save($file) {
    my $orgmode="";
    for @org -> %task {
        $orgmode~=join(" ",grep {$_}, ("*",%task{"ORG_todo"},%task{"ORG_task"}))~"\n";
        # use a recusive sub
        if %task{"SUB_task"} {
            for %task{"SUB_task"}.Array {
                $orgmode~=join(" ",grep {$_}, ("**",$_{"ORG_todo"},$_{"ORG_task"}))~"\n";
            }
        }
    }
	spurt $file, $orgmode;
}

#--------------------------main--------------------------------

read_file();
0 ?? parse_file() !! demo_procedural_read();       # 0 if AST doesn't work
populate_task();
$m.gtk-main;
