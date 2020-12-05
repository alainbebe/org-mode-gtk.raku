use Gnome::Gtk3::AboutDialog;
use NativeCall;

class AboutDialog {

    method create-ad {
        my Gnome::Gtk3::AboutDialog $about .= new;
        $about.set-program-name('org-mode-gtk.raku');
        $about.set-version('0.1');
        $about.set-license-type(GTK_LICENSE_GPL_3_0);
        $about.set-website("http://www.barbason.be");
        $about.set-website-label("http://www.barbason.be");
        $about.set-authors(CArray[Str].new('Alain BarBason'));
        $about.gtk-dialog-run;
        $about.gtk-widget-hide;
    }
}

