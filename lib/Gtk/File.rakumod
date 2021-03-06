use OrgMode::Date;
use Gtk::Task;
use OrgMode::Grammar;
use Gtk::EditTask;

use Gnome::N::N-GObject;
use Gnome::GObject::Type;
use Gnome::GObject::Value;
use Gnome::Gtk3::TreeStore;
use Gnome::Gtk3::TreeView;
use Gnome::Gtk3::ScrolledWindow;
use Gnome::Gtk3::CellRendererText;
use Gnome::Gdk3::Pixbuf;
use Gnome::Gtk3::CellRendererPixbuf;
use Gnome::Gtk3::FileChooser;
use Gnome::Gtk3::FileChooserDialog;
use Gnome::Gtk3::Dialog;
use Gnome::Gtk3::MessageDialog;
use Gnome::Gtk3::Box;
use Gnome::Gtk3::Entry;
use Gnome::Gtk3::ListStore;
use Gnome::GObject::Value;
use Gnome::Gtk3::TreeViewColumn;
use Gnome::Gtk3::TreePath;
use Gnome::Gtk3::TreeSelection;
use Gnome::Gdk3::Events;
use NativeCall;

#use Data::Dump;

my Gtk::Task $task-cut; # to save a branch cut, to past after # TODO remove global value, in fact, task-cut is global var for program, not GtkFile (to analyse when notebook) :refactoring:0.x:

class Gtk::File {
    has Gtk::Task                     $.om              is rw;
    has Gnome::Gtk3::TreeStore      $.ts              ; #.= new(:field-types(G_TYPE_STRING));
    has Gnome::Gtk3::TreeView       $.tv              ; #.= new(:model($!ts));
    has Gnome::Gtk3::ScrolledWindow $.sw              ; #.= new;
    has Gnome::Gtk3::Window         $!top-window      ;
    has                             $.count-row       is rw =0;
    has Int                         $.change          is rw =0;       # for ask question to save when quit
    has                             $.no-done         is rw =True;    # display with no DONE
    has                             $.prior-A         is rw =False;   # display #A          
    has                             $.prior-B         is rw =False;   # display #B          
    has                             $.prior-C         is rw =False;   # display #C          
    has                             $.today-past      is rw =False;   # display only task in past and not Done          
    has                             $.presentation    is rw ="TODO";  # Change presentation for display title          
    has                             $.view-hide-image is rw =0;
    has                             $.g-tag           is rw;          # Memorize tag to find, nil is no find
    has                             $.g-find          is rw ='';      # Memorize string to find, nil is no find

    enum list-field-columns < TITLE-CODE PICT TITLE >;
    my Gnome::Gdk3::Pixbuf $pb .= new(:file<img/test.png>);
    my Int $pb-type = $pb.get-class-gtype;
    #note "Pixbuf type: $pb-type";

    submethod BUILD ( Gnome::Gtk3::Window:D :$!top-window! ) {
        $!om                  .= new(:stars(0)) ; 
        $!ts                  .= new(:field-types(G_TYPE_STRING, $pb-type, G_TYPE_STRING));
        $!tv                  .= new(:model($!ts));
        $!tv.set-hexpand(1);
        $!tv.set-vexpand(1);
        $!tv.set-headers-visible(0);
#        $!tv.set-activate-on-single-click(1);
        $!sw                  .= new;
        $!sw.gtk-container-add($!tv);

        my Gnome::Gtk3::TreeViewColumn $tvc .= new;
        my Gnome::Gtk3::CellRendererText $crt1 .= new;
        $tvc.pack-end( $crt1, 1);
        $tvc.add-attribute( $crt1, 'markup', 0);
        $!tv.append-column($tvc);

        $tvc .= new;
        my Gnome::Gtk3::CellRendererPixbuf $crt3 .= new;
        $tvc.pack-end( $crt3, 1);
        $tvc.add-attribute( $crt3, 'pixbuf', PICT);
        $!tv.append-column($tvc);

        $tvc .= new;
        my Gnome::Gtk3::CellRendererText $crt2 .= new;
        $tvc.pack-end( $crt2, 1);
        $tvc.add-attribute( $crt2, 'markup', 2);
        $!tv.append-column($tvc);
        $!tv.register-signal( self, 'tv-button-click', 'row-activated');
    }

