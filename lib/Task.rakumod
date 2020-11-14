use DateOrg;

sub to-markup ($text is rw) is export {    # TODO create a class inheriting of string ?
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
            if    ($.level==1) {$display~='<span foreground="blue" size="xx-large"      >'~$header~'</span>'}
            elsif ($.level==2) {$display~='<span foreground="deepskyblue" size="x-large">'~$header~'</span>'}
            else               {$display~='<span foreground="black" size="x-large"      >'~$header~'</span>'}
        } else { # DEFAULT TODO
            if (!$.todo)             {$display~=' '}
            elsif ($.todo eq "TODO") {$display~='<span foreground="red"  > TODO</span>'}
            elsif ($.todo eq "DONE") {$display~='<span foreground="green"> DONE</span>'}

            if $.priority {
                if    $.priority ~~ /A/ {$display~=' <span foreground="fuchsia">'~$.priority~'</span>'}
                elsif $.priority ~~ /B/ {$display~=' <span foreground="grey">'~$.priority~'</span>'}
                elsif $.priority ~~ /C/ {$display~=' <span foreground="lime">'~$.priority~'</span>'}
            }

            if    ($.level==1) {$display~='<span weight="bold" foreground="blue" > '~$header~'</span>'}
            elsif ($.level==2) {$display~='<span weight="bold" foreground="brown"> '~$header~'</span>'}
            else               {$display~='<span weight="bold" foreground="black"> '~$header~'</span>'}
        }
        return $display;
    }
    method display-tags ($presentation) {
        my $display='';
        if $presentation ne 'TEXT' {
            if $.tags {
                $display~=' <span foreground="grey">'~$.tags~'</span>';
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
        $orgmode~="CLOSED: ["~$.closed.str~"]" if $.closed;
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
}
