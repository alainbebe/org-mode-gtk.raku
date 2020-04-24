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

my $change=0;           # for ask question to save when quit
my $debug=1;            # to debug =1
my $toggle_rb=False;    # when click on a radio-buttun we have 2 signals. Take only the second
my $presentation=True;  # presentation in mode TODO or Textual
my $no-done=False;      # display with no DONE
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

my Gnome::Gtk3::TreeStore $ts .= new(:field-types(G_TYPE_STRING));

#----------------------- class Task & OrgMode
#use lib ".";
#use Task;
class Task {
    has Int  $.level     is rw;
    has Str  $.todo      is rw;
    has Str  $.header    is rw; #  is required
    has Str  @.text      is rw;
    has Task @.sub-tasks is rw;
    has Gnome::Gtk3::TreeIter $.iter is rw; # TODO create 2 Class, one pure Task, and one GtkTask hertiable with "iter"

    method display-header {
        if $presentation {
            my $str_todo;
            if (!$.todo)             {$str_todo=' '}
            elsif ($.todo eq "TODO") {$str_todo='<span foreground="red"  > TODO</span>'}
            elsif ($.todo eq "DONE") {$str_todo='<span foreground="green"> DONE</span>'}
            my $str_task;
            if    ($.level==1) {$str_task='<span foreground="blue" > '~$.header~'</span>'}
            elsif ($.level==2) {$str_task='<span foreground="brown"> '~$.header~'</span>'}
            return $str_todo ~ " " ~$str_task;
        } else {
            my $str_task;
            if    ($.level==1) {$str_task='<span foreground="blue" size="xx-large"      >'~$.header~'</span>'}
            elsif ($.level==2) {$str_task='<span foreground="deepskyblue" size="x-large">'~$.header~'</span>'}
            return $str_task;
        }
        return $.todo~" "~$.header;
    }
    method iter-get-indices { # find indices IN treestore, not tasks
        if $.iter.defined && $.iter.is-valid {
            return  $ts.get-path($.iter).get-indices
        }
        return;
    }
    method is-my-iter($iter) {
        # $_.iter ne $iter # TODO doesn't work, why ?
        return $.iter.is-valid && $.iter-get-indices eq $ts.get-path($iter).get-indices;
    }
}

my Str $filename;

class OrgMode {
    has Str  @.preface is rw;
    has Task @.tasks   is rw;

    method delete-iter-task(Task $task) {
        $task.iter .=new;
        if $task.sub-tasks {
            for $task.sub-tasks.Array {
                $.delete-iter-task($_);
            }
        }
    }

    method delete-iter() {
        for $.tasks.Array {
            $.delete-iter-task($_);
        }
    }

    method inspect-task(Task $task) {
        say $task.iter-get-indices;
        if $task.sub-tasks {
            for $task.sub-tasks.Array {
                $.inspect-task($_);
            }
        }
    }

    method inspect() {
    say "begin inspect";
        for $.tasks.Array {
            $.inspect-task($_);
        }
    say "end inspect";
    }
}

my OrgMode $om .=new;

sub demo_procedural_read($name) {
    # TODO to remove, improve grammar/AST
    my token content2 { .*? $$ };

    for $name.IO.lines {
        if ($_~~/^"* "((["TODO"|"DONE"])" ")?<content2>/) { # header level 1
            my Task $task.=new(:header($<content2>.Str),:level(1));
            $task.todo=$0[0].Str if $0[0];
            push($om.tasks,$task);
        } elsif ($_~~/^"** "((["TODO"|"DONE"])" ")?<content2>/) { # headerlvl 2 TODO create recursive sub
            my $task=pop($om.tasks);
            my Task $sub-task.=new(:header($<content2>.Str),:level(2));
            $sub-task.todo=$0[0].Str if $0[0];
            push($task.sub-tasks,$sub-task);
            push($om.tasks,$task);
        } else {
            if ($om.tasks) {                                 # text in task
                my $task=pop($om.tasks);
                if !$task.sub-tasks {                # first task 
                    push($task.text,$_);
                } else {
                    my @so=$task.sub-tasks.Array;
                    my $sub-task=pop(@so);    
                    push($sub-task.text,$_);
                    push(@so,$sub-task);
                    $task.sub-tasks=@so;
                }
                push($om.tasks,$task);
            } else {                                     # preface
                push($om.preface,$_);
            }
        }
    }
    say $om.tasks;
#    say "after : \n", Dump $om.tasks;
}

#--------------------------- part GTK--------------------------------

my Gnome::Gtk3::Main $m .= new;
my Gnome::Gtk3::MessageDialog $md .=new(:message('Voulez-vous sauvez votre fichier ?'),:buttons(GTK_BUTTONS_YES_NO));

