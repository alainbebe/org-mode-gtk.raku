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
my $toggle_rb_pr=False; # when click on a radio-buttun we have 2 signals. Take only the second
my $presentation=True;  # presentation in mode TODO or Textual
my $no-done=True;       # display with no DONE
my $i=0;                # for creation of level1 in tree
my Str $filename;
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
my Gnome::Gtk3::TreeView $tv .= new(:model($ts));

#----------------------- class Task & OrgMode
#use lib ".";
#use Task;
class Task {
    has Int  $.level     is rw;
    has Str  $.todo      is rw;
    has Str  $.priority  is rw;
    has Str  $.header    is rw; #  is required
    has Str  @.tags      is rw;
    has Str  @.text      is rw;
    has Task @.tasks is rw;

    method display-header {
        my $display;
        if $presentation {
            if (!$.todo)             {$display~=' '}
            elsif ($.todo eq "TODO") {$display~='<span foreground="red"  > TODO</span>'}
            elsif ($.todo eq "DONE") {$display~='<span foreground="green"> DONE</span>'}

            if $.priority {
                if    $.priority ~~ /A/ {$display~=' <span foreground="fuchsia">'~$.priority~'</span>'}
                elsif $.priority ~~ /B/ {$display~=' <span foreground="grey">'~$.priority~'</span>'}
                elsif $.priority ~~ /C/ {$display~=' <span foreground="lime">'~$.priority~'</span>'}
            }

            if    ($.level==1) {$display~='<span weight="bold" foreground="blue" > '~$.header~'</span>'}
            elsif ($.level==2) {$display~='<span weight="bold" foreground="brown"> '~$.header~'</span>'}
            else               {$display~='<span weight="bold" foreground="black"> '~$.header~'</span>'}

            if $.tags {
                $display~=' <span foreground="grey">'~$.tags~'</span>';
            }

        } else {
            if    ($.level==1) {$display~='<span foreground="blue" size="xx-large"      >'~$.header~'</span>'}
            elsif ($.level==2) {$display~='<span foreground="deepskyblue" size="x-large">'~$.header~'</span>'}
            else               {$display~='<span foreground="black" size="x-large"      >'~$.header~'</span>'}
        }
        return $display;
    }
    method level-move($change) {
        $.level+=$change;
        if $.tasks {
            for $.tasks.Array {
                $_.level-move($change);
            }
        }
    }
    #my $j=0;
    method to_text() {
        #say $j++,"-" x $.level," ",$.header," ";
        my $orgmode="";
        if $.level>0 {  # skip for the primary task $om
            $orgmode~="*" x $.level~" ";
            $orgmode~=$.todo~" " if $.todo;
            $orgmode~="\["~$.priority~"\] " if $.priority;
            $orgmode~=$.header;
            $orgmode~=" :"~join(':',$.tags)~':' if $.tags;
            $orgmode~="\n";
        }
        if ($.text) {
            for $.text.Array {
                $orgmode~=$_~"\n";
            }
        }
        if $.tasks {
            for $.tasks.Array {
                $orgmode~=$_.to_text;
            }
        }
        #$j--;
        return $orgmode;
    }
}
class GtkTask is Task {
    has Gnome::Gtk3::TreeIter $.iter is rw;

