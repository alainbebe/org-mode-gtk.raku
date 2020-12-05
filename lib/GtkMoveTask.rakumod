use GtkFile;

use Gnome::Gtk3::Window;
use Gnome::Gtk3::Dialog;
use Gnome::Gtk3::Box;
use Gnome::Gtk3::Grid;
use Gnome::Gtk3::Button;

class GtkMoveTask {
    has Gnome::Gtk3::Window $!top-window;
    has Gnome::Gtk3::Dialog $dialog;
    has GtkFile $gf1;

    submethod BUILD ( Gnome::Gtk3::Window:D :$!top-window! ) { }

    multi method create-button($label,$method,$iter?,$inc?) {
        my Gnome::Gtk3::Button $b  .= new(:label($label));
        $b.register-signal($gf1, $method, 'clicked',:iter($iter),:inc($inc));
        return $b;
    }

    method move-task (:$gf) {
        $gf1=$gf;                                                           # TODO :refactoring:
        my Gnome::Gtk3::TreeIter $iter = $gf.highlighted-task.iter;

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
}
