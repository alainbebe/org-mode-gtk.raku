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
    has @ctrl-keys;
    has $is-maximized=False; # TODO use gtk-window.is_maximized in Window.pm6 (uncomment =head2 [[gtk_] window_] is_maximized) :0.x:

    submethod BUILD ( :$!m ) { 
    }

    method message($message) {
        $!m.l-info.set-label($message);
        @ctrl-keys=''; 
    }
    method handle-keypress ( N-GdkEventKey $event-key, :$widget ) {
#        note 'event: ', GdkEventType($event-key.type), ', ', $event-key.keyval.fmt('0x%08x');
        if $event-key.type ~~ GDK_KEY_PRESS {
#            note "State : ", $event-key.state;
            given $event-key.state {
                when 0 { # No Ctrl, Alt, Shift.
                    given $event-key.keyval.fmt('0x%08x') {
                        when GDK_KEY_F11 {
                            $is-maximized ?? $.m.top-window.unmaximize !! $.m.top-window.maximize;
                            $is-maximized=!$is-maximized; 
                        }
                    }
                }
                when 1 { # Shift push
                    given $event-key.keyval.fmt('0x%08x') {
                        when GDK_KEY_Up   {$!m.gf.priority-up}
                        when GDK_KEY_Down {$!m.gf.priority-down}
                    }
                }
                when 4 { # Ctrl push
    #                note "ekv : ",$event-key.keyval;
                    return 1 if $event-key.keyval == 65505; # "ctrl-shift" witout other key
    #                note "Key ",Buf.new($event-key.keyval).decode;
                    @ctrl-keys.push(Buf.new($event-key.keyval).decode);
                    given join('',@ctrl-keys) {
                        when  ""  {}
                        when  "c"  {$!m.l-info.set-label("C-c")}
                        when  "x"  {$!m.l-info.set-label("C-x")}
                        when  "cx" {$!m.l-info.set-label("C-c C-x")}
                        when "-"   { $.message('Zoom -');             $!m.gf.zoom(:choice(-1))} 
    #                    when "cc" {@ctrl-keys=''; say "cc"}
    #                    when "cq" {@ctrl-keys=''; say "edit tag"}
    #                    when "k"  { $.message('Delete branch');      $!m.gf.delete-branch($clicked-task.iter); }
                        when "cs"  { $.message('Schedule');           $.m.gedt.scheduled(:gf($!m.gf))} 
                        when "cd"  { $.message('Deadline');           $.m.gedt.deadline(:gf($!m.gf))}
                        when "ct"  { $.message('Change TODO/DONE/-'); $!m.gf.edit-todo-done;}
                        when "cxv" { $.message('View/Hide Image');    $!m.gf.m-view-hide-image;}
                        when "xs"  { $.message('Save');               $!m.gf.file-save }
                        when "xc"  { $.message('Exit');               $!m.exit-gui }
                        default    { $.message(join(' Ctrl-',@ctrl-keys) ~ " is undefined") }
                    }
                }
                when 5 { # Ctrl Shift push  # TODO french keyboard :0.2:
    #                note "Key ",Buf.new($event-key.keyval).decode;
                    @ctrl-keys.push(Buf.new($event-key.keyval).decode);
                    given join('',@ctrl-keys) {
                        when  ""   {}
                        when "+"   { $.message('Zoom +');             $!m.gf.zoom(:choice(1))} 
                        when "0"   { $.message('Normal Size');        $!m.gf.zoom(:choice(0))} 
                        default    { $.message(join(' Ctrl-',@ctrl-keys) ~ " is undefined") }
                    }
                }
                when 8 { # Alt push 
                    given $event-key.keyval.fmt('0x%08x') {
                        when GDK_KEY_Up   {$!m.gf.move-up-down-button-click(:inc(-1))} # Alt-Up
                        when GDK_KEY_Down {$!m.gf.move-up-down-button-click(:inc( 1))} # Alt-Down
                    }
                }
                when 9 { # Alt Shift push
                    given $event-key.keyval.fmt('0x%08x') {
                        when GDK_KEY_Left  {$!m.gf.move-left-button-click } # Alt-Shift-left
                        when GDK_KEY_Right {$!m.gf.move-right-button-click} # Alt-Shift-Right
                    }
                }
            # TODO Alt-Enter crée un frère après
            # TODO M-S-Enter crée un fils avec TODO
            # TODO Home suivi de Alt-Enter crée un frère avant
            }
        }
        1
    }
}
