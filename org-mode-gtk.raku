#!/usr/bin/env perl6

use v6;

use lib "lib";
use DateOrg;
use Task;
use GtkTask;
use GtkFile;
use GtkEditTask;

use Gnome::N::N-GObject;
use Gnome::Gtk3::Main;
use Gnome::Gtk3::Window;
use Gnome::Gtk3::Grid;
use Gnome::Gtk3::Button;
use Gnome::Gtk3::CheckButton;
use Gnome::Gtk3::Label;
use Gnome::Gtk3::TreePath;
use Gnome::Gtk3::TreeView;
use Gnome::Gtk3::TreeIter;
use Gnome::Gtk3::MenuBar;
use Gnome::Gtk3::Menu;
use Gnome::Gtk3::MenuItem;
use Gnome::Gtk3::Dialog;
use Gnome::Gtk3::MessageDialog;
use Gnome::Gtk3::AboutDialog;
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

# global variable : to remove ?
my $debug=1;            # to debug =1
my $is-maximized=False; # TODO use gtk-window.is_maximized in Window.pm6 (uncomment =head2 [[gtk_] window_] is_maximized) :0.x:
my $is-return=False;    # memorize the return key

my Gnome::Gtk3::Main $m .= new;

my Gnome::Gtk3::Window $top-window .= new;
$top-window.set-title('Org-Mode with GTK and raku');
$top-window.set-default-size( 640, 480);

my Gnome::Gtk3::Grid $g .= new;
$top-window.gtk-container-add($g);

my GtkFile $gf.=new;
$g.gtk-grid-attach($gf.sw, 0, 1, 4, 1);

my Gnome::Gtk3::Label $l-info .= new(:text('Double-Click on task to modify'));
$g.gtk-grid-attach($l-info, 0, 2, 1, 1);

my Gnome::Gtk3::AboutDialog $about .= new;
$about.set-program-name('org-mode-gtk.raku');
$about.set-version('0.1');
$about.set-license-type(GTK_LICENSE_GPL_3_0);
$about.set-website("http://www.barbason.be");
$about.set-website-label("http://www.barbason.be");
$about.set-authors(CArray[Str].new('Alain BarBason'));

class AppSignalHandlers {
    has Gnome::Gtk3::Window $!top-window;
    submethod BUILD ( Gnome::Gtk3::Window:D :$!top-window! ) { }

