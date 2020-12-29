use Gtk::EditPreface;
use Gtk::File;
use Gtk::MoveTask;
use Gtk::AboutDialog;

use Gnome::Gtk3::Main;
use Gnome::Gtk3::MenuBar;
use Gnome::Gtk3::Menu; 
use Gnome::Gtk3::MenuItem;

# global variable : to remove ?
my $debug=0;            # to debug =1

class Gtk::MenuBar {
    has Gtk::File $.gf;
    has Gnome::Gtk3::Main $.m ;

    submethod BUILD ( :$!m ) { # TODO :refactoring:
        $!gf=$!m.gf;
    }

    method create-menu {
        my Gnome::Gtk3::MenuBar $menu-bar .= new;
        $menu-bar.gtk-menu-shell-append($.create-main-menu('_File',$.make-menubar-list-file));
        #$menu-bar.gtk-menu-shell-append($.create-main-menu('_Edit',$.make-menubar-list-edit));
        $menu-bar.gtk-menu-shell-append($.create-main-menu('_Divers',$.make-menubar-list-divers));
        $menu-bar.gtk-menu-shell-append($.create-main-menu('_Org',$.make-menubar-list-org));
        $menu-bar.gtk-menu-shell-append($.create-main-menu('De_bug',$.make-menubar-list-debug)) if $debug;
        $menu-bar.gtk-menu-shell-append($.create-main-menu('_Help',$.make-menubar-list-help));
        $menu-bar;
    }
    method create-main-menu($title,Gnome::Gtk3::Menu $sub-menu) {
        my Gnome::Gtk3::MenuItem $but-file-menu .= new(:label($title));
        $but-file-menu.set-use-underline(1);
        $but-file-menu.set-submenu($sub-menu);
        return $but-file-menu;
    }
    method create-sub-menu($menu,$name,$ash,$method,:$choice) {
        my Gnome::Gtk3::MenuItem $menu-item .= new(:label($name));
        $menu-item.set-use-underline(1);
        $menu.gtk-menu-shell-append($menu-item);
        $menu-item.register-signal( $ash, $method, 'activate',:choice($choice));
    } 
    method make-menubar-list-file {
        my Gnome::Gtk3::Menu $menu .= new;

        $.create-sub-menu($menu,"_New",                 $.gf,'file-new');
        $.create-sub-menu($menu,"_Open File ...",       $.gf,'file-open');
        $.create-sub-menu($menu,"_Save         C-x C-s",$.gf,'file-save');
        $.create-sub-menu($menu,"Save _as ...",         $.gf,'file-save-as');
        $.create-sub-menu($menu,"Save to _test",        $.gf,'file-save-test') if $debug;

        my Gnome::Gtk3::MenuItem $menu-item .= new(:label("_Quit         C-x C-c"));
        $menu-item.set-use-underline(1);
        $menu.gtk-menu-shell-append($menu-item);
        $menu-item.register-signal( $.m, 'exit-gui', 'activate');

        $menu
    }
    method make-menubar-list-edit {
        my Gnome::Gtk3::Menu $menu .= new;

        $menu
    }
    method make-menubar-list-divers {
        my Gnome::Gtk3::Menu $menu .= new;

        my Gtk::EditPreface $ep .=new(:top-window($!m.top-window));
        my Gnome::Gtk3::MenuItem $menu-item .= new(:label('Edit P_reface'));
        $menu-item.set-use-underline(1);
        $menu.gtk-menu-shell-append($menu-item);
        $menu-item.register-signal( $ep, 'edit-preface', 'activate', :gf($.gf));

        $.create-sub-menu($menu,"Change _Presentation",$.gf,'option-presentation');
        $.create-sub-menu($menu,"View/Hide _Image       C-c C-x C-v",$.gf,'m-view-hide-image');

        my Gnome::Gtk3::Menu $sm-zoom = $.make-menubar-zoom($.gf);
        my Gnome::Gtk3::MenuItem $zoom-root-menu .= new(:label('Zoom'));
        $zoom-root-menu.set-submenu($sm-zoom);
        $menu.gtk-menu-shell-append($zoom-root-menu);

        $menu
    }
    method make-menubar-list-org {
        my Gnome::Gtk3::Menu $menu .= new;

        my Gnome::Gtk3::Menu $sm-sh = $.make-menubar-sh($.gf);
        my Gnome::Gtk3::MenuItem $sh-root-menu .= new(:label('Show/Hide'));
        $sh-root-menu.set-submenu($sm-sh);
        $menu.gtk-menu-shell-append($sh-root-menu);

        my Gnome::Gtk3::MenuItem $menu-item .= new(:label('New Heading                M-Enter'));
        $menu-item.set-use-underline(1);
        $menu.gtk-menu-shell-append($menu-item);
        $menu-item.register-signal( $.gf, 'add-brother-down', 'activate');

        $.create-sub-menu($menu,"New Child",$.gf,'add-child');

        my Gnome::Gtk3::Menu $sm-es = $.make-menubar-es($.gf);
        my Gnome::Gtk3::MenuItem $es-root-menu .= new(:label('Edit Structure'));
        $es-root-menu.set-submenu($sm-es);
        $menu.gtk-menu-shell-append($es-root-menu);

        my Gnome::Gtk3::Menu $sm-keyword = $.make-menubar-keyword($.gf);
        my Gnome::Gtk3::MenuItem $sm-root-menu .= new(:label('TODO Lists'));
        $sm-root-menu.set-submenu($sm-keyword);
        $menu.gtk-menu-shell-append($sm-root-menu);

    #    my Gnome::Gtk3::Menu $sm-tp = $.make-menubar-tp($.gf);
    #    my Gnome::Gtk3::MenuItem $tp-root-menu .= new(:label('TAG and Properties'));
    #    $tp-root-menu.set-submenu($sm-tp);
    #    $menu.gtk-menu-shell-append($tp-root-menu);
    #
        my Gnome::Gtk3::Menu $sm-ds = $.make-menubar-ds($.gf);
        my Gnome::Gtk3::MenuItem $ds-root-menu .= new(:label('Dates and Scheduling'));
        $ds-root-menu.set-submenu($sm-ds);
        $menu.gtk-menu-shell-append($ds-root-menu);

        $menu
    }   
    method make-menubar-zoom ( $ash ){
        my Gnome::Gtk3::Menu $menu .= new;
        $.create-sub-menu($menu,"Zoom +"     ,$.gf,'zoom',:choice( 1));
        $.create-sub-menu($menu,"Zoom -"     ,$.gf,'zoom',:choice(-1));
        $.create-sub-menu($menu,"Normal size",$.gf,'zoom',:choice( 0));
        $menu
    }
    method make-menubar-sh ( $ash ) {
        my Gnome::Gtk3::Menu $menu .= new;

        my Gnome::Gtk3::Menu $sm-st = $.make-menubar-st($ash);
        my Gnome::Gtk3::MenuItem $st-root-menu .= new(:label('Sparse Tree'));
        $st-root-menu.set-submenu($sm-st);
        $menu.gtk-menu-shell-append($st-root-menu);

        $.create-sub-menu($menu,"Fold All",$ash,'view-fold-all'); # TODO keep $ash or $.gf ? :refactroing:
        $.create-sub-menu($menu,"Show All",$.gf,'show-all');
        $.create-sub-menu($menu,"Fold branch",$.gf,'fold-branch');
        $.create-sub-menu($menu,"Unfold branch",$.gf,'unfold-branch');
        $.create-sub-menu($menu,"Unfold branch and child",$.gf,'unfold-branch-child');

        $menu
    }
    method make-menubar-st ( $ash ) {
        my Gnome::Gtk3::Menu $menu .= new;

        $.create-sub-menu($menu,"Show All (and DONE)",$.gf,'option-no-done');
        $.create-sub-menu($menu,"#_A",$.gf,"option-prior-A");
        $.create-sub-menu($menu,"#A #_B",$.gf,"option-prior-B");
        $.create-sub-menu($menu,"#A #B #_C",$.gf,"option-prior-C");
        $.create-sub-menu($menu,"_Today and past",$.gf,"option-today-past");

        my Gnome::Gtk3::MenuItem $mi-find .= new(:label('_Find ...'));
        $mi-find.set-use-underline(1);
        $menu.gtk-menu-shell-append($mi-find);

        $mi-find.register-signal( $.gf, "option-find", 'activate');

        my Gnome::Gtk3::MenuItem $mi-search-tags .= new(:label('Search by _Tag ...'));
        $mi-search-tags.set-use-underline(1);
        $menu.gtk-menu-shell-append($mi-search-tags);
        $mi-search-tags.register-signal( $.gf, "option-search-tag", 'activate');

        my Gnome::Gtk3::MenuItem $mi-clear-tags .= new(:label("Clear filter (but hide DONE)"));
        $mi-clear-tags.set-use-underline(1);
        $menu.gtk-menu-shell-append($mi-clear-tags);
        $mi-clear-tags.register-signal( $.gf, "option-clear", 'activate');

        $menu
    }
    method make-menubar-es ( $ash ) {
        my Gnome::Gtk3::Menu $menu .= new;

    #    .create-sub-menu2($menu,"Up          M-up",$ash,'move-up-down-button-click',-1); # TODO doesn't work. Why ?
                                                                # Too many positionals passed; expected 4 arguments but got 5
        my Gnome::Gtk3::MenuItem $menu-item .= new(:label('Move Subtree Up             M-up'));
        $menu-item.set-use-underline(1);
        $menu.gtk-menu-shell-append($menu-item);
        $menu-item.register-signal( $.gf, 'move-up-down-button-click', 'activate',:inc(-1));

        $menu-item .= new(:label('Move Subtree Down      M-down'));
        $menu-item.set-use-underline(1);
        $menu.gtk-menu-shell-append($menu-item);
        $menu-item.register-signal( $.gf, 'move-up-down-button-click', 'activate',:inc(1));

        my Gnome::Gtk3::MenuItem $mi-cut .= new(:label('_Cut Subtree'));
        $mi-cut.set-use-underline(1);
        $menu.gtk-menu-shell-append($mi-cut);
        my Gnome::Gtk3::MenuItem $mi-paste .= new(:label("_Paste Subtree (as child)"));
        $mi-paste.set-use-underline(1);
        $menu.gtk-menu-shell-append($mi-paste);
        $mi-paste.set-sensitive(0);

        $mi-cut.register-signal( $.gf, "edit-cut", 'activate',:widget-paste($mi-paste));
        $mi-paste.register-signal( $.gf, "edit-paste", 'activate',:widget-cut($mi-cut));

        $menu-item .= new(:label('Demote Subtree             M-S-right'));
        $menu-item.set-use-underline(1);
        $menu.gtk-menu-shell-append($menu-item);
        $menu-item.register-signal( $.gf, 'move-right-button-click', 'activate');

        $menu-item .= new(:label('Promote Subtree            M-S-left'));
        $menu-item.set-use-underline(1);
        $menu.gtk-menu-shell-append($menu-item);
        $menu-item.register-signal( $.gf, 'move-left-button-click', 'activate');

        my Gtk::MoveTask $mt .= new(:gf($.gf));
        $.create-sub-menu($menu,"Move Subtree ...",$mt,'move-task');

        $menu
    }
    method make-menubar-keyword ( $ash ) {
        my Gnome::Gtk3::Menu $menu .= new;

        $.create-sub-menu($menu,"TODO/DONE/-    C-c C-t",$.gf,'edit-keyword');

        # TODO add a menu separator

        my Gnome::Gtk3::MenuItem $menu-item .= new(:label('Priority Up                  S-up'));
        $menu-item.set-use-underline(1);
        $menu.gtk-menu-shell-append($menu-item);
        $menu-item.register-signal( $.gf, 'priority-up', 'activate');

        $menu-item .= new(:label('Priority Down                S-down'));
        $menu-item.set-use-underline(1);
        $menu.gtk-menu-shell-append($menu-item);
        $menu-item.register-signal( $.gf, 'priority-down', 'activate');

        $menu
    }
    #sub make-menubar-tp ( $ash ) {
    #    my Gnome::Gtk3::Menu $menu .= new;
    #
    #    $menu
    #}
    method make-menubar-ds ( $ash ) {
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
    method make-menubar-list-debug {
        my Gnome::Gtk3::Menu $menu .= new;
        $.create-sub-menu($menu,"_Inspect",$.gf,'inspect');
        $menu
    }
    method make-menubar-list-help  {
        my Gnome::Gtk3::Menu $menu .= new;
        $.create-sub-menu($menu,"_About",self,'help-about');
        $menu
    }
    method help-about {
        Gtk::AboutDialog.new.run;
    }
}

