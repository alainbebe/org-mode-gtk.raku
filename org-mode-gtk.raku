#!/usr/bin/env perl6

use v6;

use lib "lib";
use GtkFile;
use GtkEditPreface;
use GtkMoveTask;
use GtkKeyEvent;

use Gnome::N::N-GObject;
use Gnome::Gtk3::Main;
use Gnome::Gtk3::Window;
use Gnome::Gtk3::Grid;
use Gnome::Gtk3::Label;
use Gnome::Gtk3::MenuBar;
use Gnome::Gtk3::Menu;
use Gnome::Gtk3::MenuItem;
use Gnome::Gtk3::AboutDialog;
use Gnome::Gtk3::ScrolledWindow;
use NativeCall;

# global variable : to remove ?
my $debug=1;            # to debug =1

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

my Gnome::Gtk3::MenuBar $menu-bar .= new;
$g.gtk_grid_attach( $menu-bar, 0, 0, 1, 1);
$menu-bar.gtk-menu-shell-append(create-main-menu('_File',make-menubar-list-file));
#$menu-bar.gtk-menu-shell-append(create-main-menu('_Edit',make-menubar-list-edit));
$menu-bar.gtk-menu-shell-append(create-main-menu('_Divers',make-menubar-list-divers));
$menu-bar.gtk-menu-shell-append(create-main-menu('_Org',make-menubar-list-org));
$menu-bar.gtk-menu-shell-append(create-main-menu('De_bug',make-menubar-list-debug)) if $debug;
$menu-bar.gtk-menu-shell-append(create-main-menu('_Help',make-menubar-list-help));

sub create-main-menu($title,Gnome::Gtk3::Menu $sub-menu) {
    my Gnome::Gtk3::MenuItem $but-file-menu .= new(:label($title));
    $but-file-menu.set-use-underline(1);
    $but-file-menu.set-submenu($sub-menu);
    return $but-file-menu;
}
sub create-sub-menu($menu,$name,$ash,$method) {
    my Gnome::Gtk3::MenuItem $menu-item .= new(:label($name));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, $method, 'activate');
} 
sub make-menubar-list-file {
    my Gnome::Gtk3::Menu $menu .= new;

#    create-sub-menu($menu,"_New",$gf,'file-new'); # TODO doesn't work. Why ? :refactoroing:
#    create-sub-menu($menu,"_Open File ...",$gf,'file-open');
#    create-sub-menu($menu,"_Save         C-x C-s",$gf,'file-save');
#    create-sub-menu($menu,"Save _as ...",$gf,'file-save-as');
#    create-sub-menu($menu,"Save to _test",$gf,'file-save-test') if $debug;

    my Gnome::Gtk3::MenuItem $menu-item .= new(:label("_New"));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $gf, 'file-new', 'activate');

    $menu-item .= new(:label("_Open File ..."));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $gf, 'file-open1', 'activate');

    $menu-item .= new(:label("_Save         C-x C-s"));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $gf, 'file-save', 'activate');

    $menu-item .= new(:label("Save _as ..."));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $gf, 'file-save-as1', 'activate');

    $menu-item .= new(:label("Save to _test"));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $gf, 'file-save-test', 'activate');
    
    $menu-item .= new(:label("_Quit         C-x C-c"));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $gke, 'exit-gui', 'activate', :gf($gf), :m($m));

    $menu
}
sub make-menubar-list-edit {
    my Gnome::Gtk3::Menu $menu .= new;

    $menu
}
sub make-menubar-list-divers {
    my Gnome::Gtk3::Menu $menu .= new;

    my GtkEditPreface $ep .=new(:top-window($top-window));
    my Gnome::Gtk3::MenuItem $menu-item .= new(:label('Edit P_reface'));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ep, 'edit-preface', 'activate', :gf($gf));

    create-sub-menu($menu,"Change _Presentation",$gf,'option-presentation');
    create-sub-menu($menu,"View/Hide _Image       C-c C-x C-v",$gf,'m-view-hide-image');

    $menu
}
sub make-menubar-list-org {
    my Gnome::Gtk3::Menu $menu .= new;

    my Gnome::Gtk3::Menu $sm-sh = make-menubar-sh($ash);
    my Gnome::Gtk3::MenuItem $sh-root-menu .= new(:label('Show/Hide'));
    $sh-root-menu.set-submenu($sm-sh);
    $menu.gtk-menu-shell-append($sh-root-menu);

    my Gnome::Gtk3::MenuItem $menu-item .= new(:label('New Heading                M-Enter'));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $gf, 'add-brother-down', 'activate');

    create-sub-menu($menu,"New Child",$gf,'add-child');

    my Gnome::Gtk3::Menu $sm-es = make-menubar-es($ash);
    my Gnome::Gtk3::MenuItem $es-root-menu .= new(:label('Edit Structure'));
    $es-root-menu.set-submenu($sm-es);
    $menu.gtk-menu-shell-append($es-root-menu);

    my Gnome::Gtk3::Menu $sm-todo = make-menubar-todo($ash);
    my Gnome::Gtk3::MenuItem $sm-root-menu .= new(:label('TODO Lists'));
    $sm-root-menu.set-submenu($sm-todo);
    $menu.gtk-menu-shell-append($sm-root-menu);

