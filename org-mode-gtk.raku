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
use Gnome::Gtk3::CheckButton;
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
use Gnome::Gtk3::TreeSelection;
use Gnome::Gtk3::ComboBoxText;
use Gnome::Gdk3::Events;
use Gnome::Gdk3::Keysyms;
use NativeCall;

use Data::Dump;

use lib "lib";
use DateOrg;
use Task;
use GtkTask;
use GramOrgMode;
use GtkFile;

# global variable : to remove ?
my $debug=1;            # to debug =1
my $toggle-rb-pr=False; # TODO when click on a radio-buttun we have 2 signals. Take only the second
my $is-maximized=False; # TODO use gtk-window.is_maximized in Window.pm6 (uncomment =head2 [[gtk_] window_] is_maximized) :0.x:
my Gnome::Gtk3::TreeIter $iter;
my $is-return=False;    # memorize the return key

my Gnome::Gtk3::Main $m .= new;

my Gnome::Gtk3::Window $top-window .= new;
$top-window.set-title('Org-Mode with GTK and raku');
$top-window.set-default-size( 640, 480);

my Gnome::Gtk3::Grid $g .= new;
$top-window.gtk-container-add($g);

my GtkFile $gf.=new;
$g.gtk-grid-attach( $gf.sw, 0, 1, 4, 1);

my Gnome::Gtk3::Entry $e-add  .= new;
my Gnome::Gtk3::Button $b-add  .= new(:label('Add task'));
my Gnome::Gtk3::Label $l-del  .= new(:text('Click on task to manage'));
$g.gtk-grid-attach( $e-add, 0, 2, 1, 1);
$g.gtk-grid-attach( $b-add, 1, 2, 1, 1);
$g.gtk-grid-attach( $l-del, 2, 2, 1, 1);

my Gnome::Gtk3::AboutDialog $about .= new;
$about.set-program-name('org-mode-gtk.raku');
$about.set-version('0.1');
$about.set-license-type(GTK_LICENSE_GPL_3_0);
$about.set-website("http://www.barbason.be");
$about.set-website-label("http://www.barbason.be");
$about.set-authors(CArray[Str].new('Alain BarBason'));

# Global Gtk variable : to remove ?
my Gnome::Gtk3::Entry $e-add2;
my Gnome::Gtk3::Entry $e-edit-tags;
my Gnome::Gtk3::Entry $e-edit-text;
my Gnome::Gtk3::Dialog $dialog;
my Gnome::Gtk3::TextBuffer $text-buffer;
my GtkTask $selected-task;

class AppSignalHandlers {
    has Gnome::Gtk3::Window $!top-window;
    submethod BUILD ( Gnome::Gtk3::Window:D :$!top-window! ) { }

