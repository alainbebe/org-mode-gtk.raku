use GtkFile;
use GtkEditTask;

use Gnome::Gtk3::Window;
use Gnome::Gtk3::Main;
use Gnome::Gtk3::Dialog;
use Gnome::Gdk3::Events;
use Gnome::Gdk3::Keysyms;

class GtkKeyEvent {
    has Gnome::Gtk3::Window $!top-window; 
    has Gnome::Gtk3::Main $.m ;
    has GtkFile $.gf;
    has GtkEditTask $.get;
    has @ctrl-keys;
    has $is-maximized=False; # TODO use gtk-window.is_maximized in Window.pm6 (uncomment =head2 [[gtk_] window_] is_maximized) :0.x:

    submethod BUILD ( :$gf, :$m, Gnome::Gtk3::Window:D :$!top-window!) { 
        $!gf=$gf;
        $!m=$m;
        $!get .= new(:top-window($!top-window));
    }

    method exit-gui ( --> Int ) {
        my $button=$.gf.try-save;
        $!m.gtk-main-quit if $button != GTK_RESPONSE_CANCEL;
        1
    }
    method handle-keypress ( N-GdkEventKey $event-key, :$widget , :$gf, :$l-info) {
#        note 'event: ', GdkEventType($event-key.type), ', ', $event-key.keyval.fmt('0x%08x') if $debug;
        if $event-key.type ~~ GDK_KEY_PRESS {
            if $event-key.keyval.fmt('0x%08x') == GDK_KEY_F11 {
                $is-maximized ?? $!top-window.unmaximize !! $!top-window.maximize;
                $is-maximized=!$is-maximized; 
            }
            if $event-key.state == 1 { # shift push
                given $event-key.keyval.fmt('0x%08x') {
                    when 0xff52 {$gf.priority-up}
                    when 0xff54 {$gf.priority-down}
                }
            }
            if $event-key.state == 4 { # ctrl push
                #note "Key ",Buf.new($event-key.keyval).decode;
                @ctrl-keys.push(Buf.new($event-key.keyval).decode);
                given join('',@ctrl-keys) {
                    when  ""  {}
                    when  "c"  {$l-info.set-label("C-c")}
                    when  "x"  {$l-info.set-label("C-x")}
                    when  "cx" {$l-info.set-label("C-c C-x")}
#                    when "cc" {@ctrl-keys=''; say "cc"}
#                    when "cq" {@ctrl-keys=''; say "edit tag"}
#                    when "k"  {@ctrl-keys=''; $l-info.set-label('Delete branch');      $gf.delete-branch($clicked-task.iter); }
                    when "cs"  {@ctrl-keys=''; $l-info.set-label('Schedule');           $.get.scheduled(:gf($gf))} 
                    when "cd"  {@ctrl-keys=''; $l-info.set-label('Deadline');           $.get.deadline(:gf($gf))}
                    when "ct"  {@ctrl-keys=''; $l-info.set-label('Change TODO/DONE/-'); $gf.edit-todo-done;}
                    when "cxv" {@ctrl-keys=''; $l-info.set-label('View/Hide Image');    $gf.m-view-hide-image;}
                    when "xs"  {@ctrl-keys=''; $l-info.set-label('Save');               $gf.file-save1}
                    when "xc"  {@ctrl-keys=''; $l-info.set-label('Exit');               self.exit-gui}
                    default    {$l-info.set-label(join(' Ctrl-',@ctrl-keys) ~ " is undefined");@ctrl-keys='';}
                }
            }
            # TODO Alt-Enter crée un frère après
            # TODO M-S-Enter crée un fils avec TODO
            # TODO Home suivi de Alt-Enter crée un frère avant
            if $event-key.state == 8 { # alt push # TODO write with "given" :refactoring:
                $gf.move-up-down-button-click(:inc(-1)) 
                    if $event-key.keyval.fmt('0x%08x') == 0xff52; # Alt-Up
                $gf.move-up-down-button-click(:inc( 1)) 
                    if $event-key.keyval.fmt('0x%08x') == 0xff54; # Alt-Down
            }
            if $event-key.state == 9 { # alt shift push
                $gf.move-left-button-click() 
                    if $event-key.keyval.fmt('0x%08x') == 0xff51; # Alt-Shift-left
                $gf.move-right-button-click() 
                    if $event-key.keyval.fmt('0x%08x') == 0xff53; # Alt-Shift-right
            }
        }
        1
    }
}