class X {
  method exit-gui ( --> Int ) {
        if $change && !$debug {
            if $md.run==-8 {
                save($filename);
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
        # now, only on the header 1
        $om.tasks = map {
            if $_.is-my-iter($iter) {
                my Task $task.=new(:header($e_add2.get-text),:todo("TODO"),:level(2));
                create_task($task,$iter);
                push($_.sub-tasks,$task);
            } ; $_
        }, $om.tasks;
        $dialog.gtk_widget_destroy;
    }
}

sub  search-task-in-org-from($iter) {
    my @org_tmp = grep { $_.is-my-iter($iter)}, $om.tasks;
    if (!@org_tmp) { # not found, find in sub
        for $om.tasks -> $task {    # for subtask, find a recusive method
            if $task.sub-tasks && !@org_tmp {
                @org_tmp = grep { $_.is-my-iter($iter) }, $task.sub-tasks.Array;
            }
        }
    }
    if @org_tmp {
        return pop(@org_tmp);   # if click on a task
    } else {
        return;                 # if click on text 
    }
}

sub delete-branch($iter) {
    $change=1;
    $om.tasks = grep { !$_.is-my-iter($iter) }, $om.tasks;   # keep all else $iter

    # for subtask, find a recusive method
    for $om.tasks -> $task {
        my @org_sub;
        if $task.sub-tasks {
            for $task.sub-tasks.Array {
                push(@org_sub,$_) if !$_.is-my-iter($iter); 
            }
        }
        if @org_sub {
            $task.sub-tasks=@org_sub;
        } else {
            $task.sub-tasks:delete;
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
        return $i if $_.is-my-iter($iter);
        }
    return -1;
}

sub update-text($iter,$new-text) {
    my $task=search-task-in-org-from($iter);
    $task.text=$new-text.split(/\n/);
    my $iter_child=$ts.iter-children($iter);
    # remove all lines "text"
    while $iter_child.is-valid && !search-task-in-org-from($iter_child) { # if no task associate to a task, it's a "text"
        delete-branch($iter_child);
        $iter_child=$ts.iter-children($iter);
    }
    if $task.text {
        for $task.text.Array.reverse {
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
        save($filename);
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
                save($filename);
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
            $om.tasks=[]; 
            $om.preface=[]; 
            $filename = $dialog.get-filename;
            open-file($filename) if $filename;
        }
        $dialog.gtk-widget-hide;
        1
    }

    method file-quit( ) {
        if $change && !$debug {
            if $md.run==-8 {
                save($filename);
            }
            $md.destroy;
        }
        $m.gtk-main-quit;
    }
    method debug-inspect( ) {
        $om.inspect();
    }
    method option-presentation( ) {
        $presentation=!$presentation;
        reconstruct_tree();
        1
    }
    method option-no-done( ) {
        $no-done=!$no-done;
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
            my Task $task.=new(:header($e_add.get-text),:todo('TODO'),:level(1));
            $e_add.set-text("");
            $task=create_task($task);
            $om.tasks.push($task);
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
                    $om.tasks[@path[*-1],@path2[*-1]] = $om.tasks[@path2[*-1],@path[*-1]];
                } else {                # more difficult that level 1, because "text" is not movable
                    my $task2=search-task-in-org-from($iter2);
                    if $task2 {              # if not, probably text et no swap 
                        $ts.swap($iter,$iter2);
                        my $tp=$ts.get-path($iter);
                        $tp.up; # transform in parent
                        my $iter-parent = $ts.get-iter($tp);
                        my $t_parent=search-task-in-org-from($iter-parent);
                        my $line=search-indice-in-sub-task-from($iter,$t_parent.sub-tasks.Array);
                        my $line2=search-indice-in-sub-task-from($iter2,$t_parent.sub-tasks.Array);
                        $t_parent.sub-tasks[$line,$line2] = $t_parent.sub-tasks[$line2,$line];
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
                    $om.tasks[@path[*-1],@path2[*-1]] = $om.tasks[@path2[*-1],@path[*-1]];
                } else {                # more difficult that level 1, because "text" is not movable
                    my $task2=search-task-in-org-from($iter2);
                    if $task2 {              # if not, probably text et no swap 
                        $ts.swap($iter,$iter2);
                        my $tp=$ts.get-path($iter);
                        $tp.up; # transform in parent
                        my $iter-parent = $ts.get-iter($tp);
                        my $t_parent=search-task-in-org-from($iter-parent);
                        my $line=search-indice-in-sub-task-from($iter,$t_parent.sub-tasks.Array);
                        my $line2=search-indice-in-sub-task-from($iter2,$t_parent.sub-tasks.Array);
                        $t_parent.sub-tasks[$line,$line2] = $t_parent.sub-tasks[$line2,$line];
                    }
                }
            }
        }
        1
    }
    method edit-button-click ( :$iter ) {
        $change=1;
        my $task=search-task-in-org-from($iter);
        $task.header=$e_edit.get-text;
        $ts.set_value( $iter, 0,search-task-in-org-from($iter).display-header);
        $dialog.gtk_widget_destroy;
        1
    }
    method todo-button-click ( :$iter,:$todo --> Int ) {
        my Task $task;
        if ($toggle_rb) {  # see definition 
            $change=1;
        my $task=search-task-in-org-from($iter);
        $task.todo=$todo;
            $ts.set_value( $iter, 0,search-task-in-org-from($iter).display-header);
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
            my $task=search-task-in-org-from($iter);

            # to move
            $b_move_up  .= new(:label('^'));
            $content-area.gtk_container_add($b_move_up);
            b_move_up-register-signal($iter);
            $b_move_down  .= new(:label('v'));
            $content-area.gtk_container_add($b_move_down);
            b_move_down-register-signal($iter);

            # To edit task
            $e_edit  .= new();
            $e_edit.set-text($task.header);
            $content-area.gtk_container_add($e_edit);
            $b_edit  .= new(:label('Update task'));
            $content-area.gtk_container_add($b_edit);
            b_edit-register-signal($iter);
            
            # To edit text
            $tev_edit_text .= new;
            $text-buffer .= new(:native-object($tev_edit_text.get-buffer));
            if $task.text {
                my $text=$task.text.join("\n");
                $text-buffer.set-text($text);
            }
            $content-area.gtk_container_add($tev_edit_text);
            $b_edit_text  .= new(:label('Update text'));
            $content-area.gtk_container_add($b_edit_text);
            b_edit_text-register-signal($iter);
            
            # To manage TODO/DONE
            $task=search-task-in-org-from($iter);
            my Gnome::Gtk3::Grid $g_todo .= new;
            $content-area.gtk_container_add($g_todo);
            $rb_td1 .= new(:label('-'));
            $rb_td2 .= new( :group-from($rb_td1), :label('TODO'));
            $rb_td3 .= new( :group-from($rb_td1), :label('DONE'));
            if    !$task.todo          { $rb_td1.set-active(1);}
            elsif $task.todo eq 'TODO' { $rb_td2.set-active(1);}
            elsif $task.todo eq 'DONE' { $rb_td3.set-active(1);} 
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
    $menu-item .= new(:label("_No Done"));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, 'option-no-done', 'activate');
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

sub create_task(Task $task, Gnome::Gtk3::TreeIter $iter?) {
    if !($task.todo && $task.todo eq 'DONE') || !$no-done {
        my Gnome::Gtk3::TreeIter $parent-iter;
        if (!$iter) {
            my Gnome::Gtk3::TreePath $tp .= new(:string($i++.Str));
            $parent-iter = $ts.get-iter($tp);
        } else {
            $parent-iter = $iter;
        }
        my Gnome::Gtk3::TreeIter $iter_task;
        $iter_task = $ts.insert-with-values($parent-iter, -1, 0, $task.display-header);
        if $task.text {
            for $task.text.Array {
                 my Gnome::Gtk3::TreeIter $iter_t2 = $ts.insert-with-values($iter_task, -1, 0, $_) 
            }
        }
        $task.iter=$iter_task;

        if $task.sub-tasks {
            for $task.sub-tasks.Array {
                create_task($_,$iter_task);
            }
        }
    }
    return $task;
}
#-----------------------------------sub-------------------------------
sub reconstruct_tree { # not good practice, not abuse
    $i=0;
    $ts.clear();
    $om.delete-iter();
    populate_task();
}

sub populate_task {
    $om.tasks = map {create_task($_)}, $om.tasks;
#    say "after create task : \n",$om.tasks;
}

sub open-file($name) {
    spurt $name~".bak",slurp $name; # fast backup
    demo_procedural_read($name);
    populate_task();
}

sub save_task($task) {
    my $orgmode="";
#say $task;
#say $task.level;
    $orgmode~=join(" ",grep {$_}, ("*" x $task.level,$task.todo,$task.header))~"\n";
    if ($task.text) {
        for $task.text.Array {
            $orgmode~=$_~"\n";
        }
    }
    if $task.sub-tasks {
        for $task.sub-tasks.Array {
            $orgmode~=save_task($_);
        }
    }
    return $orgmode;
}

sub save($name) {
    my $orgmode="";
    for $om.preface {
        $orgmode~=$_~"\n";
    }
    for $om.tasks -> $task {
        $orgmode~=save_task($task);
    }
	spurt $name, $orgmode;
}

#--------------------------main--------------------------------

sub MAIN($arg = '') {
    $filename=$arg;
    open-file($filename) if $filename;
    $m.gtk-main;
}
