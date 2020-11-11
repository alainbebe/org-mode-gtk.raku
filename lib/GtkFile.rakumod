use Task;                       # TODO becasue use to-markup. To improve
use GtkTask;
use GramOrgMode;

use Gnome::N::N-GObject;
use Gnome::GObject::Type;
use Gnome::GObject::Value;
use Gnome::Gtk3::TreeStore;
use Gnome::Gtk3::TreeView;
use Gnome::Gtk3::ScrolledWindow;
use Gnome::Gtk3::CellRendererText;
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

use Data::Dump;

my $g-tag;    # TODO remove global value :refactoring:
my $g-find;   # TODO remove global value :refactoring:
my $task-cut; # TODO remove global value, in fact, task-cut is global var for program, not GtkFile (to analyse when notebook) :refactoring:

class AppSignalHandlers2 {
    method tv-tag-click (N-GtkTreePath $path, N-GObject $column , :$ls, :@tags, :$dialog) {
        my Gnome::Gtk3::TreePath $tree-path .= new(:native-object($path));
        my Gnome::Gtk3::TreeIter $iter = $ls.tree-model-get-iter($tree-path);
        my $value = $ls.tree-model-get-value($iter,0);
        $g-tag=@tags[$tree-path.to-string];
        $dialog.gtk_widget_destroy;
    }
}
class GtkFile {
    has GtkTask                     $.om            is rw;
    has Gnome::Gtk3::TreeStore      $.ts            ; #.= new(:field-types(G_TYPE_STRING));
    has Gnome::Gtk3::TreeView       $.tv            ; #.= new(:model($!ts));
    has Gnome::Gtk3::ScrolledWindow $.sw            ; #.= new;
    has                             $.i             is rw =0;       # TODO [#A] for creation of level 1 in tree, rename :refactoring:
    has Int                         $.change        is rw =0;       # for ask question to save when quit
    has                             $.no-done       is rw =True;    # display with no DONE
    has                             $.prior-A       is rw =False;   # display #A          
    has                             $.prior-B       is rw =False;   # display #B          
    has                             $.prior-C       is rw =False;   # display #C          
    has                             $.today-past    is rw =False;   # display only task in past and note Done          

