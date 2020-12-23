use Gnome::Gtk3::Window;
use Gnome::Gtk3::Dialog;
use Gnome::Gtk3::Box;
use Gnome::Gtk3::TextView;
use Gnome::Gtk3::TextBuffer;
use Gnome::Gtk3::ScrolledWindow;
use Gnome::Gtk3::TextIter;

class Gtk::EditPreface {
    has Gnome::Gtk3::Window $!top-window;

    submethod BUILD ( Gnome::Gtk3::Window:D :$!top-window! ) { }

    method edit-preface (:$gf) {
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
}