    method exit-gui ( --> Int ) {
        my $button=$gf.try-save($!top-window);
        $m.gtk-main-quit if $button != GTK_RESPONSE_CANCEL;
        1
    }
    multi method create-button($label,$method,Gnome::Gtk3::Label $l-result,DateOrg $d,DateTime $next-date,
            Gnome::Gtk3::ComboBoxText $year, Gnome::Gtk3::ComboBoxText $month, Gnome::Gtk3::ComboBoxText $day) {
#        note "create button for today,..." if $debug;
        my Gnome::Gtk3::Button $b  .= new(:label($label));
        $b.register-signal(self, $method, 'clicked',:l-result($l-result),:date($d),:next-date($next-date),
                                                    :year($year),:month($month),:day($day));
        return $b;
    }
    multi method create-button($label,$method,$iter?,$inc?) {
#        note "create button by default" if $debug;
        my Gnome::Gtk3::Button $b  .= new(:label($label));
        $b.register-signal(self, $method, 'clicked',:iter($iter),:inc($inc));
        return $b;
    }
    method create-check($method,Gnome::Gtk3::Label $label,Int $check) {
        my Gnome::Gtk3::CheckButton $cb .= new;
        $cb.set-active($check);
        $cb.register-signal( self, $method, 'toggled',:edit($label));
        return $cb;
    }
    method go-to-link ( :$iter ) { # TODO it's not iter, but text. To refactoring
#        my $proc = run '/opt/firefox/firefox', '--new-tab', $edit;
        shell "/opt/firefox/firefox --new-tab $iter";
        1
    }
    method file-new ( --> Int ) {
        if $gf.try-save($!top-window) != GTK_RESPONSE_CANCEL {
            $gf.ts.clear;
            $gf.om.tasks=[]; 
            $gf.om.text=[]; 
            $gf.om.properties=(); # TODO use undefined ?
            $gf.om.header = "";
            $!top-window.set-title('Org-Mode with GTK and raku');
            $gf.default;
        }
        1
    }
    method file-open ( --> Int ) {
        if $gf.try-save($!top-window) != GTK_RESPONSE_CANCEL {
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
                my $filename = $dialog.get-filename;
                if $filename.IO.e {
                    $gf.ts.clear;
                    $gf.om.tasks=[]; 
                    $gf.om.text=[]; 
                    $gf.om.properties=(); # TODO use undefined ?
                    $gf.om.header = $filename;
                    $gf.file-open($gf.om.header,$!top-window) if $gf.om.header;
                } else {
                    my Gnome::Gtk3::MessageDialog $md .=new(
                                        :message("File doesn't exist !"),
                                        :buttons(GTK_BUTTONS_OK)
                    );
                    $md.run;
                    $md.destroy; # TODO destroy but keep $dialog open
                }
            }
            $dialog.gtk-widget-hide;
        }
        1
    }
    method file-save {
        $gf.om.header ?? $gf.save !! $gf.file-save-as($!top-window);
    }
    method file-save-as {
        $gf.file-save-as($!top-window);
        1
    }
    method file-save-test {
        $gf.save("test.org");
        run 'cat','test.org';
        say "\n"; # yes, 2 lines.
    }
    method edit-todo-done {
        if $.highlighted-task {
            if $.highlighted-task.todo eq "TODO" {
                self.todo-shortcut(:iter($.highlighted-task.iter),:todo("DONE"));
            } elsif $.highlighted-task.todo eq "DONE" {
                self.todo-shortcut(:iter($.highlighted-task.iter),:todo(""))}
            else                                {
                self.todo-shortcut(:iter($.highlighted-task.iter),:todo("TODO"));
            }
        }
    }
    method debug-inspect {
        $gf.om.inspect;
    }
    method view-hide-image {
        $gf.view-hide-image =  !$gf.view-hide-image;
        $gf.reconstruct-tree;
        1
    }
    method option-presentation { # TODO to do this by task and not only for the entire tree
        $gf.presentation =  $gf.presentation eq "TEXT" ?? "TODO" !! "TEXT";
        $gf.reconstruct-tree;
        1
    }
    method option-no-done (:$widget) {
        $gf.no-done=!$gf.no-done;
        $widget.set-label($gf.no-done  ?? 'Show _DONE' !! 'Hide _DONE');
        $gf.reconstruct-tree;
        1
    }
    method option-prior-A {
        $gf.clear-sparse;
        $gf.prior-A=True;
        $gf.prior-B=False;
        $gf.prior-C=False;
        $gf.reconstruct-tree;
        $gf.tv.expand-all;
        1
    }
    method option-prior-B {
        $gf.clear-sparse;
        $gf.prior-A=False;
        $gf.prior-B=True;
        $gf.prior-C=False;
        $gf.reconstruct-tree;
        $gf.tv.expand-all;
        1
    }
    method option-prior-C {
        $gf.clear-sparse;
        $gf.prior-A=False;
        $gf.prior-B=False;
        $gf.prior-C=True;
        $gf.reconstruct-tree;
        $gf.tv.expand-all;
        1
    }
    method option-today-past {
        $gf.clear-sparse;
        $gf.today-past=True;
        $gf.reconstruct-tree;
        $gf.tv.expand-all;
        1
    }
    method option-find {
        $gf.clear-sparse;
        if $gf.choice-find($top-window) == GTK_RESPONSE_OK {
            $gf.reconstruct-tree;
            $gf.tv.expand-all;
        }
        1
    }
    method option-search-tag {
        $gf.clear-sparse;
        my @tags=$gf.om.search-tags.flat;
        if $gf.choice-tags(@tags,$top-window) == GTK_RESPONSE_OK {
            $gf.reconstruct-tree;
            $gf.tv.expand-all;
        }
        1
    }
    method option-clear {
        $gf.clear-sparse;
        $gf.reconstruct-tree;
        $gf.tv.collapse-all;
        1
    }
    method view-fold-all {
        $gf.tv.collapse-all;
        if !$.highlighted-task { # TODO better manage the absence of highlighted task 
            # No highlighted task if 
            # * un
            # * deux
            # * trois
            # ** sub-trois
            # hightlight sub-trois
            # ctrl-^
            # fold all
            # no task selected
            my Gnome::Gtk3::TreePath $tp .= new(:string("0"));
            my Gnome::Gtk3::TreeSelection $tselect .= new(:treeview($gf.tv));
            $tselect.select-path($tp);
        }
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
    method add-brother-down {
        $gf.change=1;
        my $task=$.highlighted-task;
        my GtkTask $brother.=new(:header(""),:level($task.level),:darth-vader($task.darth-vader));
        my GtkEditTask $et .=new(:top-window($!top-window));
        $et.edit-task($brother,$gf);
        $gf.highlighted($brother);
    }
    method highlighted-task {
        my Task $task;
#        note 'edit gs: ', $gf.tv.gtk_tree_view_get_selection.perl;
        my Gnome::Gtk3::TreeSelection $tselect .= new(:treeview($gf.tv));
#        note 'edit sr: ', $tselect.get-selected-rows(N-GObject);
        if $tselect.count-selected-rows {
            my Gnome::Glib::List $selected-rows .= new(
                :native-object($tselect.get-selected-rows(N-GObject))
            );
            # keep a eye at the front to remove the list later
            my Gnome::Glib::List $copy = $selected-rows.copy;

            if ?$selected-rows { # TODO Change in while where manage selected multi-line
                my Gnome::Gtk3::TreePath $tp .= new(:native-object(
                    nativecast( N-GObject, $selected-rows.data)
                ));
    #            note "tp ", $tp.to-string;
                my Gnome::Gtk3::TreeIter $iter;
    #            $iter = $gf.ts.get-iter($tp); # TODO expected Gnome::Gtk3::TreePath::N-GtkTreePath but got N-GObject (N-GObject.new)
                $iter = $gf.ts.get-iter-from-string($tp.to-string);
    #            note "it ",$iter;
                $task=$gf.search-task-from($gf.om,$iter);
    #            note "ta ",$task.header;
                $selected-rows .= next;
            }
            $copy.clear-object;
        } # TODO implemented "else", case of there are not task highlighted, that is possible if file is empty, improbable but...
        return $task;
    }
    method add-child {
        $gf.change=1; # TODO to do if manage return OK and not Cancel
        my $task=$.highlighted-task;
        my GtkTask $child.=new(:header(""),:level($task.level+1),:darth-vader($task)); # TODO create a BUILD 
        my GtkEditTask $et .=new(:top-window($!top-window));
        $et.edit-task($child,$gf);
        $gf.unfold-branch($task);
        $gf.highlighted($child);
    }
    method move-right-button-click {
        my $iter=$.highlighted-task.iter;
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
        $gf.create-task($task,$iter-parent,:cond(False));
        $task.darth-vader=$task-parent;
        $gf.expand-row($task-parent,0);
        my Gnome::Gtk3::TreeSelection $tselect .= new(:treeview($gf.tv));
        $tselect.select-iter($task.iter);
        1
    }
    method move-left-button-click {
        my $iter=$.highlighted-task.iter;
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
        $gf.create-task($task,$task.darth-vader.darth-vader.iter,@path-parent[*-1]+1,:cond(False));
        $task.darth-vader=$task.darth-vader.darth-vader;
        $gf.expand-row($task,0);
        my Gnome::Gtk3::TreeSelection $tselect .= new(:treeview($gf.tv));
        $tselect.select-iter($task.iter);
        1
    }
    method move-up-down-button-click ( :$inc --> Int ) { # TODO I don't pass iter as parameter. To improve
        my $iter=$.highlighted-task.iter;
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
    method todo-shortcut ( :$iter,:$todo --> Int ) {
        $gf.change=1;
        my GtkTask $task=$gf.search-task-from($gf.om,$iter);
        $task.todo=$todo;
        $gf.ts.set_value( $iter, 0,$task.display-header($gf.presentation));
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
    method priority-up {
        $gf.change=1;
        given $.highlighted-task.priority {
            when  ""  {$.highlighted-task.priority="C"}
            when  "A"  {$.highlighted-task.priority=""}
            when  "B"  {$.highlighted-task.priority="A"}
            when  "C"  {$.highlighted-task.priority="B"}
        }
        $gf.ts.set_value( $.highlighted-task.iter, 0,$.highlighted-task.display-header($gf.presentation)); # TODO create $gf.ts-set-header($task)
    }
    method priority-down {
        $gf.change=1;
        given $.highlighted-task.priority {
            when  ""  {$.highlighted-task.priority="A"}
            when  "A"  {$.highlighted-task.priority="B"}
            when  "B"  {$.highlighted-task.priority="C"}
            when  "C"  {$.highlighted-task.priority=""}
        }
        $gf.ts.set_value( $.highlighted-task.iter, 0,$.highlighted-task.display-header($gf.presentation)); # TODO create $gf.ts-set-header($task)
    }
    method del-button-click {
        $gf.change=1;
        $gf.delete-branch($.highlighted-task.iter);
        1
    }
    method edit-cut (:$widget,:$widget-paste) {
        $gf.cut-branch($.highlighted-task.iter);
        $widget.set-sensitive(0);
        $widget-paste.set-sensitive(1);
        1
    }
    method edit-paste (:$widget,:$widget-cut) {
        $gf.paste-branch($.highlighted-task.iter);
        $widget.set-sensitive(0);
        $widget-cut.set-sensitive(1);
        1
    }
    method fold-branch {
        $gf.fold-branch($.highlighted-task);
        1
    }
    method unfold-branch {
        $gf.unfold-branch($.highlighted-task);
        1
    }
    method unfold-branch-child {
        $gf.unfold-branch-child($.highlighted-task);
        1
    }
    my @ctrl-keys;
    method tv-button-click (N-GtkTreePath $path, N-GObject $column ) {
        my Gnome::Gtk3::TreePath $tree-path .= new(:native-object($path));
        my Gnome::Gtk3::TreeIter $iter = $gf.ts.tree-model-get-iter($tree-path);

        # to edit task
        if $gf.search-task-from($gf.om,$iter) {      # if not, it's a text not (now) editable 
            my GtkTask $task=$gf.search-task-from($gf.om,$iter);
            my GtkEditTask $et .=new(:top-window($!top-window));
            $et.edit-task($task,$gf);
        } else {  # text
            # manage via dialog task
        }
        1
    }
    method move-header {
        my Gnome::Gtk3::TreeIter $iter = $.highlighted-task.iter;

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
            :title("Edit preface"),
            :parent($!top-window),
            :flags(GTK_DIALOG_DESTROY_WITH_PARENT),
            :button-spec( "Cancel", GTK_RESPONSE_NONE)
            :button-spec( [
                "_Cancel", GTK_RESPONSE_CANCEL,
                "_Ok", GTK_RESPONSE_OK,
            ] )
        );
        my Gnome::Gtk3::Box $content-area .= new(:native-object($dialog.get-content-area));

        my Gnome::Gtk3::TextView $tev-edit-text .= new;
        my Gnome::Gtk3::TextBuffer $text-buffer .= new(:native-object($tev-edit-text.get-buffer));
        if $gf.om.text {
            my $text=$gf.om.text.join("\n");
            $text-buffer.set-text($text);
        }
        my Gnome::Gtk3::ScrolledWindow $swt .= new;
        $swt.gtk-container-add($tev-edit-text);
        $content-area.gtk_container_add($swt);
        $dialog.show-all;
        my $response=$dialog.gtk-dialog-run;
        if $response == GTK_RESPONSE_OK {
            $gf.change=1;
            my Gnome::Gtk3::TextIter $start = $text-buffer.get-start-iter;
            my Gnome::Gtk3::TextIter $end = $text-buffer.get-end-iter;
            my $new-text=$text-buffer.get-text( $start, $end, 0);
            $gf.om.text=$new-text.split(/\n/);
        }
        $dialog.gtk_widget_destroy;
        1
    }
    method handle-keypress ( N-GdkEventKey $event-key, :$widget ) {
#        note 'event: ', GdkEventType($event-key.type), ', ', $event-key.keyval.fmt('0x%08x') if $debug;
        $is-return=$event-key.keyval.fmt('0x%08x')==0xff0d; 
        if $event-key.type ~~ GDK_KEY_PRESS {
            if $event-key.keyval.fmt('0x%08x') == GDK_KEY_F11 {
                $is-maximized ?? $!top-window.unmaximize !! $!top-window.maximize;
                $is-maximized=!$is-maximized; 
            }
            if $event-key.state == 1 { # shift push
                given $event-key.keyval.fmt('0x%08x') {
                    when 0xff52 {self.priority-up}
                    when 0xff54 {self.priority-down}
                }
            }
            if $event-key.state == 4 { # ctrl push
                #note "Key ",Buf.new($event-key.keyval).decode;
                @ctrl-keys.push(Buf.new($event-key.keyval).decode);
                given join('',@ctrl-keys) {
                    when  ""  {}
                    when  "c"  {$l-info.set-label("C-c")}
                    when  "x"  {$l-info.set-label("C-x")}
                    when  "cx" {$l-info.set-label("C-c C-x")}
#                    when "cc" {@ctrl-keys=''; say "cc"}
#                    when "cq" {@ctrl-keys=''; say "edit tag"}
#                    when "k"  {@ctrl-keys=''; $l-info.set-label('Delete branch');      $gf.delete-branch($clicked-task.iter); }
                    when "cs"  {@ctrl-keys=''; $l-info.set-label('Schedule');           self.scheduled(:task($.highlighted-task))}
                    when "cd"  {@ctrl-keys=''; $l-info.set-label('Deadline');           self.deadline(:task($.highlighted-task))}
                    when "ct"  {@ctrl-keys=''; $l-info.set-label('Change TODO/DONE/-'); self.edit-todo-done;}
                    when "cxv" {@ctrl-keys=''; $l-info.set-label('View/Hide Image');    $.view-hide-image;}
                    when "xs"  {@ctrl-keys=''; $l-info.set-label('Save');               self.file-save}
                    when "xc"  {@ctrl-keys=''; $l-info.set-label('Exit');               self.exit-gui}
                    default    {$l-info.set-label(join(' Ctrl-',@ctrl-keys) ~ " is undefined");@ctrl-keys='';}
                }
            }
            # TODO Alt-Enter crée un frère après
            # TODO M-S-Enter crée un fils avec TODO
            # TODO Home suivi de Alt-Enter crée un frère avant
            if $event-key.state == 8 { # alt push # TODO write with "given" :refactoring:
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
#$menu-bar.gtk-menu-shell-append(create-main-menu('_Edit',make-menubar-list-edit));
$menu-bar.gtk-menu-shell-append(create-main-menu('D_ivers',make-menubar-list-divers));
$menu-bar.gtk-menu-shell-append(create-main-menu('_Org',make-menubar-list-org));
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

    $menu
}
sub make-menubar-list-divers {
    my Gnome::Gtk3::Menu $menu .= new;

    create-sub-menu($menu,"Edit P_reface",$ash,'option-preface');
    create-sub-menu($menu,"Change _Presentation",$ash,'option-presentation');
    create-sub-menu($menu,"View/Hide _Image       C-c C-x C-v",$ash,'view-hide-image');

    $menu
}
sub make-menubar-list-org {
    my Gnome::Gtk3::Menu $menu .= new;

    my Gnome::Gtk3::Menu $sm-sh = make-menubar-sh($ash);
    my Gnome::Gtk3::MenuItem $sh-root-menu .= new(:label('Show/Hide'));
    $sh-root-menu.set-submenu($sm-sh);
    $menu.gtk-menu-shell-append($sh-root-menu);

    my Gnome::Gtk3::MenuItem $menu-item .= new(:label('New Heading                M-Enter'));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, 'add-brother-down', 'activate');

    create-sub-menu($menu,"New Child",$ash,'add-child');

    my Gnome::Gtk3::Menu $sm-es = make-menubar-es($ash);
    my Gnome::Gtk3::MenuItem $es-root-menu .= new(:label('Edit Structure'));
    $es-root-menu.set-submenu($sm-es);
    $menu.gtk-menu-shell-append($es-root-menu);

    my Gnome::Gtk3::Menu $sm-todo = make-menubar-todo($ash);
    my Gnome::Gtk3::MenuItem $sm-root-menu .= new(:label('TODO Lists'));
    $sm-root-menu.set-submenu($sm-todo);
    $menu.gtk-menu-shell-append($sm-root-menu);

#    my Gnome::Gtk3::Menu $sm-tp = make-menubar-tp($ash);
#    my Gnome::Gtk3::MenuItem $tp-root-menu .= new(:label('TAG and Properties'));
#    $tp-root-menu.set-submenu($sm-tp);
#    $menu.gtk-menu-shell-append($tp-root-menu);
#
    my Gnome::Gtk3::Menu $sm-ds = make-menubar-ds($ash);
    my Gnome::Gtk3::MenuItem $ds-root-menu .= new(:label('Dates and Scheduling'));
    $ds-root-menu.set-submenu($sm-ds);
    $menu.gtk-menu-shell-append($ds-root-menu);

    $menu
}   
sub make-menubar-sh ( AppSignalHandlers $ash ) {
    my Gnome::Gtk3::Menu $menu .= new;

    my Gnome::Gtk3::Menu $sm-st = make-menubar-st($ash);
    my Gnome::Gtk3::MenuItem $st-root-menu .= new(:label('Sparse Tree'));
    $st-root-menu.set-submenu($sm-st);
    $menu.gtk-menu-shell-append($st-root-menu);

    create-sub-menu($menu,"Fold All",$ash,'view-fold-all');
    create-sub-menu($menu,"Show All",$ash,'view-unfold-all');
    create-sub-menu($menu,"Fold branch",$ash,'fold-branch');
    create-sub-menu($menu,"Unfold branch",$ash,'unfold-branch');
    create-sub-menu($menu,"Unfold branch and child",$ash,'unfold-branch-child');

    $menu
}
sub make-menubar-st ( AppSignalHandlers $ash ) {
    my Gnome::Gtk3::Menu $menu .= new;

    create-sub-menu($menu,"Show _DONE",$ash,'option-no-done'); # TODO replace Show All (or another name), Create Show TODO tree :0.1:
    create-sub-menu($menu,"#_A",$ash,"option-prior-A");
    create-sub-menu($menu,"#A #_B",$ash,"option-prior-B");
    create-sub-menu($menu,"#A #B #_C",$ash,"option-prior-C");
    create-sub-menu($menu,"_Today and past",$ash,"option-today-past");

    my Gnome::Gtk3::MenuItem $mi-find .= new(:label('_Find ...'));
    $mi-find.set-use-underline(1);
    $menu.gtk-menu-shell-append($mi-find);

    $mi-find.register-signal( $ash, "option-find", 'activate');

    my Gnome::Gtk3::MenuItem $mi-search-tags .= new(:label('Search by _Tag ...'));
    $mi-search-tags.set-use-underline(1);
    $menu.gtk-menu-shell-append($mi-search-tags);
    $mi-search-tags.register-signal( $ash, "option-search-tag", 'activate');

    my Gnome::Gtk3::MenuItem $mi-clear-tags .= new(:label("Clear filter (but hide DONE)"));
    $mi-clear-tags.set-use-underline(1);
    $menu.gtk-menu-shell-append($mi-clear-tags);
    $mi-clear-tags.register-signal( $ash, "option-clear", 'activate');

    $menu
}
sub make-menubar-es ( AppSignalHandlers $ash ) {
    my Gnome::Gtk3::Menu $menu .= new;

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

    my Gnome::Gtk3::MenuItem $mi-cut .= new(:label('_Cut Subtree'));
    $mi-cut.set-use-underline(1);
    $menu.gtk-menu-shell-append($mi-cut);
    my Gnome::Gtk3::MenuItem $mi-paste .= new(:label("_Paste Subtree (as child)"));
    $mi-paste.set-use-underline(1);
    $menu.gtk-menu-shell-append($mi-paste);
    $mi-paste.set-sensitive(0);

    $mi-cut.register-signal( $ash, "edit-cut", 'activate',:widget-paste($mi-paste));
    $mi-paste.register-signal( $ash, "edit-paste", 'activate',:widget-cut($mi-cut));

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
sub make-menubar-todo ( AppSignalHandlers $ash ) {
    my Gnome::Gtk3::Menu $menu .= new;

    create-sub-menu($menu,"TODO/DONE/-    C-c C-t",$ash,'edit-todo-done');

    # TODO add a menu separator

    my Gnome::Gtk3::MenuItem $menu-item .= new(:label('Priority Up                  S-up'));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, 'priority-up', 'activate');

    $menu-item .= new(:label('Priority Down                S-down'));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, 'priority-down', 'activate');

    $menu
}
#sub make-menubar-tp ( AppSignalHandlers $ash ) {
#    my Gnome::Gtk3::Menu $menu .= new;
#
#    $menu
#}
sub make-menubar-ds ( AppSignalHandlers $ash ) {
    my Gnome::Gtk3::Menu $menu .= new;

    my Gnome::Gtk3::MenuItem $menu-item .= new(:label('Schedule item                C-c C-s'));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, 'scheduled', 'activate'); 

    $menu-item .= new(:label('Deadline                    C-c C-d'));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, 'deadline', 'activate');

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
    $gf.file-open($arg,$top-window);
    $gf.tv.register-signal( $ash, 'tv-button-click', 'row-activated');
    $top-window.register-signal( $ash, 'exit-gui', 'destroy');
    $top-window.register-signal( $ash, 'handle-keypress', 'key-press-event');
    $top-window.show-all;
    $m.gtk-main;
}