#    my Gnome::Gtk3::Menu $sm-tp = make-menubar-tp($ash);
#    my Gnome::Gtk3::MenuItem $tp-root-menu .= new(:label('TAG and Properties'));
#    $tp-root-menu.set-submenu($sm-tp);
#    $menu.gtk-menu-shell-append($tp-root-menu);
#
    my Gnome::Gtk3::Menu $sm-ds = make-menubar-ds($ash);
    my Gnome::Gtk3::MenuItem $ds-root-menu .= new(:label('Dates and Scheduling'));
    $ds-root-menu.set-submenu($sm-ds);
    $menu.gtk-menu-shell-append($ds-root-menu);

    $menu
}   
sub make-menubar-sh ( AppSignalHandlers $ash ) {
    my Gnome::Gtk3::Menu $menu .= new;

    my Gnome::Gtk3::Menu $sm-st = make-menubar-st($ash);
    my Gnome::Gtk3::MenuItem $st-root-menu .= new(:label('Sparse Tree'));
    $st-root-menu.set-submenu($sm-st);
    $menu.gtk-menu-shell-append($st-root-menu);

    create-sub-menu($menu,"Fold All",$ash,'view-fold-all');
    create-sub-menu($menu,"Show All",$gf,'show-all');
    create-sub-menu($menu,"Fold branch",$gf,'fold-branch');
    create-sub-menu($menu,"Unfold branch",$gf,'unfold-branch');
    create-sub-menu($menu,"Unfold branch and child",$gf,'unfold-branch-child');

    $menu
}
sub make-menubar-st ( AppSignalHandlers $ash ) {
    my Gnome::Gtk3::Menu $menu .= new;

    create-sub-menu($menu,"Show _DONE",$gf,'option-no-done'); # TODO replace Show All (or another name), Create Show TODO tree :0.1:
    create-sub-menu($menu,"#_A",$gf,"option-prior-A");
    create-sub-menu($menu,"#A #_B",$gf,"option-prior-B");
    create-sub-menu($menu,"#A #B #_C",$gf,"option-prior-C");
    create-sub-menu($menu,"_Today and past",$gf,"option-today-past");

    my Gnome::Gtk3::MenuItem $mi-find .= new(:label('_Find ...'));
    $mi-find.set-use-underline(1);
    $menu.gtk-menu-shell-append($mi-find);

    $mi-find.register-signal( $gf, "option-find", 'activate');

    my Gnome::Gtk3::MenuItem $mi-search-tags .= new(:label('Search by _Tag ...'));
    $mi-search-tags.set-use-underline(1);
    $menu.gtk-menu-shell-append($mi-search-tags);
    $mi-search-tags.register-signal( $gf, "option-search-tag", 'activate');

    my Gnome::Gtk3::MenuItem $mi-clear-tags .= new(:label("Clear filter (but hide DONE)"));
    $mi-clear-tags.set-use-underline(1);
    $menu.gtk-menu-shell-append($mi-clear-tags);
    $mi-clear-tags.register-signal( $gf, "option-clear", 'activate');

    $menu
}
sub make-menubar-es ( AppSignalHandlers $ash ) {
    my Gnome::Gtk3::Menu $menu .= new;

#    create-sub-menu2($menu,"Up          M-up",$ash,'move-up-down-button-click',-1); # TODO doesn't work. Why ?
                                                            # Too many positionals passed; expected 4 arguments but got 5
    my Gnome::Gtk3::MenuItem $menu-item .= new(:label('Move Subtree Up             M-up'));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $gf, 'move-up-down-button-click', 'activate',:inc(-1));

    $menu-item .= new(:label('Move Subtree Down      M-down'));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $gf, 'move-up-down-button-click', 'activate',:inc(1));

    my Gnome::Gtk3::MenuItem $mi-cut .= new(:label('_Cut Subtree'));
    $mi-cut.set-use-underline(1);
    $menu.gtk-menu-shell-append($mi-cut);
    my Gnome::Gtk3::MenuItem $mi-paste .= new(:label("_Paste Subtree (as child)"));
    $mi-paste.set-use-underline(1);
    $menu.gtk-menu-shell-append($mi-paste);
    $mi-paste.set-sensitive(0);

    $mi-cut.register-signal( $gf, "edit-cut", 'activate',:widget-paste($mi-paste));
    $mi-paste.register-signal( $gf, "edit-paste", 'activate',:widget-cut($mi-cut));

    $menu-item .= new(:label('Demote Subtree             M-S-right'));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $gf, 'move-right-button-click', 'activate');

    $menu-item .= new(:label('Promote Subtree            M-S-left'));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $gf, 'move-left-button-click', 'activate');

    $menu-item .= new(:label('Move Subtree ...'));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    my GtkMoveTask $mt .= new(:top-window($top-window));
    $menu-item.register-signal( $mt, 'move-task', 'activate',:gf($gf));
