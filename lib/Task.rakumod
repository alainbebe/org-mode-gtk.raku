use DateOrg;

sub to-markup ($text is rw) is export {    # TODO create a class inheriting of string ?
    $text ~~ s:g/"&"/&amp;/;
    $text ~~ s:g/"<"/&lt;/;
    $text ~~ s:g/">"/&gt;/;
    return $text;
}
class Task {
    has Int      $.level       is rw;
    has Str      $.todo        is rw;
    has Str      $.priority    is rw;
    has Str      $.header      is rw; #  is required
    has DateOrg  $.scheduled   is rw;
    has DateOrg  $.deadline    is rw;
    has Str      @.tags        is rw;
    has Str      @.text        is rw;
    has          @.properties  is rw; # array, not hash to keep order 
    has Task     @.tasks       is rw;
    has Task     $.darth-vader is rw; # Task, I am your father

    method herite-properties($key) {
        if (@.properties) {
            my %properties=split(" ",@.properties); # TODO [#A] Why split ?
#            say %properties;
            return %properties{$key} if %properties{$key};
        } 
        return $.darth-vader.herite-properties($key) if $.darth-vader;
        return "DEFAULT";
    }
    method display-header {
        my $display;
        my $header=to-markup($.header);
        if $.herite-properties('presentation') eq 'TEXT' {
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
            $orgmode~=" :" ~ join(':',$.tags.Array) ~ ':' if $.tags; # TODO why it's necessary to write .Array ?
            $orgmode~="\n";
        }
        $orgmode~="DEADLINE: <"~$.deadline.str~">" if $.deadline; # DEADLINE preceed SCHEDULED. rule of Orgzly. todo : To verifie
        $orgmode~=" " if $.deadline && $.scheduled;
        $orgmode~="SCHEDULED: <"~$.scheduled.str~">" if $.scheduled;
        $orgmode~="\n" if $.deadline || $.scheduled;
        if ($.properties) {
            $orgmode~=":PROPERTIES:\n";
            for $.properties.Array { 
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
    method scheduled-today {
        say "ind : ",$.header, $.scheduled if $.scheduled && $.scheduled.begin eq &d-now(); # TODO doesn't work because fomrat is date-time, not date
        if $.tasks {
            for $.tasks.Array {
                $_.scheduled-today();
            }
        }
    }
    method inspect($task) {
        my $prefix=" " x $task.level*2;
        say $prefix,"level       ",$task.level;
        say $prefix,"header      ",$task.header;
        say $prefix,"todo        ",$task.todo if $task.todo;
        say $prefix,"priority    ",$task.priority if $task.priority;
        say $prefix,"tags        ",$_ for $task.tags;
        say $prefix,"deadline    ",$task.deadline if $task.deadline;
        say $prefix,"scheduled   ",$task.scheduled if $task.scheduled;
        say $prefix,"properties  ",$_ for $task.properties;
        say $prefix,"text        ",$_ for $task.text;
        say $prefix,"darth-vader ",$task.darth-vader.header if $task.darth-vader;
        if $task.tasks {
            for $task.tasks.Array {
                $.inspect($_);
            }
        }
        say $prefix,"-----";
    }
}