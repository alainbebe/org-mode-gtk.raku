use OrgMode::Task;
use Gnome::Gtk3::TreeIter;
use Gnome::Gdk3::Pixbuf;

my $normal-size=14000; # original size of text
my $size=$normal-size; # current size of text, change with "zoom"

sub to-markup ($text-ori) {    # TODO create a class inheriting of string ? 
    my $text=$text-ori;
    $text ~~ s:g/"&"/&amp;/;
    $text ~~ s:g/"<"/&lt;/;
    $text ~~ s:g/">"/&gt;/;
    return $text;
}

class Gtk::Task is OrgMode::Task {
    has Gnome::Gtk3::TreeIter $.iter is rw;

    method display-title ($presentation) { # TODO to put in Gtk::Task
        my $display;
        my $title=to-markup($.title);
        if $presentation eq 'TEXT' {
            if    ($.stars==1) {$display~='<span foreground="blue" size="'~round($size*8/6)~'"       >'~$title~'</span>'}
            elsif ($.stars==2) {$display~='<span foreground="deepskyblue" size="'~round($size*7/6)~'">'~$title~'</span>'}
            else               {$display~='<span foreground="black" size="'~round($size)~'"          >'~$title~'</span>'}
        } else { # DEFAULT TODO
            my $zoom= ' size="'~round($size)~'" ';          
            if (!$.keyword)             {$display~=' '}
            elsif ($.keyword eq "TODO") {$display~='<span foreground="red"  '~$zoom~'> TODO</span>'}
            elsif ($.keyword eq "DONE") {$display~='<span foreground="green"'~$zoom~'> DONE</span>'}

            if $.priority {
                if    $.priority ~~ /A/ {$display~=' <span foreground="fuchsia"'~$zoom~'>'~$.priority~'</span>'}
                elsif $.priority ~~ /B/ {$display~=' <span foreground="grey"'~$zoom~'>'~$.priority~'</span>'}
                elsif $.priority ~~ /C/ {$display~=' <span foreground="lime"'~$zoom~'>'~$.priority~'</span>'}
            }

            if    ($.stars==1) {$display~='<span weight="bold" foreground="blue" '~$zoom~'> '~$title~'</span>'}
            elsif ($.stars==2) {$display~='<span weight="bold" foreground="brown"'~$zoom~'> '~$title~'</span>'}
            elsif ($.stars==3) {$display~='<span weight="bold" foreground="green"'~$zoom~'> '~$title~'</span>'}
            else               {$display~='<span weight="bold" foreground="black"'~$zoom~'> '~$title~'</span>'}
        }
        return $display;
    }
    method display-tags ($presentation) {
        my $zoom= ' size="'~round($size)~'" ';          
        my $display='';
        if $presentation ne 'TEXT' {
            if $.tags {
                $display~=' <span foreground="grey"'~$zoom~'>'~$.tags~'</span>';
            }
        }
        return $display;
    }
    method display-text ($presentation) {
        my $display='';
        if $.text {
            my $text=to-markup($.text[0]);  # TODO because "text" is an array of 1 multiline string. Change one day to real array
            if $presentation eq 'TEXT' {
                $display~='<span foreground="black" size="'~round($size)~'"          >'~$text~'</span>';
            } else {    
                $display~='<span size="'~round($size)~'"          >'~$text~'</span>';
            }
        }
        return $display;
    }
    method display-text-without-image ($presentation) {
        my $display='';
        if $.text {
            my $text=to-markup($.text[0]);  # TODO because "text" is an array of 1 multiline string. Change one day to real array
            $text ~~ s/ "[[" ("./img/" .+ ) "]]" //;
            if $presentation eq 'TEXT' {
                $display~='<span foreground="black" size="'~round($size*2)~'"          >'~$text~'</span>';
            } else {    
                $display~=$text;
            }
        }
        return $display;
    }
    method inspect {
        callsame;
        my $prefix=" " x $.stars*2;
        say $prefix,"iter        ",$.iter;
        say $prefix,"-----";
    }
    method get-image {
        my Gnome::Gdk3::Pixbuf $pb;
        $.text ~~ / "[[" ("./img/" .+ ) "]]" /;
        $pb .= new(:file($0.Str));
        return $pb;
    }
    method refresh ($gf) {
        $gf.ts.set-value( $.iter, 0, $.display-title($gf.presentation)) if $.iter;
        $gf.ts.set-value( $.iter, 2, $.display-tags($gf.presentation)) if $.tags;
        $gf.ts.set-value( $gf.ts.iter-children($.iter), 0, $.display-text($gf.presentation)) if $.iter && $.text.trim.chars>0;
        if $.tasks {
            for $.tasks.Array {
                $_.refresh($gf);
            }
        }
    }
    method zoom($choice) { # TODO to put in Gtk::File :refactoring:
        given $choice {
            when -1 {$size*=0.9}
            when  0 {$size=$normal-size}
            when  1 {$size*=1.1}
        }
    }
}