    submethod BUILD {
        $!om                  .= new(:level(0)) ; 
        $!ts                  .= new(:field-types(G_TYPE_STRING, G_TYPE_STRING));
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
        my Gnome::Gtk3::CellRendererText $crt2 .= new;
        $tvc.pack-end( $crt2, 1);
        $tvc.add-attribute( $crt2, 'markup', 1);
        $!tv.append-column($tvc);
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
        my $task=$.search-task-from($.om,$iter);
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
        my $task=$.search-task-from($.om,$iter);
        $task-cut.darth-vader=$task;
        $task-cut.change-level($task.level+1);
        push($task.tasks,$task-cut);
        self.reconstruct-tree;
        $.unfold-branch($task); # TODO work for level 1, not sub-level. To correct when don't use "reconstruct-tree'
    }
    method expand-row($task,$child) {
        $.tv.expand-row($.ts.get-path($task.iter),$child);
    }
    method create-task(GtkTask $task, Gnome::Gtk3::TreeIter $iter?, Int $pos = -1, Bool :$cond = True) {
        if  !$cond || # if conditionnal, possibility to filter, else create all sub task
            $task.level==0 || (                                 # display always the base level
                !($task.todo && $task.todo eq 'DONE' && $.no-done)       # by default, don't display DONE
                && (!$.prior-A    || $task.is-child-prior("A"))
                && (!$.prior-B    || $task.is-child-prior("B") || $task.is-child-prior("A"))
                && (!$.prior-C    || $task.is-child-prior("C") || $task.is-child-prior("B") || $task.is-child-prior("A"))
                && (!$.today-past || $task.is-in-past-and-no-done)
                && (!$g-find      || $task.find($g-find))
                && (!$g-tag       || $task.content-tag($g-tag))
                ) { 
            my Gnome::Gtk3::TreeIter $iter-task;
            my Gnome::Gtk3::TreeIter $parent-iter;
            if ($task.level>0) {
                if ($task.level==1) { 
                    my Gnome::Gtk3::TreePath $tp .= new(:string($.i++.Str));
                    $parent-iter = $.ts.get-iter($tp);
                } else {
                    $parent-iter = $iter;
                }
                $iter-task = $.ts.insert-with-values($parent-iter, $pos, 0, $task.display-header,1,$task.display-tags);
                if $task.text {
                    for $task.text.Array {
                        my Gnome::Gtk3::TreeIter $iter_t2 = $.ts.insert-with-values($iter-task, -1, 0, to-markup($_))
                    }
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
        my GtkTask $task.=new(:header("In the beginning was the Task"),:todo('TODO'),:level(1),:darth-vader($!om));
        $.create-task($task,:cond(False));
        $!om.tasks.push($task);
    }
    method reconstruct-tree { # not good practice, not abuse 
        $.i=0; # TODO [#B] to remove ?
        $.ts.clear;
        $!om.delete-iter;
        $.create-task($!om);
        my Gnome::Gtk3::TreePath $tp .= new(:string("0"));
        my Gnome::Gtk3::TreeSelection $tselect .= new(:treeview($.tv));
        $tselect.select-path($tp);
    }
    method clear-find {
        $g-find=Nil;
    }
    method choice-find ($top-window) {
        my Gnome::Gtk3::Dialog $dialog .= new(
            :title("Enter a word"), 
            :parent($top-window),
            :flags(GTK_DIALOG_DESTROY_WITH_PARENT),
            :button-spec( [
                "_Ok", GTK_RESPONSE_OK, 
                "_Cancel", GTK_RESPONSE_CANCEL,
            ] )
        );
        my Gnome::Gtk3::Box $content-area .= new(:native-object($dialog.get-content-area));
        my Gnome::Gtk3::Entry $e-edit .= new;
        $content-area.gtk_container_add($e-edit);

        $dialog.show-all;
        my $response = $dialog.gtk-dialog-run;
        if $response == GTK_RESPONSE_OK {
            $g-find=$e-edit.get-text;
        }
        $dialog.gtk_widget_destroy;
    }
    method clear-tag {
        $g-tag=Nil;
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
        my AppSignalHandlers2 $ash .= new();
        $tv.register-signal( $ash, 'tv-tag-click', 'row-activated',:ls($ls),:tags(@tags),:dialog($dialog));
        my $response = $dialog.gtk-dialog-run;
        $dialog.gtk_widget_destroy;
    }
    method verifiy-read($name) {
        self.save("test.org");
        my $proc =     run 'diff','-Z',"$name",'test.org';
        say "Input file and save file are different. Problem with syntax or bug.
            You can view and edit the file, but it's may be wrong.
            Don't save if not sure." if $proc.exitcode; 
    }
    method file-open-with-name($name,$top-window) {
        spurt $name~".bak",slurp $name; # fast backup
#        my $i=1;                                                   # TODO finalize to :0.2:
#        repeat {
#            my $proc=run 'head',"--lines=$i","$name",:out;
#            note $i++;
#            my $file=$proc.out.slurp(:close);
            my $file=slurp $name; # Warning mettre "slurp $name" directement dans la ligne suivante 
                                    # fait foirer la grammaire (content ne match pas) . Bizarre.
            self.om=OrgMode.parse($file,:actions(OM-actions)).made;
            if !self.om {
                my Gnome::Gtk3::MessageDialog $md .=new(
                                    :message('This file is not recognized as a org file by org-mode-gtk.raku'),
                                    :buttons(GTK_BUTTONS_OK)
                );
                $md.run;
                exit;
            }
#        } while self.om;
        self.om.header=$name;   # TODO [#B] to refactor
#        say self.om;
#        say Dump(self.om , :max-recursion(2));
#        say Dump self.om; # doesn't work, probably because recursivity with darth-vader
#        say self.om.to-text;
#        self.om.inspect;
#        self.verifiy-read($name) if $debug; # TODO to reactivate :0.x:
        self.create-task(self.om);
        $top-window.set-title('Org-Mode with GTK and raku : ' ~ split(/\//,$.om.header).Array.pop) if $.om.header;
    }
    method file-open($filename,$top-window) {
        if $filename {
            self.file-open-with-name($filename,$top-window);
        } else {
            self.default;
        }
    }
    method file-save-as($top-window) {
        my Gnome::Gtk3::FileChooserDialog $dialog .= new(
            :title("Choose File"), 
            :parent($top-window),
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
                    $!om.header = $filename;
                    $.save;
                    $top-window.set-title('Org-Mode with GTK and raku : ' ~ split(/\//,$.om.header).Array.pop) if $.om.header;
                } else {
                    $response=GTK_RESPONSE_CANCEL; # TODO if no, no close dialog file-save-as
                }
                $md.destroy;
            } else {
                $!om.header = $filename;
                $.save;
                $top-window.set-title('Org-Mode with GTK and raku : ' ~ split(/\//,$.om.header).Array.pop) if $.om.header; # TODO rewrite with module File::Utils
            }
        }
        $dialog.gtk-widget-hide; # TODO destroy ?
        return $response;
    }
    method save ($name?) {
        $.change=0 if !$name;
        spurt $name ?? $name !! $!om.header, $!om.to-text;
    }
    method try-save($top-window) {
        if $.change && (!$!om.header || $!om.header ne "demo.org") {
            my Gnome::Gtk3::MessageDialog $md .=new(
                                :message('Do you like save your file ?'),
                                :buttons(GTK_BUTTONS_NONE)
            );
            $md.add-button("_Yes", GTK_RESPONSE_YES); # TODO use add_buttons. Uncomment =head2 [[gtk_] dialog_] add_buttons Dialog.pm
            $md.add-button("_No", GTK_RESPONSE_NO);
            $md.add-button("_Cancel", GTK_RESPONSE_CANCEL);
            my $button=$md.run;
            if $button==GTK_RESPONSE_YES {
                if $!om.header { 
                    $.save 
                } else {
                    $button = $.file-save-as($top-window);
                }
            }
            $md.destroy;
            return $button;
        }
    }
    method update-text($iter,$new-text) {
        my $task=$.search-task-from($.om,$iter);
        $task.text=$new-text.split(/\n/);
        my $iter_child=$.ts.iter-children($iter);
        # remove all lines "text"
        while $iter_child.is-valid && !$.search-task-from($.om,$iter_child) { # if no task associate to a task, it's a "text"
            $.ts.gtk-tree-store-remove($iter_child);
            $iter_child=$.ts.iter-children($iter);
        }
        if $task.text && $task.text.chars>0 {
            for $task.text.Array.reverse {
                my Gnome::Gtk3::TreeIter $iter_t2 = $.ts.insert-with-values($iter, 0, 0, to-markup($_)) 
            }
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
    method fold-branch ($task) {
        $.tv.collapse-row($.ts.get-path($task.iter));
    }
    method unfold-branch ($task) {
        $.tv.expand-row($.ts.get-path($task.iter),0); # 0 unfold just child, not sub child
    }
    method unfold-branch-child ($task) {
        $.tv.expand-row($.ts.get-path($task.iter),1); # 1 unfold all branch
    }
}


