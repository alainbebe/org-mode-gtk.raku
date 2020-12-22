use OrgMode::Task;
use Gnome::Gtk3::TreeIter;
use Gnome::Gdk3::Pixbuf;

class GtkTask is Task {
    has Gnome::Gtk3::TreeIter $.iter is rw;

    method inspect {
        callsame;
        my $prefix=" " x $.level*2;
        say $prefix,"iter        ",$.iter;
        say $prefix,"-----";
    }
    method get-image {
        my Gnome::Gdk3::Pixbuf $pb;
        $.text ~~ / "[[" ("./img/" .+ ) "]]" /;
        $pb .= new(:file($0.Str));
        return $pb;
    }
}

