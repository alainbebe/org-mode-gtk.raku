use DateOrg;
use GtkManageDate;

use Gnome::N::N-GObject;
use Gnome::GObject::Type;
use Gnome::Gtk3::Window;
use Gnome::Gtk3::Box;
use Gnome::Gtk3::Grid;
use Gnome::Gtk3::Entry;
use Gnome::Gtk3::Label;
use Gnome::Gtk3::RadioButton;
use Gnome::Gtk3::Button;
use Gnome::Gtk3::ListStore;
use Gnome::Gtk3::TreeView;
use Gnome::Gtk3::ScrolledWindow;
use Gnome::Gtk3::CellRendererText;
use Gnome::GObject::Value;
use Gnome::Gtk3::TreeViewColumn;
use Gnome::Gtk3::TextBuffer;
use Gnome::Gtk3::TextView;
use Gnome::Gtk3::TreeIter;
use Gnome::Gtk3::TextIter;
use Gnome::Gtk3::TreePath;
use Gnome::Gtk3::Dialog;
use Gnome::Gtk3::Entry;
use Gnome::Gtk3::Button;
use Gnome::Gdk3::Events;
use Gnome::Gdk3::Keysyms;

class GtkEditTask {
    has Gnome::Gtk3::Window $!top-window;
    has Gnome::Gtk3::Dialog $dialog;
    has Gnome::Gtk3::Entry $e-edit-tags;
    has Gnome::Gtk3::Entry $e-edit-text;
    has Gnome::Gtk3::TextBuffer $text-buffer;
    has Gnome::Gtk3::Button $b-closed;
    has Gnome::Gtk3::TreeIter $iter;


    submethod BUILD ( Gnome::Gtk3::Window:D :$!top-window! ) { }

