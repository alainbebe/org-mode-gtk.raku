use DateOrg;

use Gnome::Gtk3::Dialog;
use Gnome::Gtk3::Box;
use Gnome::Gtk3::Grid;
use Gnome::Gtk3::Label;
use Gnome::Gtk3::ComboBoxText;
use Gnome::Gtk3::Button;
use Gnome::Gtk3::CheckButton;

class ManageDate {
    has Gnome::Gtk3::Window $!top-window;

    submethod BUILD ( Gnome::Gtk3::Window:D :$!top-window! ) { }

    multi method create-button($label,$method,Gnome::Gtk3::Label $l-result,DateOrg $d,DateTime $next-date,
            Gnome::Gtk3::ComboBoxText $year, Gnome::Gtk3::ComboBoxText $month, Gnome::Gtk3::ComboBoxText $day) {
        my Gnome::Gtk3::Button $b  .= new(:label($label));
        $b.register-signal(self, $method, 'clicked',:l-result($l-result),:date($d),:next-date($next-date),
                                                    :year($year),:month($month),:day($day));
        return $b;
    }
    method year (:$widget, :$label,:$date) {
        $date.begin=$date.begin.clone(year => $widget.get-active-text);
        $label.set-text($date.str);
    }
    method month (:$widget, :$label,:$date) {
        $date.begin=$date.begin.clone(month => $widget.get-active-text);
        $label.set-text($date.str);
    }
    method day (:$widget, :$label,:$date,:$type) {
#say "t ",$type;
#        $date.begin=$date.begin.clone($type => $widget.get-active-text); # TODO Doesn't work
        $date.begin=$date.begin.clone(day => $widget.get-active-text);
        $label.set-text($date.str);
    }
    method today (:$widget, :$l-result, :$date!, :$next-date!, :$year!, :$month!, :$day!) {
        $date.begin=$date.begin.clone(year => $next-date.year, month => $next-date.month, day => $next-date.day);
        $l-result.set-text($date.str);
        $year.set-active($date.begin.year-2018);
        $month.set-active($date.begin.month-1);
        $day.set-active($date.begin.day-1);
        1
    }
    method begin-hour (:$widget, :$label,:$date) {
        $date.begin=$date.begin.clone(hour => $widget.get-active-text);
        $label.set-text($date.str);
    }
    method begin-min (:$widget, :$label,:$date) {
        $date.begin=$date.begin.clone(minute => $widget.get-active-text);
        $label.set-text($date.str);
    }
    method begin-time (:$widget, :$label,:$date,:$hour,:$min) {
        if $widget.get-active.Bool {
            $date.begin=$date.begin.clone(hour => $hour.get-active-text);
            $date.begin=$date.begin.clone(minute => $min.get-active-text);
            $hour.set-sensitive(True); 
            $min.set-sensitive(True); 
        } else {
            $date.begin=$date.begin.clone(hour => 0);
            $date.begin=$date.begin.clone(minute => 0);
            $hour.set-sensitive(False); 
            $min.set-sensitive(False); 
        }
        $label.set-text($date.str);
    }
    method end-hour (:$widget, :$label,:$date) {
        $date.end=$date.end.clone(hour => $widget.get-active-text);
        $label.set-text($date.str);
    }
    method end-min (:$widget, :$label,:$date) {
        $date.end=$date.end.clone(minute => $widget.get-active-text);
        $label.set-text($date.str);
    }
my $format-org-time = sub (DateTime $self) { # TODO improve and put in DateOrg :refactoring:
    if ($self.hour==0 && $self.minute==0) {
        sprintf ''; 
    } else {
        sprintf '%02d:%02d', 
                $self.hour,$self.minute;
    }
}
    method end-time (:$widget, :$label,:$date,:$hour,:$min) {
        if $widget.get-active.Bool {
            $date.end=DateTime.new(
                year => $date.begin.year, 
                month => $date.begin.month, 
                day => $date.begin.day,
                hour => $hour.get-active-text,
                minute => $min.get-active-text,
                formatter => $format-org-time
            );
            $hour.set-sensitive(True); 
            $min.set-sensitive(True); 
        } else {
            $date.end=$date.end.clone(hour => 0);
            $date.end=$date.end.clone(minute => 0);
            $hour.set-sensitive(False); 
            $min.set-sensitive(False); 
        }
        $label.set-text($date.str);
    }
    method repeater-type (:$widget, :$label,:$date) {
        $date.repeater-type($widget.get-active-text);
        $label.set-text($date.str);
    }
    method repeater-freq (:$widget, :$label,:$date) {
        $date.repeater-freq($widget.get-active-text);
        $label.set-text($date.str);
    }
    method repeater-period (:$widget, :$label,:$date) {
        $date.repeater-period($widget.get-active-text);
        $label.set-text($date.str);
    }
    method repeater ( :$widget, :$label,:$date, :$type,:$freq,:$period) {
        if $widget.get-active.Bool {
            $date.repeater=$type.get-active-text~$freq.get-active-text~$period.get-active-text;
            $type.set-sensitive(True); 
            $freq.set-sensitive(True); 
            $period.set-sensitive(True); 
        } else {
            $date.repeater=Nil;
            $type.set-sensitive(False); 
            $freq.set-sensitive(False); 
            $period.set-sensitive(False); 
        }
        $label.set-text($date.str);
    }
    method delay-type (:$widget, :$label,:$date) {
        $date.delay-type($widget.get-active-text);
        $label.set-text($date.str);
    }
    method delay-freq (:$widget, :$label,:$date) {
        $date.delay-freq($widget.get-active-text);
        $label.set-text($date.str);
    }
    method delay-period (:$widget, :$label,:$date) {
        $date.delay-period($widget.get-active-text);
        $label.set-text($date.str);
    }
    method delay ( :$widget, :$label,:$date, :$type,:$freq,:$period) {
        if $widget.get-active.Bool {
            $date.delay=$type.get-active-text~$freq.get-active-text~$period.get-active-text;
            $type.set-sensitive(True); 
            $freq.set-sensitive(True); 
            $period.set-sensitive(True); 
        } else {
            $date.delay=Nil;
            $type.set-sensitive(False); 
            $freq.set-sensitive(False); 
            $period.set-sensitive(False); 
        }
        $label.set-text($date.str);
    }
    method manage-date (DateOrg $date is rw) {
        my Gnome::Gtk3::Dialog $dialog2 .= new(
            :title("Manage Date"), 
            :parent($!top-window),
            :flags(GTK_DIALOG_DESTROY_WITH_PARENT),
            :button-spec( [
#                "Clear", 1, # TODO to manage 0.x
                "_Cancel", GTK_RESPONSE_CANCEL,
                "_Ok", GTK_RESPONSE_OK,
            ] )
        );
        my Gnome::Gtk3::Box $content-area .= new(:native-object($dialog2.get-content-area));
        my $cur=$date ?? $date.str !! &dd-now();
        $cur ~~ /<dateorg>/;
        my DateOrg $d=date-from-dateorg($/{'dateorg'});
        
        my Gnome::Gtk3::Grid $gd .= new;
        $content-area.gtk_container_add($gd);
        my $l=0; 

        # result
        my Gnome::Gtk3::Label $l-result .= new(:text($cur));
        $gd.gtk-grid-attach( $l-result ,                                       1, $l, 4, 1);
        $l++;

        $gd.gtk-grid-attach( Gnome::Gtk3::Label.new(:text('Day')),             0, $l, 1, 1);
        $l++;

        # Time
        my Gnome::Gtk3::ComboBoxText $cbt-year .=new;
        $cbt-year.append-text("$_") for 2018..2025;
        $cbt-year.set-active($d.begin.year-2018);
        $cbt-year.register-signal(self, 'year', 'changed',:label($l-result),:date($d));
        $gd.gtk-grid-attach( $cbt-year,                                        0, $l, 2, 1);
        my Gnome::Gtk3::ComboBoxText $cbt-month .=new;
        $cbt-month.append-text("$_") for 1..12;
        $cbt-month.set-active($d.begin.month-1);
        $cbt-month.register-signal(self, 'month', 'changed',:label($l-result),:date($d));
        $gd.gtk-grid-attach( $cbt-month,                                       2, $l, 2, 1);
        my Gnome::Gtk3::ComboBoxText $cbt-day .=new;
        $cbt-day.append-text("$_") for 1..31;
        $cbt-day.set-active($d.begin.day-1);
        $cbt-day.register-signal(self, 'day', 'changed',:label($l-result),:date($d),:type('day')); # TODO type() not work, to improve
        $gd.gtk-grid-attach( $cbt-day,                                         4, $l, 2, 1);
        $l++;

        # 3 buttons
        my $d-now = DateTime.now.later(days => 1);
        $gd.gtk-grid-attach( $.create-button('Today','today',$l-result, $d,DateTime.now,
                                                $cbt-year,$cbt-month,$cbt-day), 0, $l, 2, 1);
        $gd.gtk-grid-attach( $.create-button('Tomorrow','today',$l-result, $d,DateTime.now.later(days => 1),
                                                $cbt-year,$cbt-month,$cbt-day), 2, $l, 2, 1);
        $gd.gtk-grid-attach( $.create-button('Next Week','today',$l-result, $d,DateTime.now.later(days => 7),
                                                $cbt-year,$cbt-month,$cbt-day), 4, $l, 2, 1);
        $l++;

        # Time
        $gd.gtk-grid-attach(Gnome::Gtk3::Label.new(:text('Hour')),             0, $l, 1, 1);
        $gd.gtk-grid-attach(Gnome::Gtk3::Label.new(:text('End')),              3, $l, 1, 1);
        $l++;

        my Gnome::Gtk3::ComboBoxText $cbt-hour .=new;
        $cbt-hour.append-text("$_") for 0..23;
        $cbt-hour.set-active($d.begin.hour??$d.begin.hour!!0);
        $cbt-hour.set-sensitive($d.begin.hour+$d.begin.minute>0);
        $cbt-hour.register-signal(self, 'begin-hour', 'changed',:label($l-result),:date($d));
        $gd.gtk-grid-attach( $cbt-hour,                                        0, $l, 1, 1);
        my Gnome::Gtk3::ComboBoxText $cbt-min  .=new;
        $cbt-min.append-text("$_") for (0..59);
        $cbt-min.set-active($d.begin.minute??$d.begin.minute!!0);
        $cbt-min.set-sensitive($d.begin.hour+$d.begin.minute>0);
        $cbt-min.register-signal(self, 'begin-min', 'changed',:label($l-result),:date($d));
        $gd.gtk-grid-attach( $cbt-min,                                         1, $l, 1, 1);
        my Gnome::Gtk3::CheckButton $cb-begin .= new;
        $cb-begin.set-active($d.begin.hour+$d.begin.minute>0);
        $cb-begin.register-signal( self, 'begin-time', 'toggled',:label($l-result),:date($d),
                                :hour($cbt-hour),:min($cbt-min));
        $gd.gtk-grid-attach( $cb-begin,                                         2, $l, 1, 1);

        my Gnome::Gtk3::ComboBoxText $cbt-hour-e .=new;
        $cbt-hour-e.append-text("$_") for 0..23;
        $cbt-hour-e.set-active($d.end && $d.end.hour??$d.end.hour!!0);
        $cbt-hour-e.set-sensitive($d.end ?? ($d.end.hour+$d.end.minute>0) !! 0);
        $cbt-hour-e.register-signal(self, 'end-hour', 'changed',:label($l-result),:date($d));
        $gd.gtk-grid-attach( $cbt-hour-e,                                      3, $l, 1, 1);
        my Gnome::Gtk3::ComboBoxText $cbt-min-e  .=new;
        $cbt-min-e.append-text("$_") for 0..59;
        $cbt-min-e.set-active($d.end && $d.end.minute??$d.end.minute!!0);
        $cbt-min-e.set-sensitive($d.end ?? ($d.end.hour+$d.end.minute>0) !! 0);
        $cbt-min-e.register-signal(self, 'end-min', 'changed',:label($l-result),:date($d));
        $gd.gtk-grid-attach( $cbt-min-e,                                       4, $l, 1, 1);
        my Gnome::Gtk3::CheckButton $cb-end .= new;
        $cb-end.set-active($d.end ?? ($d.end.hour+$d.end.minute>0) !! 0);
        $cb-end.register-signal( self, 'end-time', 'toggled',:label($l-result),:date($d),
                                :hour($cbt-hour-e),:min($cbt-min-e));
        $gd.gtk-grid-attach( $cb-end,                                          5, $l, 1, 1);
        $l++;

        $gd.gtk-grid-attach( Gnome::Gtk3::Label.new(:text('Repeat')),          0, $l, 1, 1);
        $l++;

        my Gnome::Gtk3::ComboBoxText $cbt-m .=new;
        $cbt-m.append-text($_) for <+ ++ .+>;
        if    !$d.repeater           {$cbt-m.set-active(2);
                                      $cbt-m.set-sensitive($d.repeater??1!!0)}
        elsif  $d.repeater ~~ /"++"/ {$cbt-m.set-active(1)}
        elsif  $d.repeater ~~ /".+"/ {$cbt-m.set-active(2)}
        else                         {$cbt-m.set-active(0)}   # $d.repeater ~~ /"+"/ 
        $cbt-m.register-signal(self, 'repeater-type', 'changed',:label($l-result),:date($d));
        $gd.gtk-grid-attach( $cbt-m,                                           0, $l, 1, 1);
        my Gnome::Gtk3::ComboBoxText $cbt-int .=new;
        $cbt-int.append-text("$_") for 0..10;
        if !$d.repeater {
            $cbt-int.set-active(1);
            $cbt-int.set-sensitive($d.repeater??1!!0);
        } else {
            $d.repeater ~~ /(\d+)/;
            $cbt-int.set-active($0.Int);
        }
        $cbt-int.register-signal(self, 'repeater-freq', 'changed',:label($l-result),:date($d));
        $gd.gtk-grid-attach( $cbt-int,                                           1, $l, 1, 1);
        my Gnome::Gtk3::ComboBoxText $cbt .=new;
        $cbt.append-text($_) for <d w m y>;
        if    !$d.repeater           {$cbt.set-active(1);
                                      $cbt.set-sensitive($d.repeater??1!!0)}
        elsif  $d.repeater ~~ /"d"/ {$cbt.set-active(0)}
        elsif  $d.repeater ~~ /"w"/ {$cbt.set-active(1)}
        elsif  $d.repeater ~~ /"m"/ {$cbt.set-active(2)}
        else                        {$cbt.set-active(3)}   # $d.repeater ~~ /"y"/ 
        $cbt.register-signal(self, 'repeater-period', 'changed',:label($l-result),:date($d));
        $gd.gtk-grid-attach( $cbt,                                               2, $l, 1, 1);
        my Gnome::Gtk3::CheckButton $cb-repeater .= new;
        $cb-repeater.set-active($d.repeater??1!!0);
        $cb-repeater.register-signal( self, 'repeater', 'toggled',:label($l-result),:date($d),
                                :type($cbt-m),:freq($cbt-int),:period($cbt));
        $gd.gtk-grid-attach( $cb-repeater,                                       3, $l, 1, 1);
        $l++;

        $gd.gtk-grid-attach( Gnome::Gtk3::Label.new(:text('Delay')),             0, $l, 1, 1);
        $l++;

        my Gnome::Gtk3::ComboBoxText $cbt2-m .=new;
        $cbt2-m.append-text($_) for <- -->;
        if    !$d.delay           {$cbt2-m.set-active(0);
                                   $cbt2-m.set-sensitive($d.repeater??1!!0)}
        elsif  $d.delay ~~ /"--"/ {$cbt2-m.set-active(1)}
        else                      {$cbt2-m.set-active(0)}   # $d.delay ~~ /"-"/ 
        $cbt2-m.register-signal(self, 'delay-type', 'changed',:label($l-result),:date($d));
        $gd.gtk-grid-attach( $cbt2-m,                                            0, $l, 1, 1);
        my Gnome::Gtk3::ComboBoxText $cbt2-int .=new;
        $cbt2-int.append-text("$_") for 0..10;
        if !$d.delay {
            $cbt2-int.set-active(1);
            $cbt2-int.set-sensitive($d.repeater??1!!0);
        } else {
            $d.delay ~~ /(\d+)/;
            $cbt2-int.set-active($0.Int);
        }
        $cbt2-int.register-signal(self, 'delay-freq', 'changed',:label($l-result),:date($d));
        $gd.gtk-grid-attach( $cbt2-int,                                           1, $l, 1, 1);
        my Gnome::Gtk3::ComboBoxText $cbt2 .=new;
        $cbt2.append-text($_) for <d w m y>;
        if    !$d.delay           {$cbt2.set-active(0);
                                   $cbt2.set-sensitive($d.repeater??1!!0)}
        elsif  $d.delay ~~ /"d"/  {$cbt2.set-active(0)}
        elsif  $d.delay ~~ /"w"/  {$cbt2.set-active(1)}
        elsif  $d.delay ~~ /"m"/  {$cbt2.set-active(2)}
        else                      {$cbt2.set-active(3)}   # $d.delay ~~ /"y"/ 
        $cbt2.register-signal(self, 'delay-period', 'changed',:label($l-result),:date($d));
        $gd.gtk-grid-attach( $cbt2,                                               2, $l, 1, 1);
        my Gnome::Gtk3::CheckButton $cb-delay .= new;
        $cb-delay.set-active($d.delay??1!!0);
        $cb-delay.register-signal( self, 'delay', 'toggled',:label($l-result),:date($d),
                                :type($cbt2-m),:freq($cbt2-int),:period($cbt2));
        $gd.gtk-grid-attach( $cb-delay,                                           3, $l, 1, 1);
        $l++;

        $dialog2.show-all;
        my $response = $dialog2.gtk-dialog-run;
        $dialog2.gtk_widget_destroy;
        $response == GTK_RESPONSE_OK ?? $d !! $date;
    }
}

