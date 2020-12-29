use OrgMode::Date;

# No Gnome module here

# The name of attributes comes from https://orgmode.org/worg/dev/org-syntax.html (to finalize) :refactoring:
# STARS KEYWORD PRIORITY TITLE TAGS
class OrgMode::Task {
    has Int           $.stars       is rw; # required >0 (or =0 for "document", father of primary title
    has Str           $.keyword     is rw ="";
    has Str           $.priority    is rw ="";
    has Str           $.title       is rw; #  is required (Orgzly) # TODO not required in :emacs:
    has Str           @.tags        is rw;
    has OrgMode::Date $.closed      is rw;
    has OrgMode::Date $.deadline    is rw;
    has OrgMode::Date $.scheduled   is rw;
    has Str           @.text        is rw;
    has               @.properties  is rw; # array, not hash to keep order 
    has OrgMode::Task @.tasks       is rw;
    has OrgMode::Task $.darth-vader is rw; # Task, I am your father

    method herite-properties($name) {
        if (@.properties) {
            my %properties; 
            %properties=$_ for @.properties; 
            return %properties{$name} if %properties{$name};
        } 
        return $.darth-vader.herite-properties($name) if $.darth-vader;
        return "DEFAULT";
    }
    method stars-move($change) {
        $.stars+=$change;
        if $.tasks {
            for $.tasks.Array {
                $_.stars-move($change);
            }
        }
    }
    #my $j=0;
    method to-text() {
        #say $j++,"-" x $.stars," ",$.title," ";
        my $orgmode="";
        if $.stars>0 {  # skip for the primary task $om
            $orgmode~="*" x $.stars~" ";
            $orgmode~=$.keyword~" " if $.keyword;
            $orgmode~="\[#"~$.priority~"\] " if $.priority;
            $orgmode~=$.title;
            $orgmode~=  " " x (70-$orgmode.chars) ~ 
                        " :" ~ join(':',$.tags.Array) ~ # TODO why it's necessary to write .Array ?
                        ':' 
                        if $.tags; 
            $orgmode~="\n";
        }
        $orgmode~="CLOSED: ["~$.closed.str~"]" if $.closed; # 2 space before for Emacs, no space for Orgzly
        $orgmode~=" " if $.deadline && $.closed;
        $orgmode~="DEADLINE: <"~$.deadline.str~">" if $.deadline; # TODO DEADLINE preceed SCHEDULED. rule of Orgzly. To :verify:
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
            !($.keyword && $.keyword eq 'DONE')
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
            !($.keyword && $.keyword eq 'DONE')
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
    # use when paste a branch to a different stars
    method change-stars($stars) { # TODO doublon with stars-move :refactoring:
        $.stars=$stars;
        if $.tasks {
            for $.tasks.Array {
                $_.change-stars($stars+1);
            }
        }
        return False;
    }
    method find($word) {
        return True if
            !($.keyword && $.keyword eq 'DONE')
            && ($.title ~~ /$word/
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
            !($.keyword && $.keyword eq 'DONE')
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
        my $prefix=" " x $.stars*2;
        say $prefix,"stars       ",$.stars;
        say $prefix,"title    ",$.title;
        say $prefix,"keyword     ",$.keyword if $.keyword;
        say $prefix,"priority    ",$.priority if $.priority;
        { say $prefix,"tags        ",$_ for $.tags } if $.tags;
        say $prefix,"closed      ",$.closed    if $.closed   ;
        say $prefix,"deadline    ",$.deadline  if $.deadline ;
        say $prefix,"scheduled   ",$.scheduled if $.scheduled;
        { say $prefix,"properties  ",$_ for $.properties } if $.properties;
        { say $prefix,"text        ",$_ for $.text } if $.text;
        say $prefix,"darth-vader ",$.darth-vader.title if $.darth-vader;
        if $.tasks {
            for $.tasks.Array {
                $_.inspect;
            }
        }
    }
}
