use Task;
use Gnome::Gtk3::TreeIter;

class GtkTask is Task {
    has Gnome::Gtk3::TreeIter $.iter is rw;

    method delete-iter() {
        $.iter .=new;
        if $.tasks {
            for $.tasks.Array {
                $_.delete-iter();
            }
        }
    }
}

