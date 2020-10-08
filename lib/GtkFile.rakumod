use Task;                       # TODO becasue use to-markup. To improve
use GtkTask;
use GramOrgMode;
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

class GtkFile {
    has GtkTask                     $.om            is rw;
    has Gnome::Gtk3::TreeStore      $.ts            ; #.= new(:field-types(G_TYPE_STRING));
    has Gnome::Gtk3::TreeView       $.tv            ; #.= new(:model($!ts));
    has Gnome::Gtk3::ScrolledWindow $.sw             ; #.= new;
    has                             $.i             is rw =0;          # for creation of level1 in tree # TODO [#A] rename
    has Int                         $.change        is rw =0;           # for ask question to save when quit
    has                             $.no-done       is rw =True;       # display with no DONE
    has                             $.prior-A       is rw =False;      # display #A          
    has                             $.prior-B       is rw =False;      # display #B          
    has                             $.prior-C       is rw =False;      # display #C          

    submethod BUILD {
        $!om                  .= new(:level(0)) ; 
        $!ts                  .= new(:field-types(G_TYPE_STRING));
        $!tv                  .= new(:model($!ts));
        $!tv.set-hexpand(1);
        $!tv.set-vexpand(1);
        $!tv.set-headers-visible(0);
        $!tv.set-activate-on-single-click(1);
        $!sw                  .= new;
        $!sw.gtk-container-add($!tv);

        my Gnome::Gtk3::TreeViewColumn $tvc .= new;
        my Gnome::Gtk3::CellRendererText $crt1 .= new;
        $tvc.pack-end( $crt1, 1);
        $tvc.add-attribute( $crt1, 'markup', 0);
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
    method expand-row($task,$child) {
        $.tv.expand-row($.ts.get-path($task.iter),$child);
    }
    method create-task(GtkTask $task, Gnome::Gtk3::TreeIter $iter?,$pos = -1) {
        my Gnome::Gtk3::TreeIter $iter-task;
        if $task.level==0 || (                                 # display always the base level
            !($task.todo && $task.todo eq 'DONE' && $.no-done)       # by default, don't display DONE
            && (!$.prior-A || $task.is-child-prior("A"))
            && (!$.prior-B || $task.is-child-prior("B") || $task.is-child-prior("A"))
            && (!$.prior-C || $task.is-child-prior("C") || $task.is-child-prior("B") || $task.is-child-prior("A"))
        ) { 
            my Gnome::Gtk3::TreeIter $parent-iter;
            if ($task.level>0) {
                if ($task.level==1) { 
                    my Gnome::Gtk3::TreePath $tp .= new(:string($.i++.Str));
                    $parent-iter = $.ts.get-iter($tp);
                } else {
                    $parent-iter = $iter;
                }
                $iter-task = $.ts.insert-with-values($parent-iter, $pos, 0, $task.display-header);
                if $task.text {
                    for $task.text.Array {
                        my Gnome::Gtk3::TreeIter $iter_t2 = $.ts.insert-with-values($iter-task, -1, 0, to-markup($_))
                    }
                }
                $task.iter=$iter-task;
            }
            if $task.tasks {
                for $task.tasks.Array {
                    $.create-task($_,$iter-task);
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
        $.create-task($task);
        $!om.tasks.push($task);
    }
    method reconstruct-tree { # not good practice, not abuse 
        $.i=0; # TODO [#B] to remove ?
        $.ts.clear;
        $!om.delete-iter;
        $.create-task($!om);
    }
    my $lvl=0;
    method inspect($task) {
        say "ind : ",$.iter-get-indices($task), " lvl:",$lvl," ",$task.header, " lvl:",$task.level, " pr:",$task.priority;
#        say $task.herite-properties('presentation');
        if $task.tasks {
            for $task.tasks.Array {
                $lvl++;
                $.inspect($_);
                $lvl--;
            }
        }
    }
    method verifiy-read($name) {
        self.save("test.org");
        my $proc =     run 'diff','-Z',"$name",'test.org';
        say "Input file and save file are different. Problem with syntax or bug.
            You can view and edit the file, but it's may be wrong.
            Don't save if not sure." if $proc.exitcode; 
    }
    method open-file-with-name($name) {
        spurt $name~".bak",slurp $name; # fast backup
        my $file=slurp $name; # Warning mettre "slurp $name" directement dans la ligne suivante 
                                # fait foirer la grammaire (content ne match pas) . Bizarre.
        self.om=OrgMode.parse($file,:actions(OM-actions)).made;
        self.om.header=$name;   # TODO [#B] to refactor
    #    say Dump self.om;
    #    say self.om.to-text;
#        self.verifiy-read($name) if $debug; # TODO to reactivate :0.x:
        self.create-task(self.om);
    }
    method open-file($filename) {
        if $filename {
            self.open-file-with-name($filename);
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
#                "_Ok", GTK_RESPONSE_OK,
                "_Cancel", GTK_RESPONSE_CANCEL,
                "_Open", GTK_RESPONSE_ACCEPT
            ] )
        );
        my $response = $dialog.gtk-dialog-run;
        if $response == GTK_RESPONSE_ACCEPT {
            $!om.header = $dialog.get-filename;
            my @path=split(/\//,$!om.header); # TODO [#C] rewrite with module File::Utils
            my $name=pop(@path);
            $!om.header~=".org" if !($name ~~ /\./);
            $.save if $!om.header;
        }
        $dialog.gtk-widget-hide; # TODO destroy ?
        1
    }
    method save ($name?) {
        $.change=0 if !$name;
        spurt $name ?? $name !! $!om.header, $!om.to-text;
    }
    method try-save($top-window) {
        if $.change && (!$!om.header || $!om.header ne "demo.org") {
            my Gnome::Gtk3::MessageDialog $md .=new(
                                :message('Voulez-vous sauver votre fichier ?'),
                                :buttons(GTK_BUTTONS_NONE)
            ); # TODO Add a Cancel and return true/false. Try for :0.1:
            $md.add-button("_Yes", GTK_RESPONSE_YES); # TODO use add_buttons. Uncomment =head2 [[gtk_] dialog_] add_buttons Dialog.pm
            $md.add-button("_No", GTK_RESPONSE_NO);
            $md.add-button("_Cancel", GTK_RESPONSE_CANCEL);
            my $button=$md.run;
            if $button==GTK_RESPONSE_YES {
                $!om.header ?? $.save !! $.file-save-as($top-window);
            }
            $md.destroy;
            return $button; # TODO return file-save-as button is "cancel". try for :0.1:
        }
    }
}


