use Task;
use Gnome::Gtk3::TreeIter;

class GtkTask is Task {
    has Gnome::Gtk3::TreeIter $.iter is rw;

    method inspect {
        callsame;
        my $prefix=" " x $.level*2;
        say $prefix,"iter        ",$.iter;
        say $prefix,"-----";
    }
}

