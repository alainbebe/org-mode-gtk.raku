use OrgMode::DateOrg;

# No Gnome module here
# TODO Move presentation in GtkTask :0.x:refactoring:

my $normal-size=14000; # original size of text
my $size=$normal-size; # current size of text, change with "zoom"

sub to-markup ($text-ori) {    # TODO create a class inheriting of string ?
    my $text=$text-ori;
    $text ~~ s:g/"&"/&amp;/;
    $text ~~ s:g/"<"/&lt;/;
    $text ~~ s:g/">"/&gt;/;
    return $text;
}
class Task {
    has Int      $.level       is rw;
    has Str      $.todo        is rw ="";
    has Str      $.priority    is rw ="";
    has Str      $.header      is rw; #  is required
    has DateOrg  $.closed      is rw;
    has DateOrg  $.deadline    is rw;
    has DateOrg  $.scheduled   is rw;
    has Str      @.tags        is rw;
    has Str      @.text        is rw;
    has          @.properties  is rw; # array, not hash to keep order 
    has Task     @.tasks       is rw;
    has Task     $.darth-vader is rw; # Task, I am your father

    method herite-properties($key) {
        if (@.properties) {
            my %properties; 
            %properties=$_ for @.properties; 
            return %properties{$key} if %properties{$key};
        } 
        return $.darth-vader.herite-properties($key) if $.darth-vader;
        return "DEFAULT";
    }
    method display-header ($presentation) {
        my $display;
        my $header=to-markup($.header);
        if $presentation eq 'TEXT' {
            if    ($.level==1) {$display~='<span foreground="blue" size="'~round($size*8/6)~'"       >'~$header~'</span>'}
            elsif ($.level==2) {$display~='<span foreground="deepskyblue" size="'~round($size*7/6)~'">'~$header~'</span>'}
            else               {$display~='<span foreground="black" size="'~round($size)~'"          >'~$header~'</span>'}
        } else { # DEFAULT TODO
            my $zoom= ' size="'~round($size)~'" ';          
            if (!$.todo)             {$display~=' '}
            elsif ($.todo eq "TODO") {$display~='<span foreground="red"  '~$zoom~'> TODO</span>'}
            elsif ($.todo eq "DONE") {$display~='<span foreground="green"'~$zoom~'> DONE</span>'}

            if $.priority {
                if    $.priority ~~ /A/ {$display~=' <span foreground="fuchsia"'~$zoom~'>'~$.priority~'</span>'}
                elsif $.priority ~~ /B/ {$display~=' <span foreground="grey"'~$zoom~'>'~$.priority~'</span>'}
                elsif $.priority ~~ /C/ {$display~=' <span foreground="lime"'~$zoom~'>'~$.priority~'</span>'}
            }

            if    ($.level==1) {$display~='<span weight="bold" foreground="blue" '~$zoom~'> '~$header~'</span>'}
            elsif ($.level==2) {$display~='<span weight="bold" foreground="brown"'~$zoom~'> '~$header~'</span>'}
            elsif ($.level==3) {$display~='<span weight="bold" foreground="green"'~$zoom~'> '~$header~'</span>'}
            else               {$display~='<span weight="bold" foreground="black"'~$zoom~'> '~$header~'</span>'}
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
    method level-move($change) {
        $.level+=$change;
        if $.tasks {
            for $.tasks.Array {
                $_.level-move($change);
            }
        }
    }
    #my $j=0;
    method to-text() {
        #say $j++,"-" x $.level," ",$.header," ";
        my $orgmode="";
        if $.level>0 {  # skip for the primary task $om
            $orgmode~="*" x $.level~" ";
            $orgmode~=$.todo~" " if $.todo;
            $orgmode~="\[#"~$.priority~"\] " if $.priority;
            $orgmode~=$.header;
            $orgmode~=  " " x (70-$orgmode.chars) ~ 
                        " :" ~ join(':',$.tags.Array) ~ # TODO why it's necessary to write .Array ?
                        ':' 
                        if $.tags; 
            $orgmode~="\n";
        }
        $orgmode~="CLOSED: ["~$.closed.str~"]" if $.closed; # 2 space before for Emacs, no space for Orgzly
        $orgmode~=" " if $.deadline && $.closed;
        $orgmode~="DEADLINE: <"~$.deadline.str~">" if $.deadline; # DEADLINE preceed SCHEDULED. rule of Orgzly. todo : To verifie
        $orgmode~=" " if ($.deadline || $.closed) && $.scheduled;
        $orgmode~="SCHEDULED: <"~$.scheduled.str~">" if $.scheduled;
        $orgmode~="\n" if $.closed || $.deadline || $.scheduled;
        if ($.properties) {
            $orgmode~=":PROPERTIES:\n";
            for $.properties.List { 
                my ($k,$v) = $_;
                my $len=$k.chars;
                my $white="";
                if $len < 8 { $white=" " x (8-$len)} # based on Orgzly alignment
                $orgmode~=":$k:$white $v\n"; 
            }
            $orgmode~=":END:\n";
        }
        if ($.text) {
            for $.text.Array {
                $orgmode~=$_~"\n";
            }
        }
        if $.tasks {
            for $.tasks.Array {
                $orgmode~=$_.to-text;
            }
        }
        #$j--;
        return $orgmode;
    }
    method is-child-prior($prior) {
        return True if 
            !($.todo && $.todo eq 'DONE')
            && $.priority && $.priority eq $prior; 
        if $.tasks {
            for $.tasks.Array {
                return True if $_.is-child-prior($prior);
            }
        }
        return False;
    }
    method is-in-past-and-no-done {
        return True if 
            !($.todo && $.todo eq 'DONE')
            && (
                $.scheduled && $.scheduled.begin.Date <= DateTime.now.Date
                || $.deadline && $.deadline.begin && $.deadline.begin.Date <= DateTime.now.Date);
        if $.tasks {
            for $.tasks.Array {
                return True if $_.is-in-past-and-no-done;
            }
        }
        return False;
    }
    # use when paste a branch to a different level
    method change-level($level) {
        $.level=$level;
        if $.tasks {
            for $.tasks.Array {
                $_.change-level($level+1);
            }
        }
        return False;
    }
    method find($word) {
        return True if
            !($.todo && $.todo eq 'DONE')
            && ($.header ~~ /$word/
                || $.text ~~ /$word/); 
        if $.tasks {
            for $.tasks.Array {
                return True if $_.find($word);
            }
        }
        return False;
    }
    method content-tag($tag) {
        return True if
            !($.todo && $.todo eq 'DONE')
            && grep $tag, $.tags.Array; 
        if $.tasks {
            for $.tasks.Array {
                return True if $_.content-tag($tag);
            }
        }
        return False;
    }
    method search-tags { # Todo :refactoring:
        my @tags;
        for $.tags.flat {
            @tags.push($_) if $_;
        }
        if $.tasks {
            for $.tasks.Array {
                my @tags-child=$_.search-tags;
                @tags.append(@tags-child);
            }
        }
        return @tags.sort.unique;
    }
    method inspect {
        my $prefix=" " x $.level*2;
        say $prefix,"level       ",$.level;
        say $prefix,"header      ",$.header;
        say $prefix,"todo        ",$.todo if $.todo;
        say $prefix,"priority    ",$.priority if $.priority;
        { say $prefix,"tags        ",$_ for $.tags } if $.tags;
        say $prefix,"closed      ",$.closed    if $.closed   ;
        say $prefix,"deadline    ",$.deadline  if $.deadline ;
        say $prefix,"scheduled   ",$.scheduled if $.scheduled;
        { say $prefix,"properties  ",$_ for $.properties } if $.properties;
        { say $prefix,"text        ",$_ for $.text } if $.text;
        say $prefix,"darth-vader ",$.darth-vader.header if $.darth-vader;
        if $.tasks {
            for $.tasks.Array {
                $_.inspect;
            }
        }
    }
    method refresh ($gf) {
        $gf.ts.set-value( $.iter, 0, $.display-header($gf.presentation)) if $.iter;
        $gf.ts.set-value( $.iter, 2, $.display-tags($gf.presentation)) if $.tags;
        $gf.ts.set-value( $gf.ts.iter-children($.iter), 0, $.display-text($gf.presentation)) if $.iter && $.text.trim.chars>0;
        if $.tasks {
            for $.tasks.Array {
                $_.refresh($gf);
            }
        }
    }
    method zoom($choice) {
        given $choice {
            when -1 {$size*=0.9}
            when  0 {$size=$normal-size}
            when  1 {$size*=1.1}
        }
    }
}