    method exit-gui ( --> Int ) {
        my $button=$gf.try-save($!top-window);
        $m.gtk-main-quit if $button != GTK_RESPONSE_CANCEL;
        1
    }
    multi method create-button($label,$method,$iter?,$inc?) {
        my Gnome::Gtk3::Button $b  .= new(:label($label));
        $b.register-signal(self, $method, 'clicked',:iter($iter),:inc($inc));
        return $b;
    }
    multi method create-button($label,$method,Gnome::Gtk3::Entry $entry) {
        my Gnome::Gtk3::Button $b  .= new(:label($label));
        $b.register-signal(self, $method, 'clicked',:edit($entry));
        return $b;
    }
    multi method create-button($label,$method,Str $text) {
        my Gnome::Gtk3::Button $b  .= new(:label($label));
        $b.register-signal(self, $method, 'clicked',:edit($text));
        return $b;
    }
    method create-check($method,Gnome::Gtk3::Entry $entry) {
        my Gnome::Gtk3::CheckButton $cb .= new;
        $cb.register-signal( self, $method, 'toggled',:edit($entry));
        return $cb;
    }
    method go-to-link ( :$edit ) {
#        my $proc = run '/opt/firefox/firefox', '--new-tab', $edit;
        shell "/opt/firefox/firefox --new-tab $edit";
        1
    }
    method time ( :$widget, :$edit ) {
        note " button  ",
         $widget.get-active.Bool ;
    }
    method today (:$edit) {
        my $ds=&d-now().Str.substr(0,14);
        my $ori=$edit.get-text;
        $ori ~~ s/^.**14/$ds/; # TODO not very good, but work
        $edit.set-text($ori); 
        1
    }
    method tomorrow (:$edit) {
        my $ds=&d-now().later(days => 1).Str.substr(0,14);
        my $ori=$edit.get-text;
        $ori ~~ s/^.**14/$ds/; # TODO not very good, but work
        $edit.set-text($ori); 
        1
    }
    method repeat-i (:$widget, :$edit, :$cbt) {
        $edit.get-text  ~~ /<dateorg>/;
        my DateOrg $d=date-from-dateorg($/{'dateorg'});
        if $widget.get-active-text ne "0" {
            $d.repeater="+"~$widget.get-active-text~$cbt.get-active-text;
        } else {
            $d.repeater="";
        }
        $edit.set-text($d.str); 
        1
    }
    method repeat-w (:$widget, :$edit, :$cbt) {
        $edit.get-text  ~~ /<dateorg>/;
        my DateOrg $d=date-from-dateorg($/{'dateorg'});
        if $cbt.get-active-text ne "0" {
            $d.repeater="+"~$cbt.get-active-text~$widget.get-active-text;
        } else {
            $d.repeater="";
        }
        $edit.set-text($d.str); 
        1
    }
    method delay-i (:$widget, :$edit, :$cbt) {
        $edit.get-text  ~~ /<dateorg>/;
        my DateOrg $d=date-from-dateorg($/{'dateorg'});
        if $widget.get-active-text ne "0" {
            $d.delay="-"~$widget.get-active-text~$cbt.get-active-text;
        } else {
            $d.delay="";
        }
        $edit.set-text($d.str); 
        1
    }
    method delay-w (:$widget, :$edit, :$cbt) {
        $edit.get-text  ~~ /<dateorg>/;
        my DateOrg $d=date-from-dateorg($/{'dateorg'});
        if $cbt.get-active-text ne "0" {
            $d.delay="-"~$cbt.get-active-text~$widget.get-active-text;
        } else {
            $d.delay="";
        }
        $edit.set-text($d.str); 
        1
    }
    method manage-date (DateOrg $date is rw) {
#say $date.begin;
        my Gnome::Gtk3::Dialog $dialog2 .= new(
            :title("Scheduling"), 
            :parent($!top-window),
            :flags(GTK_DIALOG_DESTROY_WITH_PARENT),
            :button-spec( [
                "_Ok", GTK_RESPONSE_OK,     # TODO rajouter un "delete"
                "_Cancel", GTK_RESPONSE_CANCEL,
            ] )
        );
        my Gnome::Gtk3::Box $content-area .= new(:native-object($dialog2.get-content-area));

        # entry
        my Gnome::Gtk3::Entry $e-edit-d .= new;
        $e-edit-d.set-text($date??$date.str!!&d-now());
        $content-area.gtk_container_add($e-edit-d);

        # 3 button
        my Gnome::Gtk3::Grid $g3 .= new;
        $content-area.gtk_container_add($g3);

        $g3.gtk-grid-attach( $.create-button('Today','today',$e-edit-d),            0, 0, 1, 1);
        $g3.gtk-grid-attach( $.create-button('Tomorrow','tomorrow',$e-edit-d),      1, 0, 1, 1);
#        $g3.gtk-grid-attach( $.create-button('Next Saturday','next-sat',$e-edit-d), 2, 0, 1, 1);

        # Time
        my Gnome::Gtk3::Grid $gt .= new;
        $content-area.gtk_container_add($gt);

#        $gt.gtk-grid-attach( Gnome::Gtk3::Label.new(:text('Time')),            0, 0, 1, 1);
#        $gt.gtk-grid-attach( $.create-button('Time','time',$e-edit-d),         0, 1, 1, 1);
#        $gt.gtk-grid-attach( $.create-check('time',$e-edit-d),                 1, 1, 1, 1);

#        $gt.gtk-grid-attach( Gnome::Gtk3::Label.new(:text('End time')),        2, 0, 1, 1);
#        $gt.gtk-grid-attach( $.create-button('End time','end-time',$e-edit-d), 2, 1, 1, 1);
#        $gt.gtk-grid-attach( $.create-check('end-time',$e-edit-d),             3, 1, 1, 1);

        $gt.gtk-grid-attach( Gnome::Gtk3::Label.new(:text('Repeat')),          0, 2, 1, 1);
        my Gnome::Gtk3::ComboBoxText $cbt-int .=new;
        $cbt-int.append-text("$_") for 0..10;
        $cbt-int.set-active(0);
        $gt.gtk-grid-attach( $cbt-int,                                         0, 3, 1, 1);
        my Gnome::Gtk3::ComboBoxText $cbt .=new;
        $cbt.append-text($_) for <d w m y>;
        $cbt.set-active(1);
        $gt.gtk-grid-attach( $cbt,                                             1, 3, 1, 1);
        $cbt-int.register-signal(self, 'repeat-i', 'changed',:edit($e-edit-d),:cbt($cbt));
        $cbt.register-signal(self, 'repeat-w', 'changed',:edit($e-edit-d),:cbt($cbt-int));

        $gt.gtk-grid-attach( Gnome::Gtk3::Label.new(:text('Delay')),           0, 4, 1, 1);
#        $gt.gtk-grid-attach( $.create-button('Delay','delay',$e-edit-d),       0, 5, 1, 1);
#        $gt.gtk-grid-attach( $.create-check('delay',$e-edit-d),                1, 5, 1, 1);

        my Gnome::Gtk3::ComboBoxText $cbt2-int .=new;
        $cbt2-int.append-text("$_") for 0..10;
        $cbt2-int.set-active(0);
        $gt.gtk-grid-attach( $cbt2-int,                                         0, 5, 1, 1);
        my Gnome::Gtk3::ComboBoxText $cbt2 .=new;
        $cbt2.append-text($_) for <d w m y>;
        $cbt2.set-active(1);
        $gt.gtk-grid-attach( $cbt2,                                             1, 5, 1, 1);
        $cbt2-int.register-signal(self, 'delay-i', 'changed',:edit($e-edit-d),:cbt($cbt2));
        $cbt2.register-signal(self, 'delay-w', 'changed',:edit($e-edit-d),:cbt($cbt2-int));

        $dialog2.show-all;
        my $response = $dialog2.gtk-dialog-run;
        if $response == GTK_RESPONSE_OK {
            my $ds=$e-edit-d.get-text;  # date string
            if $ds ~~ /<dateorg>/ {
                $date=date-from-dateorg($/{'dateorg'});
            } else {
                say "erreur de format";
            }
        }
        $dialog2.gtk_widget_destroy;
        return $date;
    }
    method file-new ( --> Int ) {
        $gf.ts.clear;
        $gf.om.tasks=[]; 
        $gf.om.text=[]; 
        $gf.om.properties=(); # TODO use undefined ?
        $gf.om.header = "";
        $!top-window.set-title('Org-Mode with GTK and raku');
        $gf.default;
        1
    }
    method file-open ( --> Int ) {
        $gf.try-save($!top-window); # TODO check return button cancel :0.1:
        my Gnome::Gtk3::FileChooserDialog $dialog .= new(
            :title("Open File"), 
            :action(GTK_FILE_CHOOSER_ACTION_SAVE),
            :button-spec( [
                "_Cancel", GTK_RESPONSE_CANCEL,
                "_Open", GTK_RESPONSE_ACCEPT
            ] )
        );
        my $response = $dialog.gtk-dialog-run;
        if $response ~~ GTK_RESPONSE_ACCEPT {
            $gf.ts.clear;
            $gf.om.tasks=[]; 
            $gf.om.text=[]; 
            $gf.om.properties=(); # TODO use undefined ?
            $gf.om.header = $dialog.get-filename;
            $!top-window.set-title('Org-Mode with GTK and raku : ' ~ split(/\//,$gf.om.header).Array.pop) if $gf.om.header;
            self.open-file($gf.om.header) if $gf.om.header;
        }
        $dialog.gtk-widget-hide;
        1
    }
    method file-save {
        $gf.om.header ?? $gf.save !! $gf.file-save-as($!top-window);
    }
    method file-save-as {
        $gf.file-save-as($!top-window); # TODO [#A] change title of windows
        1
    }
    method file-save-test {
        $gf.save("test.org");
        run 'cat','test.org';
        say "\n"; # yes, 2 lines.
    }
    method edit-todo-done {
        if $selected-task {
            if $selected-task.todo eq "TODO" {
                self.todo-shortcut(:iter($selected-task.iter),:todo("DONE"));
            } elsif $selected-task.todo eq "DONE" {
                self.todo-shortcut(:iter($selected-task.iter),:todo(""))}
            else                                {
                self.todo-shortcut(:iter($selected-task.iter),:todo("TODO"));
            }
        }
    }
    method debug-inspect {
        $gf.om.inspect($gf.om);
    }
    method option-presentation { # TODO do this by task and not only for the entire tree
        $gf.change=1;
        if $gf.om.herite-properties('presentation') eq 'DEFAULT' || 
               $gf.om.herite-properties('presentation') eq 'TODO'  {
            $gf.om.properties.push(('presentation','TEXT'));
        } else {
            $gf.om.properties= map {$_[0] eq 'presentation' ?? ('presentation','TODO') !! $_}, $gf.om.properties;
        };
        $gf.reconstruct-tree;
        1
    }
    method option-no-done {
        $gf.no-done=!$gf.no-done;
        $gf.reconstruct-tree;
        1
    }
    method option-prior-A {
        $gf.prior-A=!$gf.prior-A;
        $gf.prior-B=False;
        $gf.prior-C=False;
        $gf.reconstruct-tree;
        $gf.prior-A??$gf.tv.expand-all!!$gf.tv.collapse-all;
        1
    }
    method option-prior-B {
        $gf.prior-B=!$gf.prior-B;
        $gf.prior-A=False;
        $gf.prior-C=False;
        $gf.reconstruct-tree;
        $gf.prior-B??$gf.tv.expand-all!!$gf.tv.collapse-all;
        1
    }
    method option-prior-C {
        $gf.prior-C=!$gf.prior-C;
        $gf.prior-A=False;
        $gf.prior-B=False;
        $gf.reconstruct-tree;
        $gf.prior-C??$gf.tv.expand-all!!$gf.tv.collapse-all;
        1
    }
    method view-fold-all {
        $gf.tv.collapse-all;
        1
    }
    method view-unfold-all {
        $gf.tv.expand-all;
        1
    }
    method help-about {
        $about.gtk-dialog-run;
        $about.gtk-widget-hide;
    }
    method add-button-click  {
        if $e-add.get-text {
            $gf.change=1;
            my GtkTask $task.=new(:header($e-add.get-text),:todo('TODO'),:level(1),:darth-vader($gf.om));
            $e-add.set-text("");
            $gf.create-task($task);
            $gf.om.tasks.push($task);
        }
        1
    }
    method add2-button-click ( :$iter --> Int ) {
        if $e-add2.get-text {
            $gf.change=1;
            my $task=$gf.search-task-from($gf.om,$iter);
            my GtkTask $child.=new(:header($e-add2.get-text),:todo("TODO"),:level($task.level+1),:darth-vader($task));
            $e-add2.set-text("");
            $gf.create-task($child,$iter);
            push($task.tasks,$child);
            $gf.expand-row($task,0);
        }
        1
    }
    method edit-preface {
        $gf.change=1;
        my Gnome::Gtk3::TextIter $start = $text-buffer.get-start-iter;
        my Gnome::Gtk3::TextIter $end = $text-buffer.get-end-iter;
        my $new-text=$text-buffer.get-text( $start, $end, 0);
        $gf.om.text=$new-text.split(/\n/);
        1
    }
    method move-right-button-click {
        my $iter=$selected-task.iter;
        my @path= $gf.ts.get-path($iter).get-indices.Array;
        return if @path[*-1] eq "0"; # first task doesn't go to left
        my $task=$gf.search-task-from($gf.om,$iter);
        my @path-parent=@path; # it's not the parent (darth-vader) but the futur parent
        @path-parent[*-1]--;
        my $iter-parent=$gf.get-iter-from-path(@path-parent);
        my $task-parent=$gf.search-task-from($gf.om,$iter-parent);
        $gf.delete-branch($iter); 
        $task.level-move(1);
        push($task-parent.tasks,$task); 
        $gf.create-task($task,$iter-parent);
        $task.darth-vader=$task-parent;
        $gf.expand-row($task-parent,0);
        my Gnome::Gtk3::TreeSelection $tselect .= new(:treeview($gf.tv));
        $tselect.select-iter($task.iter);
        $selected-task=$task;
        1
    }
    method move-left-button-click {
        my $iter=$selected-task.iter;
        my $task=$gf.search-task-from($gf.om,$iter);
        return if $task.level <= 1; # level 0 and 1 don't go to left
        $task.level-move(-1);
        $gf.delete-branch($iter); 
        my @tasks;
        for $task.darth-vader.darth-vader.tasks.Array {
            if $_ eq $task.darth-vader {
                push(@tasks,$_);
                push(@tasks,$task);
            } else {
                push(@tasks,$_);
            } 
        }
        $task.darth-vader.darth-vader.tasks=@tasks;
        my @path-parent= $gf.ts.get-path($task.darth-vader.iter).get-indices.Array;
        $gf.create-task($task,$task.darth-vader.darth-vader.iter,@path-parent[*-1]+1);
        $task.darth-vader=$task.darth-vader.darth-vader;
        $gf.expand-row($task,0);
        my Gnome::Gtk3::TreeSelection $tselect .= new(:treeview($gf.tv));
        $tselect.select-iter($task.iter);
        $selected-task=$task;
        1
    }
    method move-up-down-button-click ( :$inc --> Int ) { # TODO I don't pass iter as parameter. To improve
        my $iter=$selected-task.iter;
        my @path= $gf.ts.get-path($iter).get-indices.Array;
        if !(@path[*-1] eq "0" && $inc==-1) {     # if is not the first child in treestore (because if have DONE hide) for up
            my $iter2=$gf.brother($iter,$inc);
            if $iter2.is-valid {   # if not, it's the last child
                $gf.change=1;
                my $task=$gf.search-task-from($gf.om,$iter);
                my $task2=$gf.search-task-from($gf.om,$iter2);
                $gf.ts.swap($iter,$iter2);
                $gf.swap($task,$task2);
                my Gnome::Gtk3::TreeSelection $tselect .= new(:treeview($gf.tv));
                $tselect.select-iter($task.iter);
            }
        }
        1
    }
    method scheduled ( :$iter ) {
        my $task=$gf.search-task-from($gf.om,$iter);
        $task.scheduled=self.manage-date($task.scheduled);
        1
    }
    method deadline ( :$iter ) {
        my $task=$gf.search-task-from($gf.om,$iter);
        $task.deadline=self.manage-date($task.deadline);
        1
    }
    method clear-tags-button-click ( :$iter ) {
        $e-edit-tags.set-text("");
        1
    }
    method prior-button-click ( :$iter,:$prior --> Int ) {
        my GtkTask $task;
        if ($toggle-rb-pr) {  # see definition 
            $gf.change=1;
            my $task=$gf.search-task-from($gf.om,$iter);
            $task.priority=$prior??"#"~$prior!!"";
            $gf.ts.set_value( $iter, 0,$gf.search-task-from($gf.om,$iter).display-header);
        }
        $toggle-rb-pr=!$toggle-rb-pr;
        1
    }
    method todo-shortcut ( :$iter,:$todo --> Int ) {
        $gf.change=1;
        my GtkTask $task=$gf.search-task-from($gf.om,$iter);
        $task.todo=$todo;
        $gf.ts.set_value( $iter, 0,$task.display-header);
        if $todo eq 'DONE' {
            my $ds=&d-now();
            if $ds ~~ /<dateorg>/ {
                $task.closed=date-from-dateorg($/{'dateorg'});
            }
        } else {
            $task.closed=DateOrg;
        }
        1
    }
    method del-button-click {
        $gf.change=1;
        $gf.delete-branch($selected-task.iter);
        1
    }
    method del-children-button-click {
        $gf.change=1;
        if $gf.search-task-from($gf.om,$selected-task.iter) {      # if not, it's a text not now() editable 
            my $task=$gf.search-task-from($gf.om,$selected-task.iter);
            if $task.tasks {
                for $task.tasks.Array {
                    $gf.ts.gtk-tree-store-remove($_.iter) if $_.iter;
                }
                $task.tasks = [];
            }
        }
        1
    }
    method fold-branch {
        $gf.tv.collapse-row($gf.ts.get-path($selected-task.iter));
        1
    }
    method unfold-branch {
        $gf.tv.expand-row($gf.ts.get-path($selected-task.iter),0);
        1
    }
    method unfold-branch-child {
        $gf.tv.expand-row($gf.ts.get-path($selected-task.iter),1); # TODO merge with unfold-branch :refactoring:
        1
    }
    method manage($task) {
        # Dialog to manage task
        $dialog .= new(             # TODO try to pass dialog as parameter
            :title("Manage task"),  # TODO doesn't work if multi-tab. Very strange. Fix in :0.x:
            :parent($!top-window),
            :flags(GTK_DIALOG_DESTROY_WITH_PARENT),
            :button-spec( [
                "_Ok", GTK_RESPONSE_OK,
                "_Cancel", GTK_RESPONSE_CANCEL,
                ] )                    # TODO Add a button "Apply"
        );
        my Gnome::Gtk3::Box $content-area .= new(:native-object($dialog.get-content-area));
        my Gnome::Gtk3::Grid $g .= new;
        $content-area.gtk_container_add($g);

        # To edit task
        my Gnome::Gtk3::Entry $e-edit .= new;
        $e-edit.set-text($task.header);
        $g.gtk-grid-attach($e-edit,                                                       0, 0, 4, 1);

        # To edit tags
        $e-edit-tags  .= new;
        $e-edit-tags.set-text(join(" ",$task.tags));
        $g.gtk-grid-attach(Gnome::Gtk3::Label.new(:text('Tag')),                          0, 1, 1, 1);
        $g.gtk-grid-attach($e-edit-tags,                                                  1, 1, 2, 1);
        $g.gtk-grid-attach($.create-button('X','clear-tags-button-click',$task.iter),     3, 1, 1, 1);
        
        # To manage TODO/DONE
        my Gnome::Gtk3::RadioButton $rb-td1 .= new(:label('-'));
        my Gnome::Gtk3::RadioButton $rb-td2 .= new( :group-from($rb-td1), :label('TODO'));
        my Gnome::Gtk3::RadioButton $rb-td3 .= new( :group-from($rb-td1), :label('DONE'));
        if    !$task.todo          { $rb-td1.set-active(1);}
        elsif $task.todo eq 'TODO' { $rb-td2.set-active(1);}
        elsif $task.todo eq 'DONE' { $rb-td3.set-active(1);} 
        $g.gtk-grid-attach( $rb-td2,                                                        0, 2, 1, 1);
        $g.gtk-grid-attach( $rb-td3,                                                        1, 2, 1, 1);
        $g.gtk-grid-attach( $rb-td1,                                                        3, 2, 1, 1);

        # To manage priority A,B,C.
        my Gnome::Gtk3::RadioButton $rb-pr1 .= new(:label('-'));
        my Gnome::Gtk3::RadioButton $rb-pr2 .= new( :group-from($rb-pr1), :label('A'));
        my Gnome::Gtk3::RadioButton $rb-pr3 .= new( :group-from($rb-pr1), :label('B'));
        my Gnome::Gtk3::RadioButton $rb-pr4 .= new( :group-from($rb-pr1), :label('C'));
        if   !$task.priority         { $rb-pr1.set-active(1);}
        elsif $task.priority eq '#A' { $rb-pr2.set-active(1);}
        elsif $task.priority eq '#B' { $rb-pr3.set-active(1);} 
        elsif $task.priority eq '#C' { $rb-pr4.set-active(1);} 
        $g.gtk-grid-attach( $rb-pr2,                                                        0, 3, 1, 1);
        $g.gtk-grid-attach( $rb-pr3,                                                        1, 3, 1, 1);
        $g.gtk-grid-attach( $rb-pr4,                                                        2, 3, 1, 1);
        $g.gtk-grid-attach( $rb-pr1,                                                        3, 3, 1, 1);
        $rb-pr1.register-signal(self, 'prior-button-click', 'clicked',:iter($task.iter),:prior(""));
        $rb-pr2.register-signal(self, 'prior-button-click', 'clicked',:iter($task.iter),:prior("A"));
        $rb-pr3.register-signal(self, 'prior-button-click', 'clicked',:iter($task.iter),:prior("B"));
        $rb-pr4.register-signal(self, 'prior-button-click', 'clicked',:iter($task.iter),:prior("C"));

        my $label='Scheduling';
        $label~=' : '~$task.scheduled.str if $task.scheduled;
        $g.gtk-grid-attach($.create-button($label,'scheduled',$task.iter,1),            0, 4, 4, 1);
        $label='Deadline';
        $label~=' : '~$task.deadline.str if $task.deadline;
        $g.gtk-grid-attach($.create-button($label,'deadline',$task.iter,1),               0, 5, 4, 1);
        
        # To edit properties
        $content-area.gtk_container_add(Gnome::Gtk3::Label.new(:text('Properties')));
        my Gnome::Gtk3::TextView $tev-edit-prop .= new;
        my Gnome::Gtk3::TextBuffer $prop-buffer .= new(:native-object($tev-edit-prop.get-buffer));
        if $task.properties {
            my $text=$task.properties.join("\n");
            $prop-buffer.set-text($text);
        }
        my Gnome::Gtk3::ScrolledWindow $swp .= new;
        $swp.gtk-container-add($tev-edit-prop);
        $content-area.gtk_container_add($swp);
        
        # To edit text
        $content-area.gtk_container_add(Gnome::Gtk3::Label.new(:text('Content')));
        my Gnome::Gtk3::TextView $tev-edit-text .= new;
        my Gnome::Gtk3::TextBuffer $text-buffer2 .= new(:native-object($tev-edit-text.get-buffer));
        if $task.text {
            my $text=$task.text.join("\n");
            $text-buffer2.set-text($text);
        }
        my Gnome::Gtk3::ScrolledWindow $swt .= new;
        $swt.gtk-container-add($tev-edit-text);
        $content-area.gtk_container_add($swt);
        if $task.text {
            my $text=$task.text.join("\n");
            $text ~~ /(http:..\S*)/;
            $content-area.gtk_container_add($.create-button('Goto to link','go-to-link',$0.Str)) if $0;
        }
        
        # To add a sub-task
        $e-add2  .= new;
        $content-area.gtk_container_add($e-add2);
        $content-area.gtk_container_add($.create-button('Add sub-task','add2-button-click',$task.iter));
        
        # Show the dialog.
        $dialog.show-all;
        my $response = $dialog.gtk-dialog-run;
        if $response == GTK_RESPONSE_OK {
            if ($task.header ne $e-edit.get-text) {
                $gf.change=1;
                $task.header=$e-edit.get-text;
                $gf.ts.set_value( $task.iter, 0,$task.display-header);
            }
            if ($e-edit-tags.get-text ne join(" ",$task.tags)) {
                $gf.change=1;
                $task.tags=split(/" "/,$e-edit-tags.get-text);
                $gf.ts.set_value( $task.iter, 0,$task.display-header);
            }
            my $todo="";
            $todo="TODO" if $rb-td2.get-active();
            $todo="DONE" if $rb-td3.get-active();
            if $task.todo ne $todo {
                $gf.change=1;
                $task.todo=$todo;
                $gf.ts.set_value( $task.iter, 0,$task.display-header);
                if $todo eq 'DONE' {
                    my $ds=&d-now();
                    if $ds ~~ /<dateorg>/ {
                        $task.closed=date-from-dateorg($/{'dateorg'});
                    }
                } else {
                    $task.closed=DateOrg;
                }
            }
            my Gnome::Gtk3::TextIter $start = $text-buffer2.get-start-iter;
            my Gnome::Gtk3::TextIter $end = $text-buffer2.get-end-iter;
            my $new-text=$text-buffer2.get-text( $start, $end, 0);
#            if ($new-text ne $task.text.join("\n")) {
#                $gf.change=1;
#                $gf.update-text($task.iter,$new-text);
#            }
            $start = $prop-buffer.get-start-iter;
            $end = $prop-buffer.get-end-iter;
            $new-text=$prop-buffer.get-text( $start, $end, 0);
            if ($new-text ne $task.properties.join("\n")) {
                $gf.change=1;
                $task.properties=map {$_.split(/" "/)},$new-text.split(/\n/);
            }
        }
        $dialog.gtk_widget_destroy;
    }
    my @ctrl-keys;
    method tv-button-click (N-GtkTreePath $path, N-GObject $column ) {
        my Gnome::Gtk3::TreePath $tree-path .= new(:native-object($path));
        my Gnome::Gtk3::TreeIter $iter = $gf.ts.tree-model-get-iter($tree-path);

        # to edit task
        if $gf.search-task-from($gf.om,$iter) {      # if not, it's a text not (now) editable 
            $selected-task=$gf.search-task-from($gf.om,$iter); # TODO [#A] to memorize the current task
            note 'task selected : ',$selected-task.header if $debug;
            return if $is-return; # TODO To remove when tree-select is ok :0.1:

            my GtkTask $task=$gf.search-task-from($gf.om,$iter);
            self.manage($task);
        } else {  # text
            # manage via dialog task
        }
        1
    }
    method move-header {
        my Gnome::Gtk3::TreeIter $iter = $selected-task.iter;

        # Dialog to manage task
        my Gnome::Gtk3::Dialog $dialog .= new(
            :title("Manage task"),
            :parent($!top-window),
            :flags(GTK_DIALOG_DESTROY_WITH_PARENT),
            :button-spec( "Ok", GTK_RESPONSE_NONE)
        );
        my Gnome::Gtk3::Box $content-area .= new(:native-object($dialog.get-content-area));
        my Gnome::Gtk3::Grid $g .= new;
        $content-area.gtk_container_add($g);

        $g.gtk-grid-attach($.create-button('<','move-left-button-click',$iter),          0, 0, 1, 2);
        $g.gtk-grid-attach($.create-button('^','move-up-down-button-click',$iter,-1),    1, 0, 2, 1);
        $g.gtk-grid-attach($.create-button('v','move-up-down-button-click',$iter,1),     1, 1, 2, 1);
        $g.gtk-grid-attach($.create-button('>','move-right-button-click',$iter),         3, 0, 1, 2);

        # Show the dialog.
        $dialog.show-all;
        $dialog.gtk-dialog-run;
        $dialog.gtk_widget_destroy;
        1
    }
    method option-preface {
        # Dialog to manage preface
        my Gnome::Gtk3::Dialog $dialog .= new(
            :title("Manage preface"),
            :parent($!top-window),
            :flags(GTK_DIALOG_DESTROY_WITH_PARENT),
            :button-spec( "Cancel", GTK_RESPONSE_NONE)
        );
        my Gnome::Gtk3::Box $content-area .= new(:native-object($dialog.get-content-area));

        my Gnome::Gtk3::TextView $tev-edit-text .= new;
        $text-buffer .= new(:native-object($tev-edit-text.get-buffer));
        if $gf.om.text {
            my $text=$gf.om.text.join("\n");
            $text-buffer.set-text($text);
        }
        my Gnome::Gtk3::ScrolledWindow $swt .= new;
        $swt.gtk-container-add($tev-edit-text);
        $content-area.gtk_container_add($swt);
        $content-area.gtk_container_add($.create-button('Update Preface','edit-preface',''));
        if $gf.om.text {
            my $text=$gf.om.text.join("\n");
            $text ~~ /(http:..\S*)/;
            $content-area.gtk_container_add($.create-button('Goto to link','go-to-link',$0.Str)) if $0;
        }
        $dialog.show-all;
        $dialog.gtk-dialog-run;
        $dialog.gtk_widget_destroy;
        1
    }
    method handle-keypress ( N-GdkEventKey $event-key, :$widget ) {
        note 'event: ', GdkEventType($event-key.type), ', ', $event-key.keyval.fmt('0x%08x') if $debug;
        $is-return=$event-key.keyval.fmt('0x%08x')==0xff0d; 
        if $event-key.type ~~ GDK_KEY_PRESS {
            if $event-key.keyval.fmt('0x%08x') == GDK_KEY_F11 {
                $is-maximized ?? $!top-window.unmaximize !! $!top-window.maximize;
                $is-maximized=!$is-maximized; 
            }
            note "eks ",$event-key.state if $debug;
            if $event-key.state == 4 { # ctrl push
                #note "Key ",Buf.new($event-key.keyval).decode;
                @ctrl-keys.push(Buf.new($event-key.keyval).decode);
                given join('',@ctrl-keys) {
                    when  ""  {}
                    when  "c" {say "c"}
                    when  "x" {say "x"}
#                    when "cc" {@ctrl-keys=''; say "cc"}
#                    when "cd" {@ctrl-keys=''; say "deadline"}
#                    when "cs" {@ctrl-keys=''; say "scheduled"}
#                    when "cq" {@ctrl-keys=''; say "edit tag"}
#                    when "k" {@ctrl-keys=''; $gf.delete-branch($clicked-task.iter); }
                    when "ct" {@ctrl-keys=''; self.edit-todo-done;}
                    when "xs" {@ctrl-keys=''; self.file-save}
                    when "xc" {@ctrl-keys=''; self.exit-gui}
                    default   {@ctrl-keys=''; say "not use"}
                }
            }
            # TODO Alt-Enter crée un frère après
            # TODO M-S-Enter crée un fils avec TODO
            # TODO Home suivi de Alt-Enter crée un frère avant
            if $event-key.state == 8 { # alt push # TODO write with "given"
                self.move-up-down-button-click(:inc(-1)) 
                    if $event-key.keyval.fmt('0x%08x') == 0xff52; # Alt-Up
                self.move-up-down-button-click(:inc( 1)) 
                    if $event-key.keyval.fmt('0x%08x') == 0xff54; # Alt-Down
            }
            if $event-key.state == 9 { # alt shift push
                self.move-left-button-click() 
                    if $event-key.keyval.fmt('0x%08x') == 0xff51; # Alt-Shift-left
                self.move-right-button-click() 
                    if $event-key.keyval.fmt('0x%08x') == 0xff53; # Alt-Shift-right
            }
        }
        1
    }
} # end Class AppSiganlHandlers
my AppSignalHandlers $ash .= new(:top-window($top-window));

my Gnome::Gtk3::MenuBar $menu-bar .= new;
$g.gtk_grid_attach( $menu-bar, 0, 0, 1, 1);
$menu-bar.gtk-menu-shell-append(create-main-menu('_File',make-menubar-list-file));
$menu-bar.gtk-menu-shell-append(create-main-menu('_Edit',make-menubar-list-edit));
$menu-bar.gtk-menu-shell-append(create-main-menu('O_ption',make-menubar-list-option));
$menu-bar.gtk-menu-shell-append(create-main-menu('_Org',make-menubar-list-org));
$menu-bar.gtk-menu-shell-append(create-main-menu('_View',make-menubar-list-view));
$menu-bar.gtk-menu-shell-append(create-main-menu('_Debug',make-menubar-list-debug)) if $debug;
$menu-bar.gtk-menu-shell-append(create-main-menu('_Help',make-menubar-list-help));

sub create-main-menu($title,Gnome::Gtk3::Menu $sub-menu) {
    my Gnome::Gtk3::MenuItem $but-file-menu .= new(:label($title));
    $but-file-menu.set-use-underline(1);
    $but-file-menu.set-submenu($sub-menu);
    return $but-file-menu;
}
sub create-sub-menu($menu,$name,$ash,$method) {
    my Gnome::Gtk3::MenuItem $menu-item .= new(:label($name));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, $method, 'activate');
} 
#sub create-sub-menu2($menu,$name,$ash,$method,$int) {
#    my Gnome::Gtk3::MenuItem $menu-item .= new(:label($name));
#    $menu-item.set-use-underline(1);
#    $menu.gtk-menu-shell-append($menu-item);
#    $menu-item.register-signal( $ash, $method, 'activate', $int);
#} 
sub make-menubar-list-file {
    my Gnome::Gtk3::Menu $menu .= new;
    create-sub-menu($menu,"_New",$ash,'file-new');
    create-sub-menu($menu,"_Open File ...",$ash,'file-open');
    create-sub-menu($menu,"_Save         C-x C-s",$ash,'file-save');
    create-sub-menu($menu,"Save _as ...",$ash,'file-save-as');
    create-sub-menu($menu,"Save to _test",$ash,'file-save-test') if $debug;
    create-sub-menu($menu,"_Quit         C-x C-c",$ash,'exit-gui');
    $menu
}
sub make-menubar-list-edit {
    my Gnome::Gtk3::Menu $menu .= new;
    create-sub-menu($menu,"Delete task (and sub-tasks)",$ash,'del-button-click');
    create-sub-menu($menu,"Delete sub-tasks",$ash,'del-children-button-click');
    $menu
}
sub make-menubar-list-option {
    my Gnome::Gtk3::Menu $menu .= new;
    create-sub-menu($menu,"P_reface",$ash,'option-preface');
    create-sub-menu($menu,"_Presentation",$ash,'option-presentation');
    create-sub-menu($menu,"_Hide/Display DONE",$ash,'option-no-done');
    create-sub-menu($menu,"#_A",$ash,"option-prior-A");
    create-sub-menu($menu,"#A #_B",$ash,"option-prior-B");
    create-sub-menu($menu,"#A #B #_C",$ash,"option-prior-C");
    $menu
}
sub make-menubar-list-org {
    my Gnome::Gtk3::Menu $menu .= new;
    create-sub-menu($menu,"TODO/DONE/-    C-c C-t",$ash,'edit-todo-done');

#    create-sub-menu2($menu,"Up          M-up",$ash,'move-up-down-button-click',-1); # TODO doesn't work. Why ?
                                                            # Too many positionals passed; expected 4 arguments but got 5
    my Gnome::Gtk3::MenuItem $menu-item .= new(:label('Move Subtree Up             M-up'));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, 'move-up-down-button-click', 'activate',:inc(-1));