    method iter-get-indices { # find indices IN treestore, not tasks
        if $.iter.defined && $.iter.is-valid {
            return  $ts.get-path($.iter).get-indices
        }
        return;
    }
    method is-my-iter($iter) {
        # $_.iter ne $iter # TODO doesn't work, why ?
        return $.iter && $.iter.is-valid && $.iter-get-indices eq $ts.get-path($iter).get-indices;
    }
    method delete-iter() {
        $.iter .=new;
        if $.tasks {
            for $.tasks.Array {
                $_.delete-iter();
            }
        }
    }
    my $lvl=0;
    method inspect() {
        say "ind : ",$.iter-get-indices, " lvl ",$lvl," ",$.header, " level ",$.level; # TODO filter on the primary task
        if $.tasks {
            for $.tasks.Array {
                $lvl++;
                $_.inspect();
                $lvl--;
            }
        }
    }
    method search-task-from($iter) {
        if $.is-my-iter($iter) {
            return self;
        } else {
            if $.tasks {
                for $.tasks.Array {
                    my $find=$_.search-task-from($iter);
                    return $find if $find;
                }
            }
        }
        return;                 # if click on text 
    }
    method delete-branch($iter) {
        $change=1;
        my $task=$.search-task-from($iter);
        my $task-parent=$.parent($task);
        $task-parent.tasks = grep { !$_.is-my-iter($iter) }, $task-parent.tasks;
        $ts.gtk-tree-store-remove($iter);
    }
    method expand-row {
        $tv.expand-row($ts.get-path($.iter),1);
    }
    method create_task(Gnome::Gtk3::TreeIter $iter?,$pos = -1) {
        my Gnome::Gtk3::TreeIter $iter_task;
        if !($.todo && $.todo eq 'DONE') || !$no-done {
            my Gnome::Gtk3::TreeIter $parent-iter;
            if ($.level>0) {
                if ($.level==1) {
                    my Gnome::Gtk3::TreePath $tp .= new(:string($i++.Str));
                    $parent-iter = $ts.get-iter($tp);
                } else {
                    $parent-iter = $iter;
                }
                $iter_task = $ts.insert-with-values($parent-iter, $pos, 0, $.display-header);
                if $.text {
                    for $.text.Array {
                         my Gnome::Gtk3::TreeIter $iter_t2 = $ts.insert-with-values($iter_task, -1, 0, $_) 
                    }
                }
                $.iter=$iter_task;
            }
            if $.tasks {
                for $.tasks.Array {
                    $_.create_task($iter_task);
                }
            }
        }
    }
    method parent($task) {
        my @path= $ts.get-path($task.iter).get-indices.Array;
        my @path-parent=@path;
        pop(@path-parent);
        return self if !@path-parent;   # level 0
        my $iter-parent=get-iter-from-path(@path-parent);
        return $.search-task-from($iter-parent);
    }
    method search-indice($task) { # it's the indice on my tree, not Gtk::Tree
        # TODO to improve
        my $i=-1;
        if $.parent($task).tasks {
            for $.parent($task).tasks.Array {
                $i++;
                return $i if $_.is-my-iter($task.iter);
            }
        }
        return -1;
    }
    method swap($task1,$task2) {
        my $t_parent=$.parent($task1);
        my $line1=$.search-indice($task1);
        my $line2=$.search-indice($task2);
        $t_parent.tasks[$line1,$line2] = $t_parent.tasks[$line2,$line1];
    }
    method default {
        my GtkTask $task.=new(:header("In the beginning was the Task"),:todo('TODO'),:level(1));
        $task.create_task();
        $.tasks.push($task);
    }
}
my GtkTask $om .=new(:level(0));
sub demo_procedural_read($name) {
    # TODO to remove, improve grammar/AST
    my @last=[$om]; # list of last task by level
    my $last=$om;   # last task for 'text'
    for $name.IO.lines {
        if $_~~ /^("*")+" " ((["TODO"|"DONE"])" ")? (\[(\#[A|B|C])\]" ")? (.*?) (" "(\:.*))? $/ { # header level 1
            my $level=$0.elems;
            my GtkTask $task.=new(:header($3.Str),:level($level));
            $task.todo    =$1[0].Str if $1[0];
            $task.priority=$2[0].Str if $2[0];
            $task.tags=split(/\:/,$4[0])[1..^*-1] if $4[0];
            push(@last[$level-1].tasks,$task);
            @last[$level]=$task;
            $last=$task;
        } else {
            push($last.text,$_);
            $presentation = $_ ~~ /presentation\=True/ ?? True !! False if $_ ~~ /presentation/; # TODO move this line in a new "sub parse-property"
        }
    }
    #    say $om.tasks;
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
sub create-main-menu($title,Gnome::Gtk3::Menu $sub-menu) {
    my Gnome::Gtk3::MenuItem $but-file-menu .= new(:label($title));
    $but-file-menu.set-use-underline(1);
    $but-file-menu.set-submenu($sub-menu);
    return $but-file-menu;
}
my Gnome::Gtk3::MenuBar $menu-bar .= new;
$g.gtk_grid_attach( $menu-bar, 0, 0, 1, 1);
$menu-bar.gtk-menu-shell-append(create-main-menu('_File',make-menubar-list-file()));
$menu-bar.gtk-menu-shell-append(create-main-menu('_Option',make-menubar-list-option()));
$menu-bar.gtk-menu-shell-append(create-main-menu('_Debug',make-menubar-list-debug())) if $debug;
$menu-bar.gtk-menu-shell-append(create-main-menu('_Help',make-menubar-list-help()));

my Gnome::Gtk3::ScrolledWindow $sw .= new();
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
$about.set-authors(CArray[Str].new('Alain BarBason'));

my Gnome::Gtk3::Entry $e_add2;
my Gnome::Gtk3::Entry $e_edit;
my Gnome::Gtk3::Entry $e_edit_tags;
my Gnome::Gtk3::Entry $e_edit_text;
my Gnome::Gtk3::Dialog $dialog;
my Gnome::Gtk3::Button $b_del;
my Gnome::Gtk3::Button $b_add2;
my Gnome::Gtk3::Button $b_move_up;
my Gnome::Gtk3::Button $b_move_left;
my Gnome::Gtk3::Button $b_move_right;
my Gnome::Gtk3::Button $b_move_down;
my Gnome::Gtk3::Button $b_edit;
my Gnome::Gtk3::Button $b_edit_tags;
my Gnome::Gtk3::Button $b_edit_text;
my Gnome::Gtk3::RadioButton $rb_pr1;
my Gnome::Gtk3::RadioButton $rb_pr2;
my Gnome::Gtk3::RadioButton $rb_pr3;
my Gnome::Gtk3::RadioButton $rb_pr4;
my Gnome::Gtk3::RadioButton $rb_td1;
my Gnome::Gtk3::RadioButton $rb_td2;
my Gnome::Gtk3::RadioButton $rb_td3;
my Gnome::Gtk3::TextView $tev_edit_text;
my Gnome::Gtk3::TextBuffer $text-buffer;

my X $x .= new;
$top-window.register-signal( $x, 'exit-gui', 'destroy');
sub  add2-branch($iter-parent) {
    if $e_add2.get-text {
        $change=1;
        my $task-parent=$om.search-task-from($iter-parent);
        my GtkTask $task.=new(:header($e_add2.get-text),:todo("TODO"),:level($task-parent.level+1));
        $e_add2.set-text("");
        $task.create_task($iter-parent);
        push($task-parent.tasks,$task);
        $task-parent.expand-row();
    }
}
sub update-text($iter,$new-text) {
    my $task=$om.search-task-from($iter);
    $task.text=$new-text.split(/\n/);
    my $iter_child=$ts.iter-children($iter);
    # remove all lines "text"
    while $iter_child.is-valid && !$om.search-task-from($iter_child) { # if no task associate to a task, it's a "text"
        $om.delete-branch($iter_child);
        $iter_child=$ts.iter-children($iter);
    }
    if $task.text {
        for $task.text.Array.reverse {
             my Gnome::Gtk3::TreeIter $iter_t2 = $ts.insert-with-values($iter, 0, 0, $_) 
        }
        $task.expand-row();
    }
}
sub get-iter-from-path(@path) {
    my Gnome::Gtk3::TreePath $tp .= new(:indices(@path));
    return $ts.get-iter($tp);
}
sub brother($iter,$inc) {
    my @path2= $ts.get-path($iter).get-indices.Array;
    @path2[*-1]=@path2[*-1].Int;
    @path2[*-1]+=$inc;
    my Gnome::Gtk3::TreePath $tp .= new(:indices(@path2));
    return  $ts.get-iter($tp);
}
class AppSignalHandlers {
    has Gnome::Gtk3::Window $!top-window;
    submethod BUILD ( Gnome::Gtk3::Window :$!top-window ) { }
    method file-new ( --> Int ) {
        if $change && !$debug {
            if $md.run==-8 {
                save($filename);
            }
            $md.destroy;
        }
        $ts.clear();
        $om.tasks=[]; 
        $om.text=[]; 
        $om.default;
        1
    }
    method file-save( ) {
        $change=0;
        save($filename);
    }
    method file-save-test( ) {
        save("test.org");
        run 'cat','test.org';
        say "\n"; # yes, 2 lines.
    }
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
            $om.text=[]; 
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
            my GtkTask $task.=new(:header($e_add.get-text),:todo('TODO'),:level(1));
            $e_add.set-text("");
            $task.create_task($iter);
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
        1
    }
    method move-right-button-click ( :$iter ) {
        my @path= $ts.get-path($iter).get-indices.Array;
        return if @path[*-1] eq "0"; # first task doesn't go to left
        my $task=$om.search-task-from($iter);
        my @path-parent=@path;
        @path-parent[*-1]--;
        my $iter-parent=get-iter-from-path(@path-parent);
        my $task-parent=$om.search-task-from($iter-parent);
        $om.delete-branch($iter); 
        $task.level-move(1);
        push($task-parent.tasks,$task); 
        $task.create_task($iter-parent);
        $task-parent.expand-row;
        $dialog.gtk_widget_destroy; # remove when level 3
        1
    }
    method move-left-button-click ( :$iter ) {
        my $task=$om.search-task-from($iter);
        return if $task.level <= 1; # level 0 and 1 don't go to left
        my $task-parent=$om.parent($task);
        my @path-parent= $ts.get-path($task-parent.iter).get-indices.Array;
        my $task-grand-parent=$om.parent($task-parent);
        $task.level-move(-1);
        $om.delete-branch($iter); 
        my @tasks;
        for $task-grand-parent.tasks.Array {
            if $_ eq $task-parent {
                push(@tasks,$_);
                push(@tasks,$task);
            } else {
                push(@tasks,$_);
            } 
        }
        $task-grand-parent.tasks=@tasks;
        $task.create_task($task-grand-parent.iter,@path-parent[*-1]+1);
        $task.expand-row;
        $dialog.gtk_widget_destroy; # remove when level 3
        1
    }
    method move-up-down-button-click ( :$iter, :$inc  --> Int ) {
        my @path= $ts.get-path($iter).get-indices.Array;
        if !(@path[*-1] eq "0" && $inc==-1) {     # if is not the first child in treestore (because if have DONE hide) for up
            my $iter2=brother($iter,$inc);
            if $iter2.is-valid {   # if not, it's the last child
                $change=1;
                my $task=$om.search-task-from($iter);
                my $task2=$om.search-task-from($iter2);
                $ts.swap($iter,$iter2);
                $om.swap($task,$task2);
            }
        }
        1
    }
    method edit-button-click ( :$iter ) {
        $change=1;
        my $task=$om.search-task-from($iter);
        $task.header=$e_edit.get-text;
        $ts.set_value( $iter, 0,$om.search-task-from($iter).display-header);
        1
    }
    method edit-tags-button-click ( :$iter ) {
        $change=1;
        my $task=$om.search-task-from($iter);
        $task.tags=split(/" "/,$e_edit_tags.get-text);
        $ts.set_value( $iter, 0,$om.search-task-from($iter).display-header);
        1
    }
    method prior-button-click ( :$iter,:$prior --> Int ) {
        my GtkTask $task;
        if ($toggle_rb_pr) {  # see definition 
            $change=1;
            my $task=$om.search-task-from($iter);
            $task.priority=$prior??"#"~$prior!!"";
            $ts.set_value( $iter, 0,$om.search-task-from($iter).display-header);
        }
        $toggle_rb_pr=!$toggle_rb_pr;
        1
    }
    method todo-button-click ( :$iter,:$todo --> Int ) {
        my GtkTask $task;
        if ($toggle_rb) {  # see definition 
            $change=1;
            my $task=$om.search-task-from($iter);
            $task.todo=$todo;
            $ts.set_value( $iter, 0,$om.search-task-from($iter).display-header);
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
            if $task.text { # update display text
                my $text=$task.text.join("\n");
                $text-buffer.set-text($text);
            }
        }
        $toggle_rb=!$toggle_rb;
        1
    }
    method del-button-click ( :$iter --> Int ) {
        $om.delete-branch($iter);
        $dialog.gtk_widget_destroy;
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
        if $om.search-task-from($iter) {      # if not, it's a text not now editable 
            my $task=$om.search-task-from($iter);

            # to move
            $b_move_right  .= new(:label('>'));
            $content-area.gtk_container_add($b_move_right);
            b_move_right-register-signal($iter);
            $b_move_left  .= new(:label('<'));
            $content-area.gtk_container_add($b_move_left);
            b_move_left-register-signal($iter);

            $b_move_up  .= new(:label('^'));
            $content-area.gtk_container_add($b_move_up);
            $b_move_down  .= new(:label('v'));
            $content-area.gtk_container_add($b_move_down);
            b-move-up-down-register-signal($iter);

            # To edit task
            $e_edit  .= new();
            $e_edit.set-text($task.header);
            $content-area.gtk_container_add($e_edit);
            $b_edit  .= new(:label('Update task'));
            $content-area.gtk_container_add($b_edit);
            b_edit-register-signal($iter);
            
            # To edit tags
            $e_edit_tags  .= new();
            $e_edit_tags.set-text(join(" ",$task.tags));
            $content-area.gtk_container_add($e_edit_tags);
            $b_edit_tags  .= new(:label('Update tags'));
            $content-area.gtk_container_add($b_edit_tags);
            b_edit_tags-register-signal($iter);
            
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
            
            # To manage priority A,B,C.
            $task=$om.search-task-from($iter);
            my Gnome::Gtk3::Grid $g_prio .= new;
            $content-area.gtk_container_add($g_prio);
            $rb_pr1 .= new(:label('-'));
            $rb_pr2 .= new( :group-from($rb_pr1), :label('A'));
            $rb_pr3 .= new( :group-from($rb_pr1), :label('B'));
            $rb_pr4 .= new( :group-from($rb_pr1), :label('C'));
            if    !$task.priority          { $rb_pr1.set-active(1);}
            elsif $task.priority eq '#A' { $rb_pr2.set-active(1);}
            elsif $task.priority eq '#B' { $rb_pr3.set-active(1);} 
            elsif $task.priority eq '#C' { $rb_pr4.set-active(1);} 
            $g_prio.gtk-grid-attach( $rb_pr1, 0, 0, 1, 1);
            $g_prio.gtk-grid-attach( $rb_pr2, 1, 0, 1, 1);
            $g_prio.gtk-grid-attach( $rb_pr3, 2, 0, 1, 1);
            $g_prio.gtk-grid-attach( $rb_pr4, 3, 0, 1, 1);
            b_rb_prior-register-signal($iter);

            # To manage TODO/DONE
            $task=$om.search-task-from($iter);
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
            $b_del  .= new(:label('Delete task (and tasks)'));
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
sub b_rb_prior-register-signal($iter) {
    $rb_pr1.register-signal( $ash, 'prior-button-click', 'clicked',:iter($iter),:prior(""));
    $rb_pr2.register-signal( $ash, 'prior-button-click', 'clicked',:iter($iter),:prior("A"));
    $rb_pr3.register-signal( $ash, 'prior-button-click', 'clicked',:iter($iter),:prior("B"));
    $rb_pr4.register-signal( $ash, 'prior-button-click', 'clicked',:iter($iter),:prior("C"));
}
sub b_rb-register-signal($iter) {
    $rb_td1.register-signal( $ash, 'todo-button-click', 'clicked',:iter($iter),:todo(""));
    $rb_td2.register-signal( $ash, 'todo-button-click', 'clicked',:iter($iter),:todo("TODO"));
    $rb_td3.register-signal( $ash, 'todo-button-click', 'clicked',:iter($iter),:todo("DONE"));
}
sub b_move_right-register-signal ($iter) {
    $b_move_right.register-signal( $ash, 'move-right-button-click', 'clicked',:iter($iter));
}
sub b_move_left-register-signal ($iter) {
    $b_move_left.register-signal( $ash, 'move-left-button-click', 'clicked',:iter($iter));
}
sub b-move-up-down-register-signal ($iter) {
    $b_move_up.register-signal( $ash, 'move-up-down-button-click', 'clicked',:iter($iter),:inc(-1));
    $b_move_down.register-signal( $ash, 'move-up-down-button-click', 'clicked',:iter($iter),:inc(1));
}
sub b_edit-register-signal ($iter) {
    $b_edit.register-signal( $ash, 'edit-button-click', 'clicked',:iter($iter));
}
sub b_edit_tags-register-signal ($iter) {
    $b_edit_tags.register-signal( $ash, 'edit-tags-button-click', 'clicked',:iter($iter));
}
sub b_edit_text-register-signal ($iter) {
    $b_edit_text.register-signal( $ash, 'edit-text-button-click', 'clicked',:iter($iter));
}
sub create-sub-menu($menu,$name,$ash,$method) {
    my Gnome::Gtk3::MenuItem $menu-item .= new(:label($name));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, $method, 'activate');
} 
sub make-menubar-list-file( ) {
    my Gnome::Gtk3::Menu $menu .= new;
    create-sub-menu($menu,"_New",$ash,'file-new');
    create-sub-menu($menu,"_Save",$ash,'file-save');
    create-sub-menu($menu,"_Open",$ash,'file-open');
    create-sub-menu($menu,"Save to _test",$ash,'file-save-test');
    create-sub-menu($menu,"_Quit",$ash,'file-quit');
    $menu
}
sub make-menubar-list-option() {
    my Gnome::Gtk3::Menu $menu .= new;
    create-sub-menu($menu,"_Presentation",$ash,'option-presentation');
    create-sub-menu($menu,"_No DONE",$ash,'option-no-done');
    $menu
}
sub make-menubar-list-debug() {
    my Gnome::Gtk3::Menu $menu .= new;
    create-sub-menu($menu,"_Inspect",$ash,'debug-inspect');
    $menu
}
sub make-menubar-list-help ( ) {
    my Gnome::Gtk3::Menu $menu .= new;
    create-sub-menu($menu,"_About",$ash,'help-about');
    $menu
}
#--------------------------------interface---------------------------------
#-----------------------------------sub-------------------------------
sub reconstruct_tree { # not good practice, not abuse
    $i=0;
    $ts.clear();
    $om.delete-iter();
    populate_task();
}
sub populate_task {
    $om.create_task;
#    say "after create task : \n",$om.tasks;
}
sub open-file($name) {
    spurt $name~".bak",slurp $name; # fast backup
    demo_procedural_read($name);
    populate_task();
}
sub save($name) {
	spurt $name, $om.to_text;
}
#-----------------------------------main--------------------------------
sub MAIN($arg = '') {
    $top-window.show-all;
    $filename=$arg;
    $filename??open-file($filename)!!$om.default;
    $m.gtk-main;
}
