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
    method is-child-prior($prior) {
        return True if $.priority && $.priority eq $prior; 
        if $.tasks {
            for $.tasks.Array {
                return True if $_.is-child-prior($prior);
            }
        }
        return False;
    }
}

