use Gnome::Gtk3::AboutDialog;
use NativeCall;

class Gtk::AboutDialog is Gnome::Gtk3::AboutDialog {

    submethod new ( |c ) {
        self.bless( :GtkAboutDialog, |c); # TODO why it's run ? normaly :AboutDialog :0.1:MM:
    }

    submethod BUILD ( ) {
        self.set-program-name('org-mode-gtk.raku');
        self.set-version('0.1');
        self.set-license-type(GTK_LICENSE_GPL_3_0);
        self.set-website("http://www.barbason.be");
        self.set-website-label("http://www.barbason.be");
        self.set-authors(CArray[Str].new('Alain BarBason'));
    }

    method run {
        self.gtk-dialog-run;
        self.gtk-widget-hide;
    }
}