    multi method create-button($label,$method,$iter?,$inc?) {
#        note "create button by default" if $debug;
        my Gnome::Gtk3::Button $b  .= new(:label($label));
        $b.register-signal(self, $method, 'clicked',:iter($iter),:inc($inc));
        return $b;
    }
    method go-to-link ( :$iter ) { # TODO it's not iter, but text. To refactoring
#        my $proc = run '/opt/firefox/firefox', '--new-tab', $edit;
        shell "/opt/firefox/firefox --new-tab $iter";
        1
    }
    method clear-tags-button-click ( :$iter ) {
        $e-edit-tags.set-text("");
        1
    }
    method header-event-after ( N-GdkEventKey $event-key, :$widget ) {
        $dialog.set-response-sensitive(GTK_RESPONSE_OK,$widget.get-text.trim.chars>0);
        $dialog.response(GTK_RESPONSE_OK)
            if $event-key.keyval.fmt('0x%08x')==GDK_KEY_Return 
                && $widget.get-text.trim.chars>0;
        1
    }
    method tag-event-after ( N-GdkEventKey $event-key, :$widget-header ) {
        $dialog.response(GTK_RESPONSE_OK)
            if $event-key.keyval.fmt('0x%08x')==GDK_KEY_Return
                && $widget-header.get-text.trim.chars>0;
        1
    }
    method text-event-after ( N-GdkEventKey $event-key, :$widget-header ) {
        $dialog.response(GTK_RESPONSE_OK)
            if $event-key.state == 4 # ctrl push
                && $event-key.keyval.fmt('0x%08x')==GDK_KEY_Return
                    && $widget-header.get-text.trim.chars>0;
        1
    }
    method scheduled ( :$widget, :$task , :$gf) {
        $gf.change=1;
        my $t = $task ?? $task !! $gf.highlighted-task;
        my GtkManageDate $md .=new(:top-window($!top-window));
        $t.scheduled=$md.manage-date($t.scheduled);
        $widget.set-label($t.scheduled ?? $t.scheduled.str !! "-") if $widget;
        1
    }
    method clear-scheduled ( :$task, :$button, :$gf ) {
        $gf.change=1;
        $task.scheduled=Nil;
        $button.set-label('-');
        1
    }
    method deadline ( :$widget, :$task , :$gf) {
        $gf.change=1;
        my $t=$task ?? $task !! $gf.highlighted-task;
        my GtkManageDate $md .=new(:top-window($!top-window));
        $t.deadline=$md.manage-date($t.deadline);
        $widget.set-label($t.deadline ?? $t.deadline.str !! "-") if $widget;
        1
    }
    method clear-deadline ( :$task, :$button, :$gf ) {
        $gf.change=1;
        $task.deadline=Nil;
        $button.set-label('-');
        1
    }
    method closed ( :$widget, :$task , :$gf) {
        $gf.change=1;
        my GtkManageDate $md .=new(:top-window($!top-window));
        $task.closed=$md.manage-date($task.closed);
        $widget.set-label($task.closed.str);
        1
    }
    method clear-closed ( :$task, :$button, :$gf ) {
        $gf.change=1;
        $task.closed=Nil;
        $button.set-label('-');
        1
    , :$gf}
    method property-edited (Str $path, Str $new-text, :$ls, :$col) {
        my @path=($path.Int);
        my Gnome::Gtk3::TreePath $tp .= new(:indices(@path));
        my Gnome::Gtk3::TreeIter $iter = $ls.tree-model-get-iter($tp);
        $ls.set-value( $iter, $col, $new-text);
        1
    }
    method properties-row-activated (N-GtkTreePath $path, N-GObject $column, :$ls) {
        my Gnome::Gtk3::TreePath $tree-path .= new(:native-object($path));
        my Gnome::Gtk3::TreeIter $iter = $ls.get-iter($tree-path);
        $ls.remove($iter);
        1
    }
    method new-property (:$ls) {
        my $iter=$ls.list-store-append;
        $ls.set-value( $iter, 2, 'X');
        1
    }
    method edit-task($task,$gf) {
        # Dialog to edit task
        $dialog .= new(
            :title("Edit task"),          # TODO doesn't work if multi-tab. Very strange. Fix in :0.x:
            :parent($!top-window),
            :flags(GTK_DIALOG_DESTROY_WITH_PARENT),
            :button-spec( [
                "_Cancel", GTK_RESPONSE_CANCEL,
                "_Ok", GTK_RESPONSE_OK,   # TODO OK by default if "enter"
                ] )
        );
        $dialog.set-default-response(GTK_RESPONSE_OK);
        my Gnome::Gtk3::Box $content-area .= new(:native-object($dialog.get-content-area));
        my Gnome::Gtk3::Grid $g .= new;
        $content-area.gtk_container_add($g);

        # To edit header
        my Gnome::Gtk3::Entry $e-edit .= new;
        $e-edit.set-text($task.header);
        $g.gtk-grid-attach($e-edit,                                                       0, 0, 4, 1);
        $e-edit.register-signal( self, 'header-event-after', 'event-after');
        $dialog.set-response-sensitive(GTK_RESPONSE_OK,0) if $e-edit.get-text.chars==0;

        # To edit tags
        $e-edit-tags  .= new;
        $e-edit-tags.set-text(join(" ",$task.tags));
        $g.gtk-grid-attach(Gnome::Gtk3::Label.new(:text('Tag')),                          0, 1, 1, 1);
        $g.gtk-grid-attach($e-edit-tags,                                                  1, 1, 2, 1);
        $e-edit-tags.register-signal( self, 'tag-event-after', 'event-after',:widget-header($e-edit));
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
        elsif $task.priority eq 'A' { $rb-pr2.set-active(1);}
        elsif $task.priority eq 'B' { $rb-pr3.set-active(1);} 
        elsif $task.priority eq 'C' { $rb-pr4.set-active(1);} 
        $g.gtk-grid-attach( $rb-pr2,                                                        0, 3, 1, 1);
        $g.gtk-grid-attach( $rb-pr3,                                                        1, 3, 1, 1);
        $g.gtk-grid-attach( $rb-pr4,                                                        2, 3, 1, 1);
        $g.gtk-grid-attach( $rb-pr1,                                                        3, 3, 1, 1);

        # To manage Scheduled
        $g.gtk-grid-attach(Gnome::Gtk3::Label.new(:text('Scheduling')),                     0, 4, 1, 1);
        my Gnome::Gtk3::Button $b-scheduled .= new(:label($task.scheduled ?? $task.scheduled.str !! "-"));
        $b-scheduled.register-signal(self, 'scheduled', 'clicked', :task($task), :gf($gf));
        $g.gtk-grid-attach($b-scheduled,                                                    1, 4, 2, 1);

        my Gnome::Gtk3::Button $b-cs  .= new(:label("X"));
        $b-cs.register-signal(self, 'clear-scheduled', 'clicked',:task($task),:button($b-scheduled), :gf($gf));
        $g.gtk-grid-attach($b-cs,                                                           3, 4, 1, 1);

        # To manage Deadline 
        $g.gtk-grid-attach(Gnome::Gtk3::Label.new(:text('Deadline')),                       0, 5, 1, 1);
        my Gnome::Gtk3::Button $b-deadline .= new(:label($task.deadline ?? $task.deadline.str !! "-"));
        $b-deadline.register-signal(self, 'deadline', 'clicked', :task($task), :gf($gf));
        $g.gtk-grid-attach($b-deadline,                                                     1, 5, 2, 1);

        my Gnome::Gtk3::Button $b-cd  .= new(:label("X"));
        $b-cd.register-signal(self, 'clear-deadline', 'clicked',:task($task),:button($b-deadline), :gf($gf));
        $g.gtk-grid-attach($b-cd,                                                           3, 5, 1, 1);

        if $task.closed {
            $g.gtk-grid-attach(Gnome::Gtk3::Label.new(:text('Closed')),                     0, 6, 1, 1);
            $b-closed  .= new(:label($task.closed ?? $task.closed.str !! "-"));
            $b-closed.register-signal(self, 'closed', 'clicked', :task($task), :gf($gf));
            $g.gtk-grid-attach($b-closed,                                                   1, 6, 2, 1);

            my Gnome::Gtk3::Button $b-cc  .= new(:label("X"));
            $b-cc.register-signal(self, 'clear-closed', 'clicked',:task($task),:button($b-closed), :gf($gf));
            $g.gtk-grid-attach($b-cc,                                                       3, 6, 1, 1);
        }
        
        # To edit properties
        $content-area.gtk_container_add(Gnome::Gtk3::Label.new(:text('Properties')));
        my Gnome::Gtk3::ListStore $properties .= new(:field-types( G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING));
        my Gnome::Gtk3::TreeView $tv .= new(:model($properties));
        $tv.set-hexpand(1);
        $tv.set-vexpand(1);
        $tv.set-headers-visible(1);
        my Gnome::Gtk3::ScrolledWindow $swp .= new;
        $swp.gtk-container-add($tv);
        $content-area.gtk_container_add($swp);

        my Gnome::Gtk3::CellRendererText $crt1 .= new;
        my Gnome::GObject::Value $v .= new( :type(G_TYPE_BOOLEAN), :value<1>);
        $crt1.set-property( 'editable', $v);
        $crt1.register-signal(self, 'property-edited', 'edited', :ls($properties), :col(0));
        my Gnome::Gtk3::TreeViewColumn $tvc .= new;
        $tvc.set-title('Key');
        $tvc.pack-end( $crt1, 1);
        $tvc.add-attribute( $crt1, 'text', 0);
        $tv.append-column($tvc);

        my Gnome::Gtk3::CellRendererText $crt2 .= new;
        $crt2.set-property( 'editable', $v);
        $crt2.register-signal(self, 'property-edited', 'edited', :ls($properties), :col(1));
        $tvc .= new;
        $tvc.set-title('Value');
        $tvc.pack-end( $crt2, 1);
        $tvc.add-attribute( $crt2, 'text', 1);
        $tv.append-column($tvc);

        my Gnome::Gtk3::CellRendererText $crt3 .= new;
        $tvc .= new;
        $tvc.pack-end( $crt3, 1);
        $tvc.add-attribute( $crt3, 'text', 2);
        $tv.append-column($tvc);
        $tv.register-signal( self, 'properties-row-activated', 'row-activated',:ls($properties));

        for $task.properties -> $row {
            $iter = $properties.gtk-list-store-append;
            $properties.gtk-list-store-set( $iter, |$row.kv,2,"X");
        }

        my Gnome::Gtk3::Button $b-prop  .= new(:label("Add Property"));
        $b-prop.register-signal(self, 'new-property', 'clicked',:ls($properties));
        $content-area.gtk_container_add($b-prop);

        
        # To edit text
        $content-area.gtk_container_add(Gnome::Gtk3::Label.new(:text('Content')));
        my Gnome::Gtk3::TextView $tev-edit-text .= new;
        my Gnome::Gtk3::TextBuffer $text-buffer2 .= new(:native-object($tev-edit-text.get-buffer));
        if $task.text {
            my $text=$task.text.join("\n");
            $text-buffer2.set-text($text);
        }
#        $tev-edit-text.register-signal( self, 'text-event-after', 'event-after',:widget-header($e-edit)); # TODO create a new line before send signal, to refactoring :0.2:
        my Gnome::Gtk3::ScrolledWindow $swt .= new;
        $swt.gtk-container-add($tev-edit-text);
        $content-area.gtk_container_add($swt);
#        if $task.text { # TODO enable this if tere are a config.ini to put path browser (see go-to-link') :0.x:
#            my $text=$task.text.join("\n");
#            $text ~~ /(http:..\S*)/;
#            $content-area.gtk_container_add($.create-button('Goto to link','go-to-link',$0.Str)) if $0;
#        }
        
        # Show the dialog.
        $dialog.show-all;
        my $response = $dialog.gtk-dialog-run;
        if $response == GTK_RESPONSE_OK {
            if !$task.iter {
                $gf.create-task($task,$task.darth-vader.iter,:cond(False));
                push($task.darth-vader.tasks,$task);
            }

            if $task.header ne $e-edit.get-text {
                $gf.change=1;
                $task.header=$e-edit.get-text.trim;
                $gf.ts.set-value( $task.iter, 0, $task.display-header($gf.presentation));
            }

            if $e-edit-tags.get-text ne join(" ",$task.tags) {
                $gf.change=1;
                my $tags=$e-edit-tags.get-text;
                $tags ~~ s:g/":"/ /;
                $tags ~~ s:g/" "+/ /;
                $tags = $tags.trim;
                if $tags {
                    $task.tags=split(/" "/,$tags);
                } else {
                    $task.tags=();
                }
                $gf.ts.set-value( $task.iter, 2, $task.display-tags($gf.presentation));
            }

            my $todo="";
            $todo="TODO" if $rb-td2.get-active();
            $todo="DONE" if $rb-td3.get-active();
            if $task.todo ne $todo {
                $gf.change=1;
                $task.todo=$todo;
                $gf.ts.set_value( $task.iter, 0,$task.display-header($gf.presentation));
                if $todo eq 'DONE' {
                    my $ds=&d-now();
                    if $ds ~~ /<dateorg>/ {
                        $task.closed=date-from-dateorg($/{'dateorg'});
                    }
                } else {
                    $task.closed=DateOrg;
                }
            }

            my $prior="";
            $prior="A" if $rb-pr2.get-active();
            $prior="B" if $rb-pr3.get-active();
            $prior="C" if $rb-pr4.get-active();
            if $task.priority ne $prior {
                $task.priority=$prior;
                $gf.ts.set_value( $task.iter, 0,$task.display-header($gf.presentation)); # TODO create $gf.ts-set-header($task)
            }

            my @properties;
            my Gnome::Gtk3::TreeIter $iter = $properties.get-iter-first;
            my $valid=$iter.is-valid;
            while ($valid) {
                if $properties.get-value( $iter, 0)[0].get-string.trim.chars>0 {
                    @properties.push(($properties.get-value( $iter, 0)[0].get-string.trim,
                                            $properties.get-value( $iter, 1)[0].get-string.trim)); # TODO bug if value is nil :0.1:
                }
                $valid=$properties.iter-next($iter);
            }
            if (@properties ne $task.properties) {
                $gf.change=1;
                $task.properties=@properties;
            }

            my Gnome::Gtk3::TextIter $start = $text-buffer2.get-start-iter;
            my Gnome::Gtk3::TextIter $end = $text-buffer2.get-end-iter;
            my $new-text=$text-buffer2.get-text( $start, $end, 0);
            if ($new-text ne $task.text.join("\n")) {
                $gf.change=1;
                $gf.update-text($task.iter,$new-text);
            }
        }
        $dialog.gtk_widget_destroy;
        $response;
    }
}