#    create-sub-menu($menu,"Move Subtree ...",$mt,'move-task');

    $menu
}
sub make-menubar-todo ( AppSignalHandlers $ash ) {
    my Gnome::Gtk3::Menu $menu .= new;

    create-sub-menu($menu,"TODO/DONE/-    C-c C-t",$gf,'edit-todo-done');

    # TODO add a menu separator

    my Gnome::Gtk3::MenuItem $menu-item .= new(:label('Priority Up                  S-up'));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $gf, 'priority-up', 'activate');

    $menu-item .= new(:label('Priority Down                S-down'));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $gf, 'priority-down', 'activate');

    $menu
}
#sub make-menubar-tp ( AppSignalHandlers $ash ) {
#    my Gnome::Gtk3::Menu $menu .= new;
#
#    $menu
#}
sub make-menubar-ds ( AppSignalHandlers $ash ) {
    my Gnome::Gtk3::Menu $menu .= new;

    my Gnome::Gtk3::MenuItem $menu-item .= new(:label('Schedule item                C-c C-s'));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, 'scheduled', 'activate'); 

    $menu-item .= new(:label('Deadline                    C-c C-d'));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, 'deadline', 'activate');

    $menu
}
sub make-menubar-list-debug {
    my Gnome::Gtk3::Menu $menu .= new;
    create-sub-menu($menu,"_Inspect",$gf.om,'inspect');
    $menu
}
sub make-menubar-list-help  {
    my Gnome::Gtk3::Menu $menu .= new;
    create-sub-menu($menu,"_About",$ash,'help-about');
    $menu
}
#-----------------------------------main--------------------------------
sub MAIN($arg = '') {
    $gf.file-open($arg,$top-window);
    $gf.tv.register-signal( $gf, 'tv-button-click', 'row-activated');
    $top-window.register-signal( $gke, 'exit-gui', 'destroy', :gf($gf), :m($m)); # TODO doesn't work :refactoring:
    $top-window.register-signal( $gke, 'handle-keypress', 'key-press-event', :gf($gf), :l-info($l-info));
    $top-window.show-all;
    $m.gtk-main;
}