    $menu-item .= new(:label('Move Subtree Down      M-down'));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, 'move-up-down-button-click', 'activate',:inc(1));

    $menu-item .= new(:label('Demote Subtree             M-S-right'));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, 'move-right-button-click', 'activate');

    $menu-item .= new(:label('Promote Subtree            M-S-left'));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, 'move-left-button-click', 'activate');

    create-sub-menu($menu,"Move Subtree ...",$ash,'move-header');
    $menu
}   
sub make-menubar-list-view {
    my Gnome::Gtk3::Menu $menu .= new;
    create-sub-menu($menu,"_Fold All",$ash,'view-fold-all');
    create-sub-menu($menu,"_Unfold All",$ash,'view-unfold-all');
    create-sub-menu($menu,"Fold branch",$ash,'fold-branch');
    create-sub-menu($menu,"Unfold branch",$ash,'unfold-branch');
    create-sub-menu($menu,"Unfold branch and child",$ash,'unfold-branch-child');
    $menu
}
sub make-menubar-list-debug {
    my Gnome::Gtk3::Menu $menu .= new;
    create-sub-menu($menu,"_Inspect",$ash,'debug-inspect');
    $menu
}
sub make-menubar-list-help  {
    my Gnome::Gtk3::Menu $menu .= new;
    create-sub-menu($menu,"_About",$ash,'help-about');
    $menu
}
#-----------------------------------main--------------------------------
sub MAIN($arg = '') {
    $gf.open-file($arg);
#    $gf.inspect($gf.om); # TODO create a method without param
    $b-add.register-signal( $ash, 'add-button-click', 'clicked');
    $gf.tv.register-signal( $ash, 'tv-button-click', 'row-activated');
    $top-window.register-signal( $ash, 'exit-gui', 'destroy');
    $top-window.register-signal( $ash, 'handle-keypress', 'key-press-event');
    $top-window.show-all;
    $m.gtk-main;
}

