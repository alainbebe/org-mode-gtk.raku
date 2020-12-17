use GtkFile;
use GtkEditTask;

use Gnome::Gtk3::Window;
use Gnome::Gtk3::Main;
use Gnome::Gtk3::Dialog;
use Gnome::Gdk3::Events;
use Gnome::Gdk3::Keysyms;

class GtkKeyEvent {
    has Gnome::Gtk3::Window $!top-window; 
    has Gnome::Gtk3::Main $!m ;
    has GtkFile $!gf;
    has GtkEditTask $.gedt;
    has @ctrl-keys;
    has $is-maximized=False; # TODO use gtk-window.is_maximized in Window.pm6 (uncomment =head2 [[gtk_] window_] is_maximized) :0.x:

    submethod BUILD ( :$!gf, :$!m, Gnome::Gtk3::Window:D :$!top-window!) {  # TODO improve :refactoring:0.2:
        $!gedt .= new(:top-window($!top-window));
    }

    method exit-gui ( --> Int ) {
        my $button=$!gf.try-save;
        $!m.gtk-main-quit if $button != GTK_RESPONSE_CANCEL;
        1
    }
    method handle-keypress ( N-GdkEventKey $event-key, :$widget , :$l-info) {
#        note 'event: ', GdkEventType($event-key.type), ', ', $event-key.keyval.fmt('0x%08x');
        if $event-key.type ~~ GDK_KEY_PRESS {
#            note "State : ", $event-key.state;
            given $event-key.state {
                when 0 { # No Ctrl, Alt, Shift.
                    given $event-key.keyval.fmt('0x%08x') {
                        when GDK_KEY_F11 {
                            $is-maximized ?? $!top-window.unmaximize !! $!top-window.maximize;
                            $is-maximized=!$is-maximized; 
                        }
                    }
                }
                when 1 { # Shift push
                    given $event-key.keyval.fmt('0x%08x') {
                        when GDK_KEY_Up   {$!gf.priority-up}
                        when GDK_KEY_Down {$!gf.priority-down}
                    }
                }
                when 4 { # Ctrl push
    #                note "ekv : ",$event-key.keyval;
                    return 1 if $event-key.keyval == 65505; # "ctrl-shift" witout other key
    #                note "Key ",Buf.new($event-key.keyval).decode;
                    @ctrl-keys.push(Buf.new($event-key.keyval).decode);
                    given join('',@ctrl-keys) {
                        when  ""  {}
                        when  "c"  {$l-info.set-label("C-c")}
                        when  "x"  {$l-info.set-label("C-x")}
                        when  "cx" {$l-info.set-label("C-c C-x")}
                        when "-"   {@ctrl-keys=''; $l-info.set-label('Zoom -');             $!gf.zoom(:choice(-1))} 
    #                    when "cc" {@ctrl-keys=''; say "cc"}
    #                    when "cq" {@ctrl-keys=''; say "edit tag"}
    #                    when "k"  {@ctrl-keys=''; $l-info.set-label('Delete branch');      $!gf.delete-branch($clicked-task.iter); }
                        when "cs"  {@ctrl-keys=''; $l-info.set-label('Schedule');           $.gedt.scheduled(:gf($!gf))} 
                        when "cd"  {@ctrl-keys=''; $l-info.set-label('Deadline');           $.gedt.deadline(:gf($!gf))}
                        when "ct"  {@ctrl-keys=''; $l-info.set-label('Change TODO/DONE/-'); $!gf.edit-todo-done;}
                        when "cxv" {@ctrl-keys=''; $l-info.set-label('View/Hide Image');    $!gf.m-view-hide-image;}
                        when "xs"  {@ctrl-keys=''; $l-info.set-label('Save');               $!gf.file-save}
                        when "xc"  {@ctrl-keys=''; $l-info.set-label('Exit');               self.exit-gui}
                        default    {$l-info.set-label(join(' Ctrl-',@ctrl-keys) ~ " is undefined");@ctrl-keys='';}
                    }
                }
                when 5 { # Ctrl Shift push  # TODO french keyboard :0.2:
    #                note "Key ",Buf.new($event-key.keyval).decode;
                    @ctrl-keys.push(Buf.new($event-key.keyval).decode);
                    given join('',@ctrl-keys) {
                        when  ""   {}
                        when "+"   {@ctrl-keys=''; $l-info.set-label('Zoom +');             $!gf.zoom(:choice(1))} 
                        when "0"   {@ctrl-keys=''; $l-info.set-label('Normal Size');        $!gf.zoom(:choice(0))} 
                        default    {$l-info.set-label(join(' Ctrl-',@ctrl-keys) ~ " is undefined");@ctrl-keys='';}
                    }
                }
                when 8 { # Alt push 
                    given $event-key.keyval.fmt('0x%08x') {
                        when GDK_KEY_Up   {$!gf.move-up-down-button-click(:inc(-1))} # Alt-Up
                        when GDK_KEY_Down {$!gf.move-up-down-button-click(:inc( 1))} # Alt-Down
                    }
                }
                when 9 { # Alt Shift push
                    given $event-key.keyval.fmt('0x%08x') {
                        when GDK_KEY_Left  {$!gf.move-left-button-click } # Alt-Shift-left
                        when GDK_KEY_Right {$!gf.move-right-button-click} # Alt-Shift-Right
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
