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
use Gnome::Gtk3::TextView;
use Gnome::Gtk3::TextBuffer;
use Gnome::Gtk3::FileChooser;
use Gnome::Gtk3::FileChooserDialog;
use Gnome::Gtk3::ScrolledWindow;
use NativeCall;
use Gnome::N::X;

use Data::Dump;

my @org;                # list of tasks (and a task is a hash) 
my @preface;            # line before * first task. To include in @org 
my $name;               # filename of current file
my $file;               # content of filename for parse with grammar
my $change=0;           # for ask question to save when quit
my $debug=1;            # to debug =1
my $toggle_rb=False;    # when click on a radio-buttun we have 2 signals. Take only the second
my $presentation=True;  # presentation in mode TODO or Textual
my $i=0;                # for creation of level1 in tree
my $now = DateTime.now(
    formatter => {
        my $dow;
        given .day-of-week {
            when 1 { $dow='lun'}
            when 2 { $dow='mar'}
            when 3 { $dow='mer'}
            when 4 { $dow='jeu'}
            when 5 { $dow='ven'}
            when 6 { $dow='sam'}
            when 7 { $dow='dim'}
        }
        sprintf '%04d-%02d-%02d %s  %02d:%02d', 
        .year, .month, .day, $dow, .hour, .minute
    }
);

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

sub parse_file() {
    my $om-actions = OM-actions.new();
    say ORG_MODE.parse($file);#exit;                              # just for test the grammar
    my $match = ORG_MODE.parse($file, :actions($om-actions));
    my @test=$match.made; say @test; say Dump @test;  exit;       # just for test the AST
    @org= $match.made.Array;  
#    say "after AST : \n",@org;
}

sub demo_procedural_read($name) {
    # TODO to remove, improve grammar/AST
    my token content2 { .*? $$ };

    for $name.IO.lines {
        if ($_~~/^"* "((["TODO"|"DONE"])" ")?<content2>/) {
            my %task=("ORG_task",$<content2>.Str,"ORG_level","1");
            %task{"ORG_todo"}=$0[0].Str if $0[0];
            push(@org,%task);
        } elsif ($_~~/^"** "((["TODO"|"DONE"])" ")?<content2>/) { # TODO create recursive sub
            my %task=pop(@org);
            my %sub_task=("ORG_task",$<content2>.Str,"ORG_level","2");
            %sub_task{"ORG_todo"}=$0[0].Str if $0[0];
            push(%task{"SUB_task"},%sub_task);
            push(@org,%task);
        } else {
            if (@org) {
                my %task=pop(@org);
                if !%task{"SUB_task"} {
                    push(%task{"ORG_text"},$_);
                } else {
                    my @so=%task{"SUB_task"}.Array;
                    my %sub_task=pop(@so);    
                    push(%sub_task{"ORG_text"},$_);
                    push(@so,%sub_task);
                    %task{"SUB_task"}=@so;
                }
                push(@org,%task);
            } else {
                push(@preface,$_);
            }
        }
    }
    say "after : \n", Dump @org;
}

#--------------------------- part GTK--------------------------------

my Gnome::Gtk3::Main $m .= new;
my Gnome::Gtk3::MessageDialog $md .=new(:message('Voulez-vous sauvez votre fichier ?'),:buttons(GTK_BUTTONS_YES_NO));

