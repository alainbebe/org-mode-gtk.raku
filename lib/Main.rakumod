use GtkFile;
use GtkKeyEvent;
use GtkMenuBar;

use Gnome::Gtk3::Main;
use Gnome::Gtk3::Window;
use Gnome::Gtk3::Grid;
use Gnome::Gtk3::Label;

class Main {
    my Gnome::Gtk3::Window $top-window;
    my GtkFile $gf;
    my Gnome::Gtk3::Main $m;

    method main {
        $m .= new; # TODO create Build :refactoring:

        $top-window .= new;
        $top-window.set-title('Org-Mode with GTK and raku');
        $top-window.set-default-size( 640, 480);

        my Gnome::Gtk3::Grid $g .= new;
        $top-window.gtk-container-add($g);

        $gf.=new(:top-window($top-window));
        $g.gtk-grid-attach($gf.sw, 0, 1, 4, 1);

        my Gnome::Gtk3::Label $l-info .= new(:text('Double-Click on task to modify'));
        $g.gtk-grid-attach($l-info, 0, 2, 1, 1);

        my GtkMenuBar $gmb .= new(:gf($gf), :m($m),:top-window($top-window));
        $g.gtk_grid_attach( $gmb.create-menu, 0, 0, 1, 1);

        my GtkKeyEvent $gke .= new(:gf($gf), :m($m), :top-window($top-window));

        $gf.tv.register-signal( $gf, 'tv-button-click', 'row-activated');
        $top-window.register-signal( $gke, 'exit-gui', 'destroy', :gf($gf), :m($m));
        $top-window.register-signal( $gke, 'handle-keypress', 'key-press-event', :l-info($l-info));
        
        $m;
    }
    method show($arg) {
        $gf.file-read($arg);
        $top-window.show-all;
        $m.gtk-main;
    }
}
