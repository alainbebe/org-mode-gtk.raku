use GtkFile;
use GtkKeyEvent;
use GtkMenuBar;

use Gnome::Gtk3::Main;
use Gnome::Gtk3::Window;
use Gnome::Gtk3::Grid;
use Gnome::Gtk3::Label;

class Main is Gnome::Gtk3::Main {
    has Gnome::Gtk3::Window $.top-window;
    has GtkFile $.gf;
    has Gnome::Gtk3::Label $.l-info;
    has GtkMenuBar $.gmb;
    has GtkKeyEvent $.gke;

    submethod BUILD {
        # create top window
        $!top-window .= new;
        $!top-window.set-title('Org-Mode with GTK and raku');
        $!top-window.set-default-size( 640, 480);

        # create grid to have 3 objects, a menu, a tree (in ScrolledWindow sw), a label for info
        my Gnome::Gtk3::Grid $g .= new;
        $!top-window.gtk-container-add($g);

        # add tree with orgmode file in ScrolledWindow (sw)
        $!gf.=new(:top-window($!top-window));
        $g.gtk-grid-attach($!gf.sw, 0, 1, 4, 1);

        # A label for info
        $!l-info .= new(:text('Double-Click on task to modify'));
        $g.gtk-grid-attach($!l-info, 0, 2, 1, 1);

        # A menu bar
        $!gmb .= new(:gf($!gf), :m(self),:top-window($!top-window));
        $g.gtk_grid_attach( $!gmb.create-menu, 0, 0, 1, 1);

        $!gf.tv.register-signal( $!gf, 'tv-button-click', 'row-activated');

        # register signal from keyboard
        $!gke .= new(:gf($!gf), :m(self), :top-window($!top-window));
        $!top-window.register-signal( $!gke, 'exit-gui', 'destroy', :gf($!gf), :m(self));
        $!top-window.register-signal( $!gke, 'handle-keypress', 'key-press-event', :l-info($!l-info));
    }
    method show($arg) {
        $!gf.file-read($arg);
        $!top-window.show-all;
        $.gtk-main;
    }
}