class X {
  method exit-gui ( --> Int ) {
        if $change && !$debug {
            if $md.run==-8 {
                save($name);
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
$top-window.set-default-size( 640, 480);

my Gnome::Gtk3::Grid $g .= new();
$top-window.gtk-container-add($g);

my Gnome::Gtk3::Menu $list-file-menu = make-menubar-list-file();
my Gnome::Gtk3::Menu $list-option-menu = make-menubar-list-option();
my Gnome::Gtk3::Menu $list-debug-menu = make-menubar-list-debug();
my Gnome::Gtk3::Menu $list-help-menu = make-menubar-list-help();

my Gnome::Gtk3::MenuItem $but-file-menu .= new(:label('_File'));
$but-file-menu.set-use-underline(1);
$but-file-menu.set-submenu($list-file-menu);
my Gnome::Gtk3::MenuItem $but-option-menu .= new(:label('_Option'));
$but-option-menu.set-use-underline(1);
$but-option-menu.set-submenu($list-option-menu);
my Gnome::Gtk3::MenuItem $but-debug-menu .= new(:label('_Debug'));
$but-debug-menu.set-use-underline(1);
$but-debug-menu.set-submenu($list-debug-menu);
my Gnome::Gtk3::MenuItem $but-help-menu .= new(:label('_Help'));
$but-help-menu.set-use-underline(1);
$but-help-menu.set-submenu($list-help-menu);

my Gnome::Gtk3::MenuBar $menu-bar .= new;
$g.gtk_grid_attach( $menu-bar, 0, 0, 1, 1);
$menu-bar.gtk-menu-shell-append($but-file-menu);
$menu-bar.gtk-menu-shell-append($but-option-menu);
$menu-bar.gtk-menu-shell-append($but-debug-menu) if $debug;
$menu-bar.gtk-menu-shell-append($but-help-menu);

my Gnome::Gtk3::ScrolledWindow $sw .= new();
my Gnome::Gtk3::TreeStore $ts .= new(:field-types(G_TYPE_STRING));
my Gnome::Gtk3::TreeView $tv .= new(:model($ts));
$tv.set-hexpand(1);
$tv.set-vexpand(1);
$tv.set-headers-visible(0);
$tv.set-activate-on-single-click(1);
$sw.gtk-container-add($tv);
$g.gtk-grid-attach( $sw, 0, 1, 4, 1);

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

#my Gnome::GObject::Value $gv .= new(:init(G_TYPE_INT));
#$gv.set-int(100);
#$crt2.set-property( 'wrap-width', $gv);
#$gv .= new(:init(G_TYPE_ENUM));
#$gv.set-enum('word');
#$crt2.set-property( 'wrap-mode', $gv);
##$crt2.wrap-width=10;

my Gnome::Gtk3::AboutDialog $about .= new;
$about.set-program-name('org-mode-gtk.raku');
$about.set-version('0.1');
$about.set-license-type(GTK_LICENSE_GPL_3_0);
$about.set-website("http://www.barbason.be");
$about.set-website-label("http://www.barbason.be");

my Gnome::Gtk3::Entry $e_add2;
my Gnome::Gtk3::Entry $e_edit;
my Gnome::Gtk3::Entry $e_edit_text;
my Gnome::Gtk3::Dialog $dialog;
my Gnome::Gtk3::Button $b_del;
my Gnome::Gtk3::Button $b_add2;
my Gnome::Gtk3::Button $b_move_up;
my Gnome::Gtk3::Button $b_move_down;
my Gnome::Gtk3::Button $b_edit;
my Gnome::Gtk3::Button $b_edit_text;
my Gnome::Gtk3::RadioButton $rb_td1;
my Gnome::Gtk3::RadioButton $rb_td2;
my Gnome::Gtk3::RadioButton $rb_td3;
my Gnome::Gtk3::TextView $tev_edit_text;
my Gnome::Gtk3::TextBuffer $text-buffer;

$about.set-authors(CArray[Str].new('Alain BarBason'));

my X $x .= new;
$top-window.register-signal( $x, 'exit-gui', 'destroy');

sub  add2-branch($iter) {
    if $e_add2.get-text {
        $change=1;
        my Array[Gnome::GObject::Value] $v = $ts.tree-model-get-value( $iter, 0);
        @org = map {
            if ($ts.tree-model-get-value( $_{'GTK_iter'}, 0)[0].get-string   # not good, but in waiting...
                    eq $ts.tree-model-get-value( $iter, 0)[0].get-string ) {
                my %task=("ORG_task",$e_add2.get-text, "ORG_todo","TODO","ORG_level","2");
                create_task(%task,$iter);
                push($_{'SUB_task'},%task);
            } ; $_
        }, @org;
    #{say $_} for @org;
        $dialog.gtk_widget_destroy;
    }
}

sub  search-task-in-org-from($iter) {
    my Array[Gnome::GObject::Value] $v = $ts.tree-model-get-value( $iter, 0);
    my Str $data-key = $v[0].get-string // '';
#    say $data-key;
#        @org = grep {  $_{'GTK_iter'} ne $iter }, @org; # TODO doesn't work, why ?
    my @org_tmp = grep { $ts.tree-model-get-value( $_{'GTK_iter'}, 0)[0].get-string   # not good, but in waiting...
            eq $ts.tree-model-get-value( $iter, 0)[0].get-string }, @org;
    # for subtask, find a recusive method
    if (!@org_tmp) { # not found, find in sub
        for @org -> %task {
            if %task{'SUB_task'} && !@org_tmp {
                @org_tmp = grep { $ts.tree-model-get-value( $_{'GTK_iter'}, 0)[0].get-string  
                    eq $ts.tree-model-get-value( $iter, 0)[0].get-string }, %task{"SUB_task"}.Array;
            }
        }
    }
    if @org_tmp {
        return pop(@org_tmp);   # if click on a task
    } else {
        return;                 # if click on text (not now editable)
    }
}

sub set-task-in-org-from($iter,$key,$value) {
    my Array[Gnome::GObject::Value] $v = $ts.tree-model-get-value( $iter, 0);
    my Str $data-key = $v[0].get-string // '';
#        @org = grep {  $_{'GTK_iter'} ne $iter }, @org; # TODO doesn't work, why ?
    @org = map { $_{$key}=$value if 
                $ts.tree-model-get-value( $_{'GTK_iter'}, 0)[0].get-string   # not good, but in waiting...
                eq $ts.tree-model-get-value( $iter, 0)[0].get-string ;
                $_ 
    }, @org;
    # for subtask, find a recusive method
    for @org -> %task {
        if %task{'SUB_task'} {
            %task{'SUB_task'} = map { $_{$key}=$value if 
                        $ts.tree-model-get-value( $_{'GTK_iter'}, 0)[0].get-string   # not good, but in waiting...
                        eq $ts.tree-model-get-value( $iter, 0)[0].get-string ;
                        $_ 
            }, %task{'SUB_task'}.Array;
            %task{'SUB_task'}=%task{'SUB_task'}.Array; 
        }
    }
}

sub  delete-branch($iter) {
    $change=1;
    my Array[Gnome::GObject::Value] $v = $ts.tree-model-get-value( $iter, 0);
    my Str $data-key = $v[0].get-string // '';
#        @org = grep {  $_{'GTK_iter'} ne $iter }, @org; # TODO doesn't work, why ?
    @org = grep { $ts.tree-model-get-value( $_{'GTK_iter'}, 0)[0].get-string   # not good, but in waiting...
            ne $ts.tree-model-get-value( $iter, 0)[0].get-string }, @org;

    # for subtask, find a recusive method
    for @org -> %task {
        my @org_sub;
        if %task{'SUB_task'} {
            for %task{"SUB_task"}.Array {
                push(@org_sub,$_) if $ts.tree-model-get-value( $_{'GTK_iter'}, 0)[0].get-string # TODO, see before
                    ne $ts.tree-model-get-value( $iter, 0)[0].get-string 
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

sub search-indice-in-sub-task-from($iter,@org-sub) {
    #TODO to improve
    my $i=-1;
    for @org-sub {
        $i++;
        return $i if $ts.get-path($iter).get-indices eq $ts.get-path($_{'GTK_iter'}).get-indices;
        }
    return -1;
}

sub update-text($iter,$new-text) {
    set-task-in-org-from($iter,"ORG_text",$new-text.split(/\n/));
    my %task=search-task-in-org-from($iter);
    my $iter_child=$ts.iter-children($iter);
    while $iter_child.is-valid && !search-task-in-org-from($iter_child) { # if no task associate to a task, it's a "text"
        delete-branch($iter_child);
        $iter_child=$ts.iter-children($iter);
    }
    if %task{'ORG_text'} {
        for %task{'ORG_text'}.Array.reverse {
             my Gnome::Gtk3::TreeIter $iter_t2 = $ts.insert-with-values($iter, 0, 0, $_) 
        }
    }
}

# Class to handle signals
class AppSignalHandlers {
    has Gnome::Gtk3::Window $!top-window;
    submethod BUILD ( Gnome::Gtk3::Window :$!top-window ) { }

    method file-save( ) {
        $change=0;
        save($name);
    }
    method file-save-test( ) {
        save("test.org");
        run 'cat','test.org';
        say "\n"; # yes, 2 lines.
    }

  # Show dialog
    method file-open ( --> Int ) {
        if $change && !$debug {
            if $md.run==-8 {
                save($name);
            }
            $md.destroy;
        }
        my Gnome::Gtk3::FileChooserDialog $dialog .= new(
            :title("Open File"), 
            #:parent($!top-window),    # TODO BUG Cannot look up attributes in a AppSignalHandlers type object
            :action(GTK_FILE_CHOOSER_ACTION_SAVE),
            :button-spec( [
                "_Ok", GTK_RESPONSE_OK,
                "_Cancel", GTK_RESPONSE_CANCEL,
                "_Open", GTK_RESPONSE_ACCEPT
            ] )
        );
        my $response = $dialog.gtk-dialog-run;
        if $response ~~ GTK_RESPONSE_ACCEPT {
            $ts.clear();
            @org=[]; 
            @preface=[]; 
            $name = $dialog.get-filename;
            open-file($name) if $name;
        }
        $dialog.gtk-widget-hide;
        1
    }

    method file-quit( ) {
        if $change && !$debug {
            if $md.run==-8 {
                save($name);
            }
            $md.destroy;
        }
        $m.gtk-main-quit;
    }
    method debug-inspect( ) {
        inspect();
    }
    method option-presentation( ) {
        $presentation=!$presentation;
        reconstruct_tree();
        1
    }
    method help-about( ) {
        $about.gtk-dialog-run;
        $about.gtk-widget-hide;
    }
    method add-button-click ( ) {
        if $e_add.get-text {
            $change=1;
            my %task=("ORG_task",$e_add.get-text, "ORG_todo","TODO","ORG_level","1");
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
    method edit-text-button-click ( :$iter ) {
        $change=1;
        my Gnome::Gtk3::TextIter $start = $text-buffer.get-start-iter;
        my Gnome::Gtk3::TextIter $end = $text-buffer.get-end-iter;
        my $new-text=$text-buffer.get-text( $start, $end, 0);
        update-text($iter,$new-text);
        $dialog.gtk_widget_destroy;
        1
    }
    method move-down-button-click ( :$iter ) {
        my @path= $ts.get-path($iter).get-indices.Array;
        my @path2= $ts.get-path($iter).get-indices.Array;
        @path2[*-1]=@path2[*-1].Int;
        @path2[*-1]++;
        my Gnome::Gtk3::TreePath $tp .= new(:indices(@path2));
        my $iter2 = $ts.get-iter($tp);
        if $iter2.is-valid {  # if not, it's the last child
#            if search-task-in-org-from($iter2) { # the down child is always a task but aday may be...
                $change=1;
                if $ts.get-path($iter).get-depth==1 {  # level 1 only
                    $ts.swap($iter,$iter2);
                    @org[@path[*-1],@path2[*-1]] = @org[@path2[*-1],@path[*-1]];
                } else {                # more difficult that level 1, because "text" is not movable
                    my %task2=search-task-in-org-from($iter2);
                    if %task2 {              # if not, probably text et no swap 
                        $ts.swap($iter,$iter2);
                        my $tp=$ts.get-path($iter);
                        $tp.up; # transform in parent
                        my $iter-parent = $ts.get-iter($tp);
                        my %t_parent=search-task-in-org-from($iter-parent);
                        my $line=search-indice-in-sub-task-from($iter,%t_parent{'SUB_task'}.Array);
                        my $line2=search-indice-in-sub-task-from($iter2,%t_parent{'SUB_task'}.Array);
                        %t_parent{'SUB_task'}[$line,$line2] = %t_parent{'SUB_task'}[$line2,$line];
                    }
                }
#            }
        }
        1
    }
    method move-up-button-click ( :$iter ) {
        my @path= $ts.get-path($iter).get-indices.Array;
        if @path[*-1] ne "0" {     # if is not the first child
            my @path2= $ts.get-path($iter).get-indices.Array;
            @path2[*-1]=@path2[*-1].Int;
            @path2[*-1]--;
            my Gnome::Gtk3::TreePath $tp .= new(:indices(@path2));
            my $iter2 = $ts.get-iter($tp);
            if search-task-in-org-from($iter2) { # the up child is a task (not a text)
                $change=1;
                if $ts.get-path($iter).get-depth==1 {  # level 1 only
                    $ts.swap($iter,$iter2);
                    @org[@path[*-1],@path2[*-1]] = @org[@path2[*-1],@path[*-1]];
                } else {                # more difficult that level 1, because "text" is not movable
                    my %task2=search-task-in-org-from($iter2);
                    if %task2 {              # if not, probably text et no swap 
                        $ts.swap($iter,$iter2);
                        my $tp=$ts.get-path($iter);
                        $tp.up; # transform in parent
                        my $iter-parent = $ts.get-iter($tp);
                        my %t_parent=search-task-in-org-from($iter-parent);
                        my $line=search-indice-in-sub-task-from($iter,%t_parent{'SUB_task'}.Array);
                        my $line2=search-indice-in-sub-task-from($iter2,%t_parent{'SUB_task'}.Array);
                        %t_parent{'SUB_task'}[$line,$line2] = %t_parent{'SUB_task'}[$line2,$line];
                    }
                }
            }
        }
        1
    }
    method edit-button-click ( :$iter ) {
        $change=1;
        set-task-in-org-from($iter,"ORG_task",$e_edit.get-text());
        $ts.set_value( $iter, 0,string_from(search-task-in-org-from($iter)));
        $dialog.gtk_widget_destroy;
        1
    }
    method todo-button-click ( :$iter,:$todo --> Int ) {
        if ($toggle_rb) {  # see definition 
            $change=1;
            set-task-in-org-from($iter,"ORG_todo",$todo);
            $ts.set_value( $iter, 0,string_from(search-task-in-org-from($iter)));
            my Gnome::Gtk3::TextIter $start = $text-buffer.get-start-iter;
            my Gnome::Gtk3::TextIter $end = $text-buffer.get-end-iter;
            my $text=$text-buffer.get-text( $start, $end, 0);
            if $todo eq 'DONE' {
                if $text.encode.elems>0 {
                    update-text($iter,"CLOSED: [$now]\n"~$text);
                } else {
                    update-text($iter,"CLOSED: [$now]");
                }
            } elsif $todo eq 'TODO' && $text~~/^\s*CLOSED/ {
                $text~~s/^\s*CLOSED.*?\]\n?//;
                update-text($iter,$text);
            }
            $dialog.gtk_widget_destroy;
        }
        $toggle_rb=!$toggle_rb;
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
            :button-spec( "Cancel", GTK_RESPONSE_NONE)
        );
        my Gnome::Gtk3::Box $content-area .= new(:native-object($dialog.get-content-area));

        # to edit task
        if search-task-in-org-from($iter) {      # if not, it's a text not now editable 
            my %task=search-task-in-org-from($iter);

            # to move
            $b_move_up  .= new(:label('^'));
            $content-area.gtk_container_add($b_move_up);
            b_move_up-register-signal($iter);
            $b_move_down  .= new(:label('v'));
            $content-area.gtk_container_add($b_move_down);
            b_move_down-register-signal($iter);

            # To edit task
            $e_edit  .= new();
            $e_edit.set-text(%task{'ORG_task'});
            $content-area.gtk_container_add($e_edit);
            $b_edit  .= new(:label('Update task'));
            $content-area.gtk_container_add($b_edit);
            b_edit-register-signal($iter);
            
            # To edit text
            $tev_edit_text .= new;
            $text-buffer .= new(:native-object($tev_edit_text.get-buffer));
            if %task{'ORG_text'} {
                my $text=%task{'ORG_text'}.join("\n");
                $text-buffer.set-text($text,$text.encode('UTF-8').bytes);
            }
            $content-area.gtk_container_add($tev_edit_text);
            $b_edit_text  .= new(:label('Update text'));
            $content-area.gtk_container_add($b_edit_text);
            b_edit_text-register-signal($iter);
            
            # To manage TODO/DONE
            %task=search-task-in-org-from($iter);
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

            # To add a sub-task
            $e_add2  .= new();
            $content-area.gtk_container_add($e_add2);
            $b_add2  .= new(:label('Add sub-task'));
            $content-area.gtk_container_add($b_add2);
            b_add2-register-signal($iter);
            
            # to delete the task
            $b_del  .= new(:label('Delete task (and sub-tasks)'));
            $content-area.gtk_container_add($b_del);
            b_del-register-signal($iter);

            # Show the dialog.
            $dialog.show-all;
            $dialog.gtk-dialog-run;
            $dialog.gtk_widget_destroy;
        } else {  # text
            # manage via dialog task
        }
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
sub b_move_up-register-signal ($iter) {
    $b_move_up.register-signal( $ash, 'move-up-button-click', 'clicked',:iter($iter));
}
sub b_move_down-register-signal ($iter) {
    $b_move_down.register-signal( $ash, 'move-down-button-click', 'clicked',:iter($iter));
}

sub b_edit-register-signal ($iter) {
    $b_edit.register-signal( $ash, 'edit-button-click', 'clicked',:iter($iter));
}

sub b_edit_text-register-signal ($iter) {
    $b_edit_text.register-signal( $ash, 'edit-text-button-click', 'clicked',:iter($iter));
}

# Create menu for the menu bar
sub make-menubar-list-file( ) {
    my Gnome::Gtk3::Menu $menu .= new;
    my Gnome::Gtk3::MenuItem $menu-item .= new(:label("_Save"));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, 'file-save', 'activate');
    $menu-item .= new(:label("_Open"));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, 'file-open', 'activate');
    $menu-item .= new(:label("Save to _test"));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item) if $debug;
    $menu-item.register-signal( $ash, 'file-save-test', 'activate');
    $menu-item .= new(:label("_Quit"));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, 'file-quit', 'activate');
    $menu
}

sub make-menubar-list-option() {
    my Gnome::Gtk3::Menu $menu .= new;
    my Gnome::Gtk3::MenuItem $menu-item .= new(:label("_Presentation"));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, 'option-presentation', 'activate');
    $menu
}

sub make-menubar-list-debug() {
    my Gnome::Gtk3::Menu $menu .= new;
    my Gnome::Gtk3::MenuItem $menu-item .= new(:label("_Inspect"));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, 'debug-inspect', 'activate');
    $menu
}

sub make-menubar-list-help ( ) {
    my Gnome::Gtk3::Menu $menu .= new;
    my Gnome::Gtk3::MenuItem $menu-item .= new(:label("_About"));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, 'help-about', 'activate');
    $menu
}

$top-window.show-all;

#--------------------------------interface---------------------------------

sub string_from(%task) {
    if $presentation {
        my $str_todo;
        if (!%task{"ORG_todo"})             {$str_todo=' '}
        elsif (%task{"ORG_todo"} eq "TODO") {$str_todo='<span foreground="red"> TODO</span>'}
        elsif (%task{"ORG_todo"} eq "DONE") {$str_todo='<span foreground="green"> DONE</span>'}
        my $str_task;
        if    (%task{"ORG_level"} eq "1") {$str_task='<span foreground="blue" > '~%task{"ORG_task"}~'</span>'}
        elsif (%task{"ORG_level"} eq "2") {$str_task='<span foreground="brown"> '~%task{"ORG_task"}~'</span>'}
        return $str_todo ~ " " ~$str_task;
    } else {
        my $str_task;
        if    (%task{"ORG_level"} eq "1") {$str_task='<span foreground="blue" size="xx-large" >'~%task{"ORG_task"}~'</span>'}
        elsif (%task{"ORG_level"} eq "2") {$str_task='<span foreground="deepskyblue" size="x-large">'~%task{"ORG_task"}~'</span>'}
        return $str_task;
    }
}

sub create_task(%task, Gnome::Gtk3::TreeIter $iter?) {
    my Gnome::Gtk3::TreeIter $parent-iter;
    if (!$iter) {
        my Gnome::Gtk3::TreePath $tp .= new(:string($i++.Str));
        $parent-iter = $ts.get-iter($tp);
    } else {
        $parent-iter = $iter;
    }
    my Gnome::Gtk3::TreeIter $iter_task = $ts.insert-with-values($parent-iter, -1, 0, string_from(%task));
    if %task{'ORG_text'} {
        for %task{'ORG_text'}.Array {
             my Gnome::Gtk3::TreeIter $iter_t2 = $ts.insert-with-values($iter_task, -1, 0, $_) 
        }
    }
    %task{'GTK_iter'}=$iter_task;

    if (%task{"SUB_task"}) {
        for %task{"SUB_task"}.Array {
            create_task($_,$iter_task);
        }
    }
    return %task;
}
#-----------------------------------sub-------------------------------
sub read_file($name) {
    $file = slurp $name;
    spurt $name~".bak",$file;
}

sub reconstruct_tree { # not good practice, not abuse
    $i=0;
    $ts.clear();
    populate_task();
}

sub populate_task {
    @org = map {create_task($_)}, @org;
#    say "after create task : \n",@org;
}

sub open-file($name) {
    read_file($name);
    0 ?? parse_file() !! demo_procedural_read($name);       # 0 if AST doesn't work
    populate_task();
}

sub inspect-task(%task) {
    say $ts.get-path(%task{'GTK_iter'}).get-indices;
    if %task{"SUB_task"} {
        for %task{"SUB_task"}.Array {
            inspect-task($_);
        }
    }
}

sub inspect() {
    for @org -> %task {
        inspect-task(%task);
    }
}

sub save_task(%task) {
    my $orgmode="";
    $orgmode~=join(" ",grep {$_}, ("*" x %task{"ORG_level"},%task{"ORG_todo"},%task{"ORG_task"}))~"\n";
    if (%task{"ORG_text"}) {
        for %task{"ORG_text"}.Array {
            $orgmode~=$_~"\n";
        }
    }
    if %task{"SUB_task"} {
        for %task{"SUB_task"}.Array {
            $orgmode~=save_task($_);
        }
    }
    return $orgmode;
}

sub save($name) {
    my $orgmode="";
    for @preface {
        $orgmode~=$_~"\n";
    }
    for @org -> %task {
        $orgmode~=save_task(%task);
    }
	spurt $name, $orgmode;
}

#--------------------------main--------------------------------

sub MAIN($arg = '') {
    $name=$arg;
    open-file($name) if $name;
    $m.gtk-main;
}

