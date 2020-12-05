#!/usr/bin/env perl6

use v6;

use lib "lib";
use GtkFile;
use GtkKeyEvent;
use GtkMenuBar;

use Gnome::Gtk3::Main;
use Gnome::Gtk3::Window;
use Gnome::Gtk3::Grid;
use Gnome::Gtk3::Label;
use Gnome::Gtk3::AboutDialog;
use NativeCall;

my Gnome::Gtk3::Main $m .= new;

my Gnome::Gtk3::Window $top-window .= new;
$top-window.set-title('Org-Mode with GTK and raku');
$top-window.set-default-size( 640, 480);

my Gnome::Gtk3::Grid $g .= new;
$top-window.gtk-container-add($g);

my GtkFile $gf.=new(:top-window($top-window));
$g.gtk-grid-attach($gf.sw, 0, 1, 4, 1);

my Gnome::Gtk3::Label $l-info .= new(:text('Double-Click on task to modify'));
$g.gtk-grid-attach($l-info, 0, 2, 1, 1);

my Gnome::Gtk3::AboutDialog $about .= new;
$about.set-program-name('org-mode-gtk.raku');
$about.set-version('0.1');
$about.set-license-type(GTK_LICENSE_GPL_3_0);
$about.set-website("http://www.barbason.be");
$about.set-website-label("http://www.barbason.be");
$about.set-authors(CArray[Str].new('Alain BarBason'));

my GtkKeyEvent $gke .= new(:gf($gf), :m($m), :top-window($top-window));

class AppSignalHandlers {
    has Gnome::Gtk3::Window $!top-window;
    submethod BUILD ( Gnome::Gtk3::Window:D :$!top-window! ) { }

    method help-about {
        $about.gtk-dialog-run;
        $about.gtk-widget-hide;
    }
} # end Class AppSiganlHandlers
my AppSignalHandlers $ash .= new(:top-window($top-window));

my GtkMenuBar $gmb .= new(:gf($gf), :m($m),:top-window($top-window));
$g.gtk_grid_attach( $gmb.create-menu, 0, 0, 1, 1);
#-----------------------------------main--------------------------------
sub MAIN($arg = '') {
    $gf.file-open($arg,$top-window);
    $gf.tv.register-signal( $gf, 'tv-button-click', 'row-activated');
    $top-window.register-signal( $gke, 'exit-gui', 'destroy', :gf($gf), :m($m)); # TODO doesn't work :refactoring:
    $top-window.register-signal( $gke, 'handle-keypress', 'key-press-event', :gf($gf), :l-info($l-info));
    $top-window.show-all;
    $m.gtk-main;
}