    # When click on a tag, accept immediatly the choice 
    method tv-tag-click (N-GtkTreePath $path, N-GObject $column , :$ls, :@tags, :$dialog) {
        my Gnome::Gtk3::TreePath $tree-path .= new(:native-object($path));
        $.g-tag=@tags[$tree-path.to-string];
        $dialog.response(GTK_RESPONSE_OK);
    }
    # When push "enter" in window find, accept the entry immediatly 
    method find-edit (N-GdkEventKey $event-key, :$dialog) { # TODO bug if 'enter' (and not double clickk)  on a task, open and close edit task.
        $dialog.response(GTK_RESPONSE_OK)
            if $event-key.keyval.fmt('0x%08x')==0xff0d;
    }
    method file-new ( --> Int ) {
        if $.try-save != GTK_RESPONSE_CANCEL {
            $.ts.clear;
            $.om.tasks=[]; 
            $.om.text=[]; 
            $.om.properties=(); # TODO use undefined ?
            $.om.title = "";
            $!top-window.set-title('Org-Mode with GTK and raku');
            $.default;
        }
        1
    }
    method file-open ( --> Int ) {
        if $.try-save != GTK_RESPONSE_CANCEL {
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
                    $.ts.clear;
                    $.om.tasks=[]; 
                    $.om.text=[]; 
                    $.om.properties=(); # TODO use undefined ?
                    $.om.title = $filename;
                    $.file-read($.om.title) if $.om.title;
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
        $.om.title ?? $.save !! $.file-save-as;
    }
    method file-save-test {
        $.save("test.org");
        run 'cat','test.org';
        say "\n"; # yes, 2 lines.
    }
    method move-right-button-click {
        my $iter=$.highlighted-task.iter;
        my @path= $.ts.get-path($iter).get-indices.Array;
        return if @path[*-1] eq "0"; # first task doesn't go to left
        my Gtk::Task $task=$.search-task-from($.om,$iter);
        my @path-parent=@path; # it's not the parent (darth-vader) but the futur parent
        @path-parent[*-1]--;
        my $iter-parent=$.get-iter-from-path(@path-parent);
        my Gtk::Task $task-parent=$.search-task-from($.om,$iter-parent);
        $.delete-branch($iter); 
        $task.stars-move(1);
        push($task-parent.tasks,$task); 
        $.create-task($task,$iter-parent,:cond(False));
        $task.darth-vader=$task-parent;
        $.expand-row($task-parent,0);
        my Gnome::Gtk3::TreeSelection $tselect .= new(:treeview($.tv));
        $tselect.select-iter($task.iter);
        1
    }
    method move-left-button-click {
        my $iter=$.highlighted-task.iter;
        my Gtk::Task $task=$.search-task-from($.om,$iter);
        return if $task.stars <= 1; # stars 0 and 1 don't go to left
        $task.stars-move(-1);
        $.delete-branch($iter); 
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
        my @path-parent= $.ts.get-path($task.darth-vader.iter).get-indices.Array;
        $.create-task($task,$task.darth-vader.darth-vader.iter,@path-parent[*-1]+1,:cond(False));
        $task.darth-vader=$task.darth-vader.darth-vader;
        $.expand-row($task,0);
        my Gnome::Gtk3::TreeSelection $tselect .= new(:treeview($.tv));
        $tselect.select-iter($task.iter);
        1
    }
    method move-up-down-button-click ( :$inc --> Int ) { # TODO I don't pass iter as parameter. To improve
        my $iter=$.highlighted-task.iter;
        my @path= $.ts.get-path($iter).get-indices.Array;
        if !(@path[*-1] eq "0" && $inc==-1) {     # if is not the first child in treestore (because if have DONE hide) for up
            my $iter2=$.brother($iter,$inc);
            if $iter2.is-valid {   # if not, it's the last child
                $.change=1;
                my Gtk::Task $task=$.search-task-from($.om,$iter);
                my Gtk::Task $task2=$.search-task-from($.om,$iter2);
                $.ts.swap($iter,$iter2);
                $.swap($task,$task2);
                my Gnome::Gtk3::TreeSelection $tselect .= new(:treeview($.tv));
                $tselect.select-iter($task.iter);
            }
        }
        1
    }
    method tv-button-click (N-GtkTreePath $path, N-GObject $column ) {
        my Gnome::Gtk3::TreePath $tree-path .= new(:native-object($path));
        my Gnome::Gtk3::TreeIter $iter = $.ts.tree-model-get-iter($tree-path);

        # to edit task
        if $.search-task-from($.om,$iter) {      # if not, it's a text not (now) editable 
            my Gtk::Task $task=$.search-task-from($.om,$iter);
            my Gtk::EditTask $et .=new(:top-window($!top-window));
            $et.edit-task($task,self);
        } else {  # text
            # manage via dialog task
        }
        1
    }
    method priority-up {
        $.change=1;
        given $.highlighted-task.priority {
            when  ""  {$.highlighted-task.priority="C"}
            when  "A"  {$.highlighted-task.priority=""}
            when  "B"  {$.highlighted-task.priority="A"}
            when  "C"  {$.highlighted-task.priority="B"}
        }
        $.ts.set_value( $.highlighted-task.iter, 0,$.highlighted-task.display-title($.presentation)); # TODO create $.ts-set-title($task)
    }
    method edit-cut (:$widget,:$widget-paste) {
        $.cut-branch($.highlighted-task.iter);
        $widget.set-sensitive(0);
        $widget-paste.set-sensitive(1);
        1
    }
    method edit-paste (:$widget,:$widget-cut) {
        $.paste-branch($.highlighted-task.iter);
        $widget.set-sensitive(0);
        $widget-cut.set-sensitive(1);
        1
    }
    method priority-down {
        $.change=1;
        given $.highlighted-task.priority {
            when  ""  {$.highlighted-task.priority="A"}
            when  "A"  {$.highlighted-task.priority="B"}
            when  "B"  {$.highlighted-task.priority="C"}
            when  "C"  {$.highlighted-task.priority=""}
        }
        $.ts.set_value( $.highlighted-task.iter, 0,$.highlighted-task.display-title($.presentation)); # TODO create $.ts-set-title($task)
    }
    method add-brother-down {
        my Gtk::Task $task=$.highlighted-task;
        my Gtk::Task $brother.=new(:title(""),:stars($task.stars),:darth-vader($task.darth-vader));
        my Gtk::EditTask $et .=new(:top-window($!top-window));
        if $et.edit-task($brother,self) == GTK_RESPONSE_OK {
            $.change=1;
            $.highlighted($brother);
        }
    }
    method add-child {
        my Gtk::Task $task=$.highlighted-task;
        my Gtk::Task $child.=new(:title(""),:stars($task.stars+1),:darth-vader($task)); # TODO create a BUILD
        my Gtk::EditTask $et .=new(:top-window($!top-window));
        if $et.edit-task($child,self) == GTK_RESPONSE_OK {
            $.change=1;
#            $.unfold-branch; # TODO unfold de good branch :0.2:
            $.highlighted($child);
        }
    }
    method option-prior-A {
        $.clear-sparse;
        $.prior-A=True;
        $.prior-B=False;
        $.prior-C=False;
        $.reconstruct-tree;
        $.tv.expand-all;
        1
    }
    method option-prior-B {
        $.clear-sparse;
        $.prior-A=False;
        $.prior-B=True;
        $.prior-C=False;
        $.reconstruct-tree;
        $.tv.expand-all;
        1
    }
    method option-prior-C {
        $.clear-sparse;
        $.prior-A=False;
        $.prior-B=False;
        $.prior-C=True;
        $.reconstruct-tree;
        $.tv.expand-all;
        1
    }
    method option-today-past {
        $.clear-sparse;
        $.today-past=True;
        $.reconstruct-tree;
        $.tv.expand-all;
        1
    }
    method option-find {
        $.clear-sparse; # TODO put this line in "if" but save $.g-find before and set after;
        if $.choice-find($!top-window) == GTK_RESPONSE_OK {
            $.reconstruct-tree;
            $.tv.expand-all;
        }
        1
    }
    method option-search-tag {
        $.clear-sparse;
        my @tags=$.om.search-tags.flat;
        if $.choice-tags(@tags,$!top-window) == GTK_RESPONSE_OK {
            $.reconstruct-tree;
            $.tv.expand-all;
        }
        1
    }
    method option-clear {
        $.clear-sparse;
        $.reconstruct-tree;
        $.tv.collapse-all;
        1
    }
    method view-fold-all {
        $.tv.collapse-all;
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
            my Gnome::Gtk3::TreeSelection $tselect .= new(:treeview($.tv));
            $tselect.select-path($tp);
        }
        1
    }
    method option-no-done (:$widget) {
        $.no-done=!$.no-done;
        $widget.set-label($.no-done  ?? 'Show _DONE' !! 'Hide _DONE');
        $.reconstruct-tree;
        1
    }
    method option-presentation { # TODO to do this by task and not only for the entire tree
        $.presentation =  $.presentation eq "TEXT" ?? "TODO" !! "TEXT";
        $.om.refresh(self);
        1
    }
    method m-view-hide-image {
        $.view-hide-image =  !$.view-hide-image;
        $.reconstruct-tree;
        1
    }
    method keyword-shortcut ( :$iter,:$keyword --> Int ) {
        $.change=1;
        my Gtk::Task $task=$.search-task-from($.om,$iter);
        $task.keyword=$keyword;
        $.ts.set_value( $iter, 0,$task.display-title($.presentation));
        if $keyword eq 'DONE' {
            my $ds=&d-now();
            if $ds ~~ /<dateorg>/ {
                $task.closed=date-from-dateorg($/{'dateorg'});
            }
        } else {
            $task.closed=OrgMode::Date;
        }
        1
    }
    method edit-keyword {
        if $.highlighted-task {
            if $.highlighted-task.keyword eq "TODO" {
                self.keyword-shortcut(:iter($.highlighted-task.iter),:keyword("DONE"));
            } elsif $.highlighted-task.keyword eq "DONE" {
                self.keyword-shortcut(:iter($.highlighted-task.iter),:keyword(""))}
            else                                {
                self.keyword-shortcut(:iter($.highlighted-task.iter),:keyword("TODO"));
            }
        }
    }
    method highlighted-task {
        my Gtk::Task $task;
#        note 'edit gs: ', $.tv.gtk_tree_view_get_selection.perl;
        my Gnome::Gtk3::TreeSelection $tselect .= new(:treeview($.tv));
#        note 'edit sr: ', $tselect.get-selected-rows(N-GObject);
        if $tselect.count-selected-rows {
            my Gnome::Glib::List $selected-rows .= new(
                :native-object($tselect.get-selected-rows(N-GObject))
            );
            # keep a eye at the front to remove the list later
            my Gnome::Glib::List $copy = $selected-rows.copy;

            if ?$selected-rows { # TODO Change in 'while' where manage selected multi-line
                my Gnome::Gtk3::TreePath $tp .= new(:native-object(
                    nativecast( N-GObject, $selected-rows.data)
                ));
    #            note "tp ", $tp.to-string;
                my Gnome::Gtk3::TreeIter $iter;
    #            $iter = $.ts.get-iter($tp); # TODO expected Gnome::Gtk3::TreePath::N-GtkTreePath but got N-GObject (N-GObject.new)
                $iter = $.ts.get-iter-from-string($tp.to-string);
    #            note "it ",$iter;
                $task=$.search-task-from($.om,$iter);
    #            note "ta ",$task.title;
                $selected-rows .= next;
            }
            $copy.clear-object;
        } # TODO implemented "else", case of there are not task highlighted, that is possible if file is empty, improbable but...
        return $task;
    }
    method show-all {
        $.tv.expand-all;
        1
    }
    method iter-get-indices($task) { # find indices IN treestore, not tasks
        if $task.iter.defined && $task.iter.is-valid {
            return  $.ts.get-path($task.iter).get-indices
        }
        return;
    }
    method is-my-iter($task,$iter) {
        # $_.iter ne $iter # TODO doesn't work, why ?
        return $task.iter && $task.iter.is-valid && $.iter-get-indices($task) eq $.ts.get-path($iter).get-indices;
    }
    method search-task-from($task,$iter) {
        if $.is-my-iter($task,$iter) {
            return $task;
        } else {
            if $task.tasks {
                for $task.tasks.Array {
                    my $find=self.search-task-from($_,$iter);
                    return $find if $find;
                }
            }
        }
        return;                 # if click on text 
    }
    method delete-branch($iter) {
        $.change=1;
        my Gtk::Task $task=$.search-task-from($.om,$iter);
        $task.darth-vader.tasks = grep { !$.is-my-iter($_,$iter) }, $task.darth-vader.tasks;
        $.ts.gtk-tree-store-remove($iter);
    }
    method cut-branch($iter) {
        $.change=1;
        $task-cut=$.search-task-from($.om,$iter);
        $task-cut.darth-vader.tasks = grep { !$.is-my-iter($_,$iter) }, $task-cut.darth-vader.tasks;
        $.ts.gtk-tree-store-remove($iter);
    }
    method paste-branch($iter) {
        $.change=1;
        my Gtk::Task $task=$.search-task-from($.om,$iter);
        $task-cut.darth-vader=$task;
        $task-cut.change-stars($task.stars+1);
        push($task.tasks,$task-cut);
        self.reconstruct-tree;
        #$.unfold-branch; # TODO work for stars 1, not sub-stars. To correct when don't use "reconstruct-tree'
    }
    method expand-row($task,$child) {
        $.tv.expand-row($.ts.get-path($task.iter),$child);
    }
    method create-task(Gtk::Task $task, Gnome::Gtk3::TreeIter $iter?, Int $pos = -1, Bool :$cond = True) {
        if  !$cond || # if conditionnal, possibility to filter, else create all sub task
            $task.stars==0 || (                                 # display always the base stars
                !($task.keyword && $task.keyword eq 'DONE' && $.no-done)       # by default, don't display DONE
                && (!$.prior-A    || $task.is-child-prior("A"))
                && (!$.prior-B    || $task.is-child-prior("B") || $task.is-child-prior("A"))
                && (!$.prior-C    || $task.is-child-prior("C") || $task.is-child-prior("B") || $task.is-child-prior("A"))
                && (!$.today-past || $task.is-in-past-and-no-done)
                && (!$.g-find      || $task.find($.g-find))
                && (!$.g-tag       || $task.content-tag($.g-tag))
                ) { 
            my Gnome::Gtk3::TreeIter $iter-task;
            my Gnome::Gtk3::TreeIter $parent-iter;
            if ($task.stars>0) {
                if ($task.stars==1) {
                    my Gnome::Gtk3::TreePath $tp .= new(:string($.count-row++.Str));
                    $parent-iter = $.ts.get-iter($tp); # TODO use "append" :refactoring:
                } else {
                    $parent-iter = $iter;
                }
                $iter-task = $.ts.insert-with-values($parent-iter, $pos, 
                                        0, $task.display-title($.presentation),
                                        2, $task.display-tags($.presentation),
                                        );
                if $task.text {
#                    for $task.text.Array { # TODO presently, text is not really array, juste one multi-line string :refactoring:
                        if $.view-hide-image && $task.text[0] ~~ / "[[" ("./img/" .+ ) "]]" / {
                            $.ts.insert-with-values($iter-task,  0, 
                                                    0, $task.display-text-without-image($.presentation),
                                                    1, $task.get-image
                                                    )
                        } else {
                            $.ts.insert-with-values($iter-task,  0, 
                                                    0, $task.display-text($.presentation),
                                                    )
                        }
#                    }
                }
                $task.iter=$iter-task;
            }
            if $task.tasks {
                for $task.tasks.Array {
                    $.create-task($_,$iter-task,:cond($cond));
                }
            }
        }
    }
    method swap($task1,$task2) {
        my $line1=$.search-indice($task1);
        my $line2=$.search-indice($task2);
        $task1.darth-vader.tasks[$line1,$line2] = $task1.darth-vader.tasks[$line2,$line1];
    }
    method search-indice($task) { # it's the indice on my tree, not Gtk::Tree # TODO to improve
        my $i=-1;
        if $task.darth-vader.tasks {
            for $task.darth-vader.tasks.Array {
                $i++;
                return $i if $.is-my-iter($_,$task.iter);
            }
        }
        return -1;
    }
    method default {
        my Gtk::Task $task.=new(
            :title("In the beginning was the Task"),
            :keyword('TODO'),
            :stars(1),
            :darth-vader($!om));
        $.create-task($task,:cond(False));
        $!om.tasks.push($task);
    }
    multi method highlighted(Gnome::Gtk3::TreePath $tp) {
        my Gnome::Gtk3::TreeSelection $tselect .= new(:treeview($.tv));
        $tselect.select-path($tp);
    }
    multi method highlighted(Gtk::Task $child) {
        my Gnome::Gtk3::TreePath $tp = $.ts.get-path($child.iter);
        $.highlighted($tp);
    }
    multi method highlighted(Str $path) {
        my Gnome::Gtk3::TreePath $tp .= new(:string($path));
        $.highlighted($tp);
    }
    method reconstruct-tree { # not good practice, not abuse 
        $.count-row=0;
        $.ts.clear;
        $.create-task($!om);
        $!om.iter=Nil; # TODO Why it's necessary. Analyze and fix :refactoring:
        $.highlighted("0");
    }
    method choice-find ($top-window) {
        my Gnome::Gtk3::Dialog $dialog .= new(
            :title("Enter a word"), 
            :parent($top-window),
            :flags(GTK_DIALOG_DESTROY_WITH_PARENT),
            :button-spec( [
                "_Cancel", GTK_RESPONSE_CANCEL,
                "_Ok", GTK_RESPONSE_OK, 
            ] )
        );
        my Gnome::Gtk3::Box $content-area .= new(:native-object($dialog.get-content-area));
        my Gnome::Gtk3::Entry $find-edit .= new;
        $find-edit.register-signal( self, 'find-edit', 'key-press-event', :dialog($dialog));
        $content-area.gtk_container_add($find-edit);

        $dialog.show-all;
        $dialog.set-default-response(GTK_RESPONSE_OK);
        my $response = $dialog.gtk-dialog-run;
        if $response == GTK_RESPONSE_OK {
            $.g-find=$find-edit.get-text;
        }
        $dialog.gtk_widget_destroy;
        $.g-find.chars>0 ?? $response !! GTK_RESPONSE_CANCEL;
    }
    method clear-sparse {
        $.no-done=True;
        $.prior-A=False;
        $.prior-B=False;
        $.prior-C=False;
        $.today-past=False;
        $.g-find=Nil;
        $.g-tag=Nil;
    }
    method choice-tags (@tags,$top-window) {
        my Gnome::Gtk3::Dialog $dialog .= new(
            :title("Choice a tag"), 
            :parent($top-window),
            :flags(GTK_DIALOG_DESTROY_WITH_PARENT),
            :button-spec( [
                "_Cancel", GTK_RESPONSE_CANCEL,
            ] )
        );
        my Gnome::Gtk3::Box $content-area .= new(:native-object($dialog.get-content-area));
        my Gnome::Gtk3::ListStore $ls .= new(:field-types( G_TYPE_STRING));

        my Gnome::Gtk3::TreeView $tv .= new(:model($ls));
        $tv.set-activate-on-single-click(1);
        $tv.set-hexpand(1);
        $tv.set-vexpand(1);
        $tv.set-headers-visible(1);
        $content-area.gtk_container_add($tv);

        my Gnome::Gtk3::CellRendererText $crt1 .= new;
        my Gnome::Gtk3::TreeViewColumn $tvc .= new;
        $tvc.set-title('Tag');
        $tvc.pack-end( $crt1, 1);
        $tvc.add-attribute( $crt1, 'text', 0);
        $tv.append-column($tvc);

        for @tags -> $row {
            my $iter = $ls.gtk-list-store-append;
            $ls.gtk-list-store-set( $iter, |$row.kv);
        }

        $dialog.show-all;
        $tv.register-signal( self, 'tv-tag-click', 'row-activated',:ls($ls),:tags(@tags),:dialog($dialog));
        my $response = $dialog.gtk-dialog-run;
        $dialog.gtk_widget_destroy;
        $response;
    }
    method verifiy-read($name) {
        self.save("test.org");
        my $proc =     run 'diff','-Z',"$name",'test.org';
        say "Input file and save file are different. Problem with syntax or bug.
            You can view and edit the file, but it's may be wrong.
            Don't save if not sure." if $proc.exitcode; 
    }
    method file-read-with-name($name) {
        spurt $name~".bak",slurp $name; # fast backup
#        my $i=1;                                                   # TODO finalize to :0.2:
#        repeat {
#            my $proc=run 'head',"--lines=$i","$name",:out;
#            note $i++;
#            my $file=$proc.out.slurp(:close);
            my $file=slurp $name; # Warning mettre "slurp $name" directement dans la ligne suivante 
                                    # fait foirer la grammaire (content ne match pas) . Bizarre.
            my OrgMode::Task $document = OrgMode.parse( $file, :actions(OrgMode::Actions) ).made;
            self.om=Gtk::Task.from-orgmode($document);
            if !self.om {
                my Gnome::Gtk3::MessageDialog $md .=new(
                                    :message('This file is not recognized as a org file by org-mode-gtk.raku'),
                                    :buttons(GTK_BUTTONS_OK)
                );
                $md.run;
                exit;
            }
#        } while self.om;
        self.om.title=$name;   # TODO to refactor
#        say self.om;
#        say Dump(self.om , :max-recursion(2));
#        say Dump self.om; # doesn't work, probably because recursivity with darth-vader
#        say self.om.to-text;
#        self.om.inspect;
#        self.verifiy-read($name) if $debug; # TODO to reactivate :0.x:
        self.create-task(self.om);
        $!top-window.set-title('Org-Mode with GTK and raku : ' ~ split(/\//,$.om.title).Array.pop) if $.om.title;
    }
    method file-exist($filename) {
        if $filename.IO.f {
            1;
        } else {
            my Gnome::Gtk3::MessageDialog $md .=new(
                                :message("The file $filename doesn't exists !"),
                                :buttons(GTK_BUTTONS_NONE)
            );
            $md.add-button("Create a new file", 1); # TODO use add_buttons.
            $md.add-button("Exit", 2);
            my $button=$md.run;
            if $button==1 {
                $md.destroy;
                return 0;
            } else {
                exit;
            }
        }
    }
    method file-read($filename) {
        if $filename && $.file-exist($filename) {
            $.file-read-with-name($filename);
        } else {
            $.default;
        }
    }
    method file-save-as {
        my Gnome::Gtk3::FileChooserDialog $dialog .= new(
            :title("Choose File"), 
            :parent($!top-window),
            :action(GTK_FILE_CHOOSER_ACTION_SAVE),
            :button-spec( [
                "_Cancel", GTK_RESPONSE_CANCEL,
                "_Save", GTK_RESPONSE_ACCEPT
            ] )
        );
        my $response = $dialog.gtk-dialog-run;
        if $response == GTK_RESPONSE_ACCEPT {
            my $filename = $dialog.get-filename;
            my @path=split(/\//,$filename); # TODO [#C] rewrite with module File::Utils
            my $name=pop(@path);
            $filename ~= ".org" if !($name ~~ /\./);
            if $filename.IO.e {
                my Gnome::Gtk3::MessageDialog $md .=new(
                                    :message("The file already exists, do you want to overwrite it ?"),
                                    :buttons(GTK_BUTTONS_NONE)
                );
                $md.add-button("_Yes", GTK_RESPONSE_YES); # TODO use add_buttons.
                $md.add-button("_No", GTK_RESPONSE_NO);
                my $button=$md.run;
                if $button==GTK_RESPONSE_YES {
                    $!om.title = $filename;
                    $.save;
                    $!top-window.set-title('Org-Mode with GTK and raku : ' ~ split(/\//,$.om.title).Array.pop) if $.om.title;
                } else {
                    $response=GTK_RESPONSE_CANCEL; # TODO if no, no close dialog file-save-as
                }
                $md.destroy;
            } else {
                $!om.title = $filename;
                $.save;
                $!top-window.set-title('Org-Mode with GTK and raku : ' ~ split(/\//,$.om.title).Array.pop) if $.om.title; # TODO rewrite with module File::Utils
            }
        }
        $dialog.gtk-widget-hide; # TODO destroy ?
        return $response;
    }
    method save ($name?) {
        $.change=0 if !$name;
        spurt $name ?? $name !! $!om.title, $!om.to-text;
    }
    method try-save {
        if $.change && (!$!om.title || $!om.title ne "demo.org") {
            my Gnome::Gtk3::MessageDialog $md .=new(
                                :message('Do you like save your file ?'),
                                :buttons(GTK_BUTTONS_NONE)
            );
            $md.add-button("_Yes", GTK_RESPONSE_YES); # TODO use add_buttons. Uncomment =head2 [[gtk_] dialog_] add_buttons Dialog.pm
            $md.add-button("_No", GTK_RESPONSE_NO);
            $md.add-button("_Cancel", GTK_RESPONSE_CANCEL);
            my $button=$md.run;
            if $button==GTK_RESPONSE_YES {
                if $!om.title {
                    $.save 
                } else {
                    $button = $.file-save-as;
                }
            }
            $md.destroy;
            return $button;
        }
    }
    method update-text($iter,$new-text) {
        my Gtk::Task $task=$.search-task-from($.om,$iter);
        $task.text=$new-text; #.split(/\n/); # TODO old version use one row for one line, to reactivate :0.x:
        my $iter_child=$.ts.iter-children($iter);
        # remove all lines "text"
        while $iter_child.is-valid && !$.search-task-from($.om,$iter_child) { # if no task associate to a task, it's a "text"
            $.ts.gtk-tree-store-remove($iter_child);
            $iter_child=$.ts.iter-children($iter);
        }
        if $task.text && $task.text.chars>0 {
#            for $task.text.Array.reverse {
                if $.view-hide-image && $task.text[0] ~~ / "[[" ("./img/" .+ ) "]]" / {
                    $.ts.insert-with-values($iter,  0, 
                                                    0, $task.display-text-without-image($.presentation),
                                                    1, $task.get-image
                                                    )
                } else {
                    $.ts.insert-with-values($iter,  0, 
                                                0, $task.display-text($.presentation),
                                                )
                }
#            }
            $.expand-row($task,0);
        }
    }
    method get-iter-from-path(@path) {
        my Gnome::Gtk3::TreePath $tp .= new(:indices(@path));
        return $.ts.get-iter($tp);
    }
    method brother($iter,$inc) {
        my @path2= $.ts.get-path($iter).get-indices.Array;
        @path2[*-1]=@path2[*-1].Int;
        @path2[*-1]+=$inc;
        my Gnome::Gtk3::TreePath $tp .= new(:indices(@path2));
        return  $.ts.get-iter($tp);
    }
    method fold-branch {
        $.tv.collapse-row($.ts.get-path($.highlighted-task.iter));
    }
    method unfold-branch {
        $.tv.expand-row($.ts.get-path($.highlighted-task.iter),0); # 0 unfold just child, not sub child
    }
    method unfold-branch-child {
        $.tv.expand-row($.ts.get-path($.highlighted-task.iter),1); # 1 unfold all branch
    }
    method zoom (:$choice) {
        $.om.zoom($choice);
        $.om.refresh(self);
    }
    method inspect {
        $.om.inspect;
    }
    method get-top-window {
        $!top-window;
    }
}


