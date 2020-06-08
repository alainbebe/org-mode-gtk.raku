#!/usr/bin/env perl6

use v6;

use Gnome::N::N-GObject;
use Gnome::GObject::Type;
use Gnome::GObject::Value;
use Gnome::Gtk3::Main;
use Gnome::Gtk3::Window;
use Gnome::Gtk3::Grid;
use Gnome::Gtk3::Button;
use Gnome::Gtk3::RadioButton;
use Gnome::Gtk3::CheckButton;
use Gnome::Gtk3::Label;
use Gnome::Gtk3::Entry;
use Gnome::Gtk3::TreePath;
use Gnome::Gtk3::TreeStore;
use Gnome::Gtk3::CellRendererText;
use Gnome::Gtk3::TreeView;
use Gnome::Gtk3::TreeViewColumn;
use Gnome::Gtk3::TreeIter;
use Gnome::Gtk3::MenuBar;
use Gnome::Gtk3::Menu;
use Gnome::Gtk3::MenuItem;
use Gnome::Gtk3::Dialog;
use Gnome::Gtk3::MessageDialog;
use Gnome::Gtk3::AboutDialog;
use Gnome::Gtk3::Box;
use Gnome::Gtk3::TextView;
use Gnome::Gtk3::TextBuffer;
use Gnome::Gtk3::FileChooser;
use Gnome::Gtk3::FileChooserDialog;
use Gnome::Gtk3::ScrolledWindow;
use Gnome::Gtk3::TreeSelection;
use Gnome::Gtk3::ComboBoxText;
use Gnome::Gtk3::Notebook;
use NativeCall;
use Gnome::N::X;

use Data::Dump;

my $change=0;           # for ask question to save when quit
my $debug=1;            # to debug =1
my $toggle_rb=False;    # when click on a radio-buttun we have 2 signals. Take only the second
my $toggle_rb_pr=False; # when click on a radio-buttun we have 2 signals. Take only the second
my $presentation=True;  # presentation in mode TODO or Textual
my $no-done=True;       # display with no DONE
my $prior-A=False;      # display #A          
my $i=0;                # for creation of level1 in tree
my $display-branch-task; # La tache qui sert de base à l'arborescence
my $format-org-date = sub (DateTime $self) { 
    my $dow;
    given $self.day-of-week {
        when 1 { $dow='Mon'}
        when 2 { $dow='Tue'}
        when 3 { $dow='Wen'}
        when 4 { $dow='Thu'}
        when 5 { $dow='Fri'}
        when 6 { $dow='Sat'}
        when 7 { $dow='Son'}
    }
    if ($self.hour==0 && $self.minute==0) {
        sprintf '%04d-%02d-%02d %s', 
            $self.year, $self.month, $self.day, $dow;
    } else {
        sprintf '%04d-%02d-%02d %s %02d:%02d', 
            $self.year, $self.month, $self.day, $dow, $self.hour,$self.minute;
    }
}
my $format-org-time = sub (DateTime $self) { 
    sprintf '%02d:%02d', 
            $self.hour,$self.minute;
}
my $d-now = DateTime.now(
    formatter => $format-org-date
);
my $now = DateTime.now(
    formatter => {
        my $dow;
        given .day-of-week {
            when 1 { $dow='lun'}
            when 2 { $dow='mar'}
            when 3 { $dow='mer'}
            when 4 { $dow='jeu'}
            when 5 { $dow='ven'}
            when 6 { $dow='sam'}
            when 7 { $dow='dim'}
        }
        sprintf '%04d-%02d-%02d %s %02d:%02d', 
        .year, .month, .day, $dow, .hour, .minute
    }
);
my token year   {\d\d\d\d}
my token month  {\d\d}
my token day    {\d\d}
my token wday   {<alpha>+}                     # TODO append boundary check
my token hour   {\d\d}
my token minute {\d\d}
my token time   {<hour>":"<minute>}
my token repeat {(\.?\+\+?)(\d+)(\w+)}         # +, ++, .+
my token delay  {(\-\-?)(\d+)(\w+)}            # -, --
my token dateorg { <year>"-"<month>"-"<day>
                (" "<wday>)?                   # TODO change ( by [ ?
                (" "<time>("-"<time>)?)? 
                (" "<repeat>)?
                (" "<delay>)?
} 
my Gnome::Gtk3::TreeStore $ts .= new(:field-types(G_TYPE_STRING));
my Gnome::Gtk3::TreeView $tv .= new(:model($ts));

#----------------------- class Task & OrgMode
#use lib ".";
#use Task;

sub to-markup ($text is rw) {    # TODO create a class inheriting of string ?
    $text ~~ s:g/"&"/&amp;/;
    $text ~~ s:g/"<"/&lt;/;
    $text ~~ s:g/">"/&gt;/;
    return $text;
}
class DateOrg {
    has DateTime $.begin    is rw;
    has DateTime $.end      is rw;
    has Str      $.repeater is rw;
    has Str      $.delay    is rw;
    
    method str {
        my Str $result= $.begin.Str;
        $result      ~= "-" ~$.end if $.end;
        $result      ~= " " ~$.repeater if $.repeater;
        $result      ~= " " ~$.delay    if $.delay;
        return $result;
    }
}
class Task {
    has Int      $.level      is rw;
    has Str      $.todo       is rw;
    has Str      $.priority   is rw;
    has Str      $.header     is rw; #  is required
    has DateOrg  $.scheduled  is rw;
    has DateOrg  $.deadline   is rw;
    has Str      @.tags       is rw;
    has Str      @.text       is rw;
    has          @.properties is rw; # array, not hash to keep order # array, not hash to keep order # array, not hash to keep order
    has Task     @.tasks      is rw;

    method display-header {
        my $display;
        my $header=to-markup($.header);
        if $presentation {
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

        } else {
            if    ($.level==1) {$display~='<span foreground="blue" size="xx-large"      >'~$header~'</span>'}
            elsif ($.level==2) {$display~='<span foreground="deepskyblue" size="x-large">'~$header~'</span>'}
            else               {$display~='<span foreground="black" size="x-large"      >'~$header~'</span>'}
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
    method to_text() {
        #say $j++,"-" x $.level," ",$.header," ";
        my $orgmode="";
        if $.level>0 {  # skip for the primary task $om
            $orgmode~="*" x $.level~" ";
            $orgmode~=$.todo~" " if $.todo;
            $orgmode~="\["~$.priority~"\] " if $.priority;
            $orgmode~=$.header;
            $orgmode~=" :" ~ join(':',$.tags.Array) ~ ':' if $.tags; # TODO why it's necessary to write .Array ?
            $orgmode~="\n";
        }
        if ($.scheduled) {
            $orgmode~="SCHEDULED: <"~$.scheduled.str~">\n";
        }
        if ($.deadline) {
            $orgmode~="DEADLINE: <"~$.deadline.str~">\n";
        }
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
                $orgmode~=$_.to_text;
            }
        }
        #$j--;
        return $orgmode;
    }
    method scheduled-today {
        say "ind : ",$.header, $.scheduled if $.scheduled && $.scheduled.begin eq $d-now;
        if $.tasks {
            for $.tasks.Array {
                $_.scheduled-today();
            }
        }
    }
}
class GtkTask is Task {
    has Gnome::Gtk3::TreeIter $.iter is rw;

    method iter-get-indices { # find indices IN treestore, not tasks
        if $.iter.defined && $.iter.is-valid {
            return  $ts.get-path($.iter).get-indices
        }
        return;
    }
    method is-my-iter($iter) {
        # $_.iter ne $iter # TODO doesn't work, why ?
        return $.iter && $.iter.is-valid && $.iter-get-indices eq $ts.get-path($iter).get-indices;
    }
    method delete-iter() {
        $.iter .=new;
        if $.tasks {
            for $.tasks.Array {
                $_.delete-iter();
            }
        }
    }
    my $lvl=0;
    method inspect() {
        say "ind : ",$.iter-get-indices, " lvl ",$lvl," ",$.header, " level ",$.level;
        if $.tasks {
            for $.tasks.Array {
                $lvl++;
                $_.inspect();
                $lvl--;
            }
        }
    }
    method is-child-prior-A() {
        return True if $.priority && $.priority eq "#A";
        if $.tasks {
            for $.tasks.Array {
                $lvl++;
                return True if $_.is-child-prior-A();
                $lvl--;
            }
        }
        return False;
    }
    method search-task-from($iter) {
        if $.is-my-iter($iter) {
            return self;
        } else {
            if $.tasks {
                for $.tasks.Array {
                    my $find=$_.search-task-from($iter);
                    return $find if $find;
                }
            }
        }
        return;                 # if click on text 
    }
    method delete-branch($iter) {
        $change=1;
        my $task=$.search-task-from($iter);
        my $task-parent=$.parent($task);
        $task-parent.tasks = grep { !$_.is-my-iter($iter) }, $task-parent.tasks;
        $ts.gtk-tree-store-remove($iter);
    }
    method expand-row {
        $tv.expand-row($ts.get-path($.iter),1);
    }
    method create_task(Gnome::Gtk3::TreeIter $iter?,$pos = -1) {
        my $level=$display-branch-task.level;
        my Gnome::Gtk3::TreeIter $iter_task;
        if $.level==$level || (
            !($.todo && $.todo eq 'DONE' && $no-done) 
            && (!$prior-A ||  $.is-child-prior-A) 
        ) {
            my Gnome::Gtk3::TreeIter $parent-iter;
            if ($.level>$level) {
                if ($.level==$level+1) {
                    my Gnome::Gtk3::TreePath $tp .= new(:string($i++.Str));
                    $parent-iter = $ts.get-iter($tp);
                } else {
                    $parent-iter = $iter;
                }
                $iter_task = $ts.insert-with-values($parent-iter, $pos, 0, $.display-header);
                if $.text {
                    for $.text.Array {
                        my Gnome::Gtk3::TreeIter $iter_t2 = $ts.insert-with-values($iter_task, -1, 0, to-markup($_)) 
                    }
                }
                $.iter=$iter_task;
            }
            if $.tasks {
                for $.tasks.Array {
                    $_.create_task($iter_task);
                }
            }
        }
    }
    method parent($task) {
        my @path= $ts.get-path($task.iter).get-indices.Array;
        my @path-parent=@path;
        pop(@path-parent);
        return self if !@path-parent;   # level 0
        my $iter-parent=get-iter-from-path(@path-parent);
        return $.search-task-from($iter-parent);
    }
    method search-indice($task) { # it's the indice on my tree, not Gtk::Tree # TODO to improve
        my $i=-1;
        if $.parent($task).tasks {
            for $.parent($task).tasks.Array {
                $i++;
                return $i if $_.is-my-iter($task.iter);
            }
        }
        return -1;
    }
    method swap($task1,$task2) {
        my $t_parent=$.parent($task1);
        my $line1=$.search-indice($task1);
        my $line2=$.search-indice($task2);
        $t_parent.tasks[$line1,$line2] = $t_parent.tasks[$line2,$line1];
    }
    method default {
        my GtkTask $task.=new(:header("In the beginning was the Task"),:todo('TODO'),:level(1));
        $task.create_task();
        $.tasks.push($task);
    }
    method reconstruct_tree { # not good practice, not abuse 
        $i=0;
        $ts.clear();
        $.delete-iter();
        $.create_task;
    }
}
my GtkTask $om;

sub date-from-dateorg($do) {
    my DateOrg $dateorg;
    if $do[1]{'time'}{'hour'} {
        $dateorg=DateOrg.new(
             begin => DateTime.new(
                year   => $do{'year'},
                month  => $do{'month'},
                day    => $do{'day'},
                hour   => $do[1]{'time'}{'hour'},
                minute => $do[1]{'time'}{'minute'},
                formatter => $format-org-date
            )            
        );
    } else {
        $dateorg=DateOrg.new(
             begin => DateTime.new(
                year   => $do{'year'},
                month  => $do{'month'},
                day    => $do{'day'},
                formatter => $format-org-date
            )            
        );
    }
    if $do[1][0]{'time'}{'hour'} {
        $dateorg.end=DateTime.new(
            year   => $do{'year'},
            month  => $do{'month'},
            day    => $do{'day'},
            hour   => $do[1][0]{'time'}{'hour'},
            minute => $do[1][0]{'time'}{'minute'},
            formatter => $format-org-time
        );
    }
    $dateorg.repeater=$do[2]{'repeat'}.Str if $do[2]{'repeat'};
    $dateorg.delay   =$do[3]{'delay'}.Str if $do[3]{'delay'};
    return $dateorg;
}
sub demo_procedural_read($name) { # TODO to remove, improve grammar/AST
    $om .=new(:header($name),:level(0)); # use "header" on level "0" for save the filename
    $display-branch-task=$om;
    my @last=[$om]; # list of last task by level
    my $last=$om;   # last task for 'text'
    my $read-property=False;
    for $name.IO.lines {
        if $_ ~~ /^("*")+" " ((["TODO"|"DONE"])" ")? (\[(\#[A|B|C])\]" ")? (.*?) (" "(\:((\S*?)\:)+))? \s* $/ { # header 
            my $level=$0.elems;
            my GtkTask $task.=new(:header($3.Str),:level($level));
            $task.todo    =$1[0].Str if $1[0];
            $task.priority=$2[0].Str if $2[0];
            $task.tags=split(/\:/,$4[0])[1..^*-1] if $4[0];
            push(@last[$level-1].tasks,$task);
            @last[$level]=$task;
            $last=$task;
        } else {
            if  /^"SCHEDULED: <" <dateorg> ">"$/ {
                $last.scheduled=date-from-dateorg($/{'dateorg'});
            } elsif  /^"DEADLINE: <" <dateorg> ">"$/ {
                $last.deadline=date-from-dateorg($/{'dateorg'});
            } elsif  /^":PROPERTIES:"$/ {
                $read-property = True;
            } elsif /^":END:"$/ {
                $read-property = False;
            } else {
                if $read-property {
                    /":"(.*?)":"" "+(.*)/;
                    $last.properties.push(($0.Str,$1.Str));
                    if $0.Str eq 'presentation' 
                        && $1.Str eq 'False' { # TODO global choice, put in task, inherit for child
                            $presentation=False
                    };
                } else {
                    push($last.text,$_); # text ou instruction précédente mal formatée
                }
            }
        }
    }
#        say $om.tasks;
#        say "after : \n", Dump $om.tasks;
}
#--------------------------- part GTK--------------------------------
my Gnome::Gtk3::Main $m .= new;
my Gnome::Gtk3::MessageDialog $md .=new(:message('Voulez-vous sauvez votre fichier ?'),:buttons(GTK_BUTTONS_YES_NO));
class X {
  method exit-gui ( --> Int ) {
        if $change && $om.header ne "demo.org" {
            if $md.run==-8 {
                save($om.header);
            }
            $md.destroy;
        }
    $m.gtk-main-quit;
    1
  }
}
my Gnome::Gtk3::TreeIter $iter;

my Gnome::GObject::Type $type .= new;
my int32 $menu-shell-gtype = $type.g_type_from_name('GtkMenuShell');

# main window
my Gnome::Gtk3::Window $top-window .= new();
$top-window.set-title('Org-Mode with GTK and raku');
$top-window.set-default-size( 640, 480);

my Gnome::Gtk3::Grid $g .= new();
$top-window.gtk-container-add($g);
sub create-main-menu($title,Gnome::Gtk3::Menu $sub-menu) {
    my Gnome::Gtk3::MenuItem $but-file-menu .= new(:label($title));
    $but-file-menu.set-use-underline(1);
    $but-file-menu.set-submenu($sub-menu);
    return $but-file-menu;
}
my Gnome::Gtk3::MenuBar $menu-bar .= new;
$g.gtk_grid_attach( $menu-bar, 0, 0, 1, 1);
$menu-bar.gtk-menu-shell-append(create-main-menu('_File',make-menubar-list-file()));
$menu-bar.gtk-menu-shell-append(create-main-menu('_Option',make-menubar-list-option()));
$menu-bar.gtk-menu-shell-append(create-main-menu('_Debug',make-menubar-list-debug())) if $debug;
$menu-bar.gtk-menu-shell-append(create-main-menu('_Help',make-menubar-list-help()));

# notebook with tab
my Gnome::Gtk3::Notebook $nb .= new();
$g.gtk-grid-attach( $nb, 0, 1, 4, 1);

# first tab
my Gnome::Gtk3::Label $tab1-label   .= new(:text("Tab 1"));

my Gnome::Gtk3::ScrolledWindow $sw .= new();

$tv.set-hexpand(1);
$tv.set-vexpand(1);
$tv.set-headers-visible(0);
$tv.set-activate-on-single-click(1);
$sw.gtk-container-add($tv);
$nb.append-page($sw,$tab1-label);

my Gnome::Gtk3::Entry $e_add  .= new();
my Gnome::Gtk3::Button $b_add  .= new(:label('Add task'));
my Gnome::Gtk3::Label $l_del  .= new(:text('Click on task to manage'));
$g.gtk-grid-attach( $e_add, 0, 2, 1, 1);
$g.gtk-grid-attach( $b_add, 1, 2, 1, 1);
$g.gtk-grid-attach( $l_del, 2, 2, 1, 1);

my Gnome::Gtk3::TreeViewColumn $tvc .= new();
my Gnome::Gtk3::CellRendererText $crt1 .= new();
$tvc.pack-end( $crt1, 1);
$tvc.add-attribute( $crt1, 'markup', 0);
$tv.append-column($tvc);

#my Gnome::GObject::Value $gv .= new(:init(G_TYPE_INT));
#$gv.set-int(100);
#$crt2.set-property( 'wrap-width', $gv);
#$gv .= new(:init(G_TYPE_ENUM));
#$gv.set-enum('word');
#$crt2.set-property( 'wrap-mode', $gv);
##$crt2.wrap-width=10;

my Gnome::Gtk3::AboutDialog $about .= new;
$about.set-program-name('org-mode-gtk.raku');
$about.set-version('0.1');
$about.set-license-type(GTK_LICENSE_GPL_3_0);
$about.set-website("http://www.barbason.be");
$about.set-website-label("http://www.barbason.be");
$about.set-authors(CArray[Str].new('Alain BarBason'));

my Gnome::Gtk3::Entry $e_add2;
my Gnome::Gtk3::Entry $e_edit;
my Gnome::Gtk3::Entry $e_edit_tags;
my Gnome::Gtk3::Entry $e_edit_text;
my Gnome::Gtk3::Dialog $dialog;
my Gnome::Gtk3::TextView $tev_edit_text;
my Gnome::Gtk3::TextBuffer $text-buffer;

my X $x .= new;
$top-window.register-signal( $x, 'exit-gui', 'destroy');
sub  add2-branch($iter-parent) {
    if $e_add2.get-text {
        $change=1;
        my $task-parent=$om.search-task-from($iter-parent);
        my GtkTask $task.=new(:header($e_add2.get-text),:todo("TODO"),:level($task-parent.level+1));
        $e_add2.set-text("");
        $task.create_task($iter-parent);
        push($task-parent.tasks,$task);
        $task-parent.expand-row();
    }
}
sub update-text($iter,$new-text) {
    my $task=$om.search-task-from($iter);
    $task.text=$new-text.split(/\n/);
    my $iter_child=$ts.iter-children($iter);
    # remove all lines "text"
    while $iter_child.is-valid && !$om.search-task-from($iter_child) { # if no task associate to a task, it's a "text"
        $ts.gtk-tree-store-remove($iter_child);
        $iter_child=$ts.iter-children($iter);
    }
    if $task.text {
        for $task.text.Array.reverse {
            my Gnome::Gtk3::TreeIter $iter_t2 = $ts.insert-with-values($iter, 0, 0, to-markup($_)) 
        }
        $task.expand-row();
    }
}
sub get-iter-from-path(@path) {
    my Gnome::Gtk3::TreePath $tp .= new(:indices(@path));
    return $ts.get-iter($tp);
}
sub brother($iter,$inc) {
    my @path2= $ts.get-path($iter).get-indices.Array;
    @path2[*-1]=@path2[*-1].Int;
    @path2[*-1]+=$inc;
    my Gnome::Gtk3::TreePath $tp .= new(:indices(@path2));
    return  $ts.get-iter($tp);
}
class AppSignalHandlers {
    has Gnome::Gtk3::Window $!top-window;
    submethod BUILD ( Gnome::Gtk3::Window :$!top-window ) { }
    multi method create-button($label,$method,$iter?,$inc?) {
        my Gnome::Gtk3::Button $b  .= new(:label($label));
        $b.register-signal(self, $method, 'clicked',:iter($iter),:inc($inc));
        return $b;
    }
    multi method create-button($label,$method,Gnome::Gtk3::Entry $entry) {
        my Gnome::Gtk3::Button $b  .= new(:label($label));
        $b.register-signal(self, $method, 'clicked',:edit($entry));
        return $b;
    }
    multi method create-button($label,$method,Str $text) {
        my Gnome::Gtk3::Button $b  .= new(:label($label));
        $b.register-signal(self, $method, 'clicked',:edit($text));
        return $b;
    }
    method create-check($method,Gnome::Gtk3::Entry $entry) {
        my Gnome::Gtk3::CheckButton $cb .= new();
        $cb.register-signal( self, $method, 'toggled',:edit($entry));
        return $cb;
    }
    method go-to-link ( :$edit ) {
#        my $proc = run '/opt/firefox/firefox', '--new-tab', $edit;
        shell "/opt/firefox/firefox --new-tab $edit";
        1
    }
    method time ( :$widget, :$edit ) {
        note " button  ",
         $widget.get-active.Bool ;
    }
    method today (:$edit) {
        my $ds=$d-now.Str.substr(0,14);
        my $ori=$edit.get-text;
        $ori ~~ s/^.**14/$ds/; # TODO not very good, but work
        $edit.set-text($ori); 
        1
    }
    method tomorrow (:$edit) {
        my $ds=$d-now.later(days => 1).Str.substr(0,14);
        my $ori=$edit.get-text;
        $ori ~~ s/^.**14/$ds/; # TODO not very good, but work
        $edit.set-text($ori); 
        1
    }
    method repeat-i (:$widget, :$edit, :$cbt) {
        $edit.get-text  ~~ /<dateorg>/;
        my DateOrg $d=date-from-dateorg($/{'dateorg'});
        if $widget.get-active-text ne "0" {
            $d.repeater="+"~$widget.get-active-text~$cbt.get-active-text;
        } else {
            $d.repeater="";
        }
        $edit.set-text($d.str); 
        1
    }
    method repeat-w (:$widget, :$edit, :$cbt) {
        $edit.get-text  ~~ /<dateorg>/;
        my DateOrg $d=date-from-dateorg($/{'dateorg'});
        if $cbt.get-active-text ne "0" {
            $d.repeater="+"~$cbt.get-active-text~$widget.get-active-text;
        } else {
            $d.repeater="";
        }
        $edit.set-text($d.str); 
        1
    }
    method delay-i (:$widget, :$edit, :$cbt) {
        $edit.get-text  ~~ /<dateorg>/;
        my DateOrg $d=date-from-dateorg($/{'dateorg'});
        if $widget.get-active-text ne "0" {
            $d.delay="-"~$widget.get-active-text~$cbt.get-active-text;
        } else {
            $d.delay="";
        }
        $edit.set-text($d.str); 
        1
    }
    method delay-w (:$widget, :$edit, :$cbt) {
        $edit.get-text  ~~ /<dateorg>/;
        my DateOrg $d=date-from-dateorg($/{'dateorg'});
        if $cbt.get-active-text ne "0" {
            $d.delay="-"~$cbt.get-active-text~$widget.get-active-text;
        } else {
            $d.delay="";
        }
        $edit.set-text($d.str); 
        1
    }
    method manage-date (DateOrg $date is rw) {
#say $date.begin;
        my Gnome::Gtk3::Dialog $dialog2 .= new(
            :title("Scheduling"), 
            :parent($!top-window),
            :flags(GTK_DIALOG_DESTROY_WITH_PARENT),
            :button-spec( [
                "_Ok", GTK_RESPONSE_OK,     # TODO rajouter un "delete"
                "_Cancel", GTK_RESPONSE_CANCEL,
            ] )
        );
        my Gnome::Gtk3::Box $content-area .= new(:native-object($dialog2.get-content-area));

        # entry
        my Gnome::Gtk3::Entry $e_edit-d .= new();
        $e_edit-d.set-text($date??$date.str!!$d-now.Str);
        $content-area.gtk_container_add($e_edit-d);

        # 3 button
        my Gnome::Gtk3::Grid $g3 .= new();
        $content-area.gtk_container_add($g3);

        $g3.gtk-grid-attach( $.create-button('Today','today',$e_edit-d),            0, 0, 1, 1);
        $g3.gtk-grid-attach( $.create-button('Tomorrow','tomorrow',$e_edit-d),      1, 0, 1, 1);
#        $g3.gtk-grid-attach( $.create-button('Next Saturday','next-sat',$e_edit-d), 2, 0, 1, 1);

        # Time
        my Gnome::Gtk3::Grid $gt .= new();
        $content-area.gtk_container_add($gt);

#        $gt.gtk-grid-attach( Gnome::Gtk3::Label.new(:text('Time')),            0, 0, 1, 1);
#        $gt.gtk-grid-attach( $.create-button('Time','time',$e_edit-d),         0, 1, 1, 1);
#        $gt.gtk-grid-attach( $.create-check('time',$e_edit-d),                 1, 1, 1, 1);

#        $gt.gtk-grid-attach( Gnome::Gtk3::Label.new(:text('End time')),        2, 0, 1, 1);
#        $gt.gtk-grid-attach( $.create-button('End time','end-time',$e_edit-d), 2, 1, 1, 1);
#        $gt.gtk-grid-attach( $.create-check('end-time',$e_edit-d),             3, 1, 1, 1);

        $gt.gtk-grid-attach( Gnome::Gtk3::Label.new(:text('Repeat')),          0, 2, 1, 1);
        my Gnome::Gtk3::ComboBoxText $cbt-int .=new();
        $cbt-int.append-text("$_") for 0..10;
        $cbt-int.set-active(0);
        $gt.gtk-grid-attach( $cbt-int,                                         0, 3, 1, 1);
        my Gnome::Gtk3::ComboBoxText $cbt .=new();
        $cbt.append-text($_) for <d w m y>;
        $cbt.set-active(1);
        $gt.gtk-grid-attach( $cbt,                                             1, 3, 1, 1);
        $cbt-int.register-signal(self, 'repeat-i', 'changed',:edit($e_edit-d),:cbt($cbt));
        $cbt.register-signal(self, 'repeat-w', 'changed',:edit($e_edit-d),:cbt($cbt-int));

        $gt.gtk-grid-attach( Gnome::Gtk3::Label.new(:text('Delay')),           0, 4, 1, 1);
#        $gt.gtk-grid-attach( $.create-button('Delay','delay',$e_edit-d),       0, 5, 1, 1);
#        $gt.gtk-grid-attach( $.create-check('delay',$e_edit-d),                1, 5, 1, 1);

        my Gnome::Gtk3::ComboBoxText $cbt2-int .=new();
        $cbt2-int.append-text("$_") for 0..10;
        $cbt2-int.set-active(0);
        $gt.gtk-grid-attach( $cbt2-int,                                         0, 5, 1, 1);
        my Gnome::Gtk3::ComboBoxText $cbt2 .=new();
        $cbt2.append-text($_) for <d w m y>;
        $cbt2.set-active(1);
        $gt.gtk-grid-attach( $cbt2,                                             1, 5, 1, 1);
        $cbt2-int.register-signal(self, 'delay-i', 'changed',:edit($e_edit-d),:cbt($cbt2));
        $cbt2.register-signal(self, 'delay-w', 'changed',:edit($e_edit-d),:cbt($cbt2-int));

        $dialog2.show-all;
        my $response = $dialog2.gtk-dialog-run;
        if $response ~~ GTK_RESPONSE_OK {
            my $ds=$e_edit-d.get-text();  # date string
#say "resp : ",$ds;
            if $ds ~~ /<dateorg>/ {
                $date=date-from-dateorg($/{'dateorg'});
#say "date : ",$date;
            } else {
                say "erreur de format";
            }
        }
        $dialog2.gtk_widget_destroy;
        return $date;
    }
    method file-new ( --> Int ) {
        if $change && $om.header ne "demo.org" {
            if $md.run==-8 {
                save($om.header);
            }
            $md.destroy;
        }
        $change=0;
        $om.header='';
        $display-branch-task=$om;
        $top-window.set-title('Org-Mode with GTK and raku');
        $ts.clear();
        $om.tasks=[]; 
        $om.text=[]; 
        $om.default;
        1
    }
    method file-save( ) {
        $om.header ?? save($om.header) !! self.file-save-as();
    }
    method file-save-as( ) {
        my Gnome::Gtk3::FileChooserDialog $dialog .= new(
            :title("Open File"), 
            #:parent($!top-window),    # TODO BUG Cannot look up attributes in a AppSignalHandlers type object
            :action(GTK_FILE_CHOOSER_ACTION_SAVE),
            :button-spec( [
#                "_Ok", GTK_RESPONSE_OK,
                "_Cancel", GTK_RESPONSE_CANCEL,
                "_Open", GTK_RESPONSE_ACCEPT
            ] )
        );
        my $response = $dialog.gtk-dialog-run;
        if $response ~~ GTK_RESPONSE_ACCEPT {
            $om.header = $dialog.get-filename;
            $top-window.set-title('Org-Mode with GTK and raku : ' ~ split(/\//,$om.header).Array.pop) if $om.header;
            save($om.header) if $om.header;
        }
        $dialog.gtk-widget-hide; # TODO destroy ?
        1
    }
    method file-save-test( ) {
        save("test.org");
        run 'cat','test.org';
        say "\n"; # yes, 2 lines.
    }
    method file-open-tab ( --> Int ) {
        my Gnome::Gtk3::Label $tab2-label   .= new(:text("Tab 2"));
        my Gnome::Gtk3::Label $tab2-content .= new(:text("It's the second tab"));
        $nb.append-page($tab2-content,$tab2-label);
        $top-window.show-all;
        1
    }
    method file-open ( --> Int ) {
        if $change && $om.header ne "demo.org" {
            if $md.run==-8 {
                save($om.header);
            }
            $md.destroy;
        }
        my Gnome::Gtk3::FileChooserDialog $dialog .= new(
            :title("Open File"), 
            #:parent($!top-window),    # TODO BUG Cannot look up attributes in a AppSignalHandlers type object
            :action(GTK_FILE_CHOOSER_ACTION_SAVE),
            :button-spec( [
#                "_Ok", GTK_RESPONSE_OK,
                "_Cancel", GTK_RESPONSE_CANCEL,
                "_Open", GTK_RESPONSE_ACCEPT
            ] )
        );
        my $response = $dialog.gtk-dialog-run;
        if $response ~~ GTK_RESPONSE_ACCEPT {
            $ts.clear();
            $om.tasks=[]; 
            $om.text=[]; 
            $om.properties=(); # TODO use undefined ?
            $presentation=True;
            $om.header = $dialog.get-filename;
            $top-window.set-title('Org-Mode with GTK and raku : ' ~ split(/\//,$om.header).Array.pop) if $om.header;
            open-file($om.header) if $om.header;
        }
        $dialog.gtk-widget-hide;
        1
    }
    method file-quit( ) {
        if $change && $om.header ne "demo.org" {
            if $md.run==-8 {
                save($om.header);
            }
            $md.destroy;
        }
        $m.gtk-main-quit;
    }
    method debug-inspect( ) {
        $om.inspect();
    }
    method option-presentation( ) {
        $presentation=!$presentation;
        $display-branch-task.reconstruct_tree();
        1
    }
    method option-no-done( ) {
        $no-done=!$no-done;
        $display-branch-task.reconstruct_tree();
        1
    }
    method option-prior-A( ) {
        $prior-A=!$prior-A;
        $display-branch-task.reconstruct_tree();
        1
    }
    method option-rebase( ) {
        $display-branch-task=$om;
        $display-branch-task.reconstruct_tree();
        1
    }
    method help-about( ) {
        $about.gtk-dialog-run;
        $about.gtk-widget-hide;
    }
    method add-button-click ( ) {
        if $e_add.get-text {
            $change=1;
            my GtkTask $task.=new(:header($e_add.get-text),:todo('TODO'),:level($display-branch-task.level+1));
            $e_add.set-text("");
            $task.create_task();
            $display-branch-task.tasks.push($task);
        }
        1
    }
    method add2-button-click ( :$iter --> Int ) {
        add2-branch($iter);
        1
    }
    method edit-text-button-click ( :$iter ) {
        $change=1;
        my Gnome::Gtk3::TextIter $start = $text-buffer.get-start-iter;
        my Gnome::Gtk3::TextIter $end = $text-buffer.get-end-iter;
        my $new-text=$text-buffer.get-text( $start, $end, 0);
        update-text($iter,$new-text);
        1
    }
    method move-right-button-click ( :$iter ) {
        my @path= $ts.get-path($iter).get-indices.Array;
        return if @path[*-1] eq "0"; # first task doesn't go to left
        my $task=$om.search-task-from($iter);
        my @path-parent=@path;
        @path-parent[*-1]--;
        my $iter-parent=get-iter-from-path(@path-parent);
        my $task-parent=$om.search-task-from($iter-parent);
        $om.delete-branch($iter); 
        $task.level-move(1);
        push($task-parent.tasks,$task); 
        $task.create_task($iter-parent);
        $task-parent.expand-row;
        $dialog.gtk_widget_destroy; # remove when level 3
        1
    }
    method move-left-button-click ( :$iter ) {
        my $task=$om.search-task-from($iter);
        return if $task.level <= 1; # level 0 and 1 don't go to left
        my $task-parent=$om.parent($task);
        my @path-parent= $ts.get-path($task-parent.iter).get-indices.Array;
        my $task-grand-parent=$om.parent($task-parent);
        $task.level-move(-1);
        $om.delete-branch($iter); 
        my @tasks;
        for $task-grand-parent.tasks.Array {
            if $_ eq $task-parent {
                push(@tasks,$_);
                push(@tasks,$task);
            } else {
                push(@tasks,$_);
            } 
        }
        $task-grand-parent.tasks=@tasks;
        $task.create_task($task-grand-parent.iter,@path-parent[*-1]+1);
        $task.expand-row;
        $dialog.gtk_widget_destroy; # remove when level 3
        1
    }
    method move-up-down-button-click ( :$iter, :$inc  --> Int ) {
        my @path= $ts.get-path($iter).get-indices.Array;
        if !(@path[*-1] eq "0" && $inc==-1) {     # if is not the first child in treestore (because if have DONE hide) for up
            my $iter2=brother($iter,$inc);
            if $iter2.is-valid {   # if not, it's the last child
                $change=1;
                my $task=$om.search-task-from($iter);
                my $task2=$om.search-task-from($iter2);
                $ts.swap($iter,$iter2);
                $om.swap($task,$task2);
            }
        }
        1
    }
    method scheduled ( :$iter ) {
        my $task=$om.search-task-from($iter);
        $task.scheduled=self.manage-date($task.scheduled);
        1
    }
    method deadline ( :$iter ) {
        my $task=$om.search-task-from($iter);
        $task.deadline=self.manage-date($task.deadline);
        1
    }
    method edit-button-click ( :$iter ) {
        $change=1;
        my $task=$om.search-task-from($iter);
        $task.header=$e_edit.get-text;
        $ts.set_value( $iter, 0,$om.search-task-from($iter).display-header);
        1
    }
    method edit-tags-button-click ( :$iter ) {
        $change=1;
        my $task=$om.search-task-from($iter);
        $task.tags=split(/" "/,$e_edit_tags.get-text);
        $ts.set_value( $iter, 0,$om.search-task-from($iter).display-header);
        1
    }
    method prior-button-click ( :$iter,:$prior --> Int ) {
        my GtkTask $task;
        if ($toggle_rb_pr) {  # see definition 
            $change=1;
            my $task=$om.search-task-from($iter);
            $task.priority=$prior??"#"~$prior!!"";
            $ts.set_value( $iter, 0,$om.search-task-from($iter).display-header);
        }
        $toggle_rb_pr=!$toggle_rb_pr;
        1
    }
    method todo-button-click ( :$iter,:$todo --> Int ) {
        my GtkTask $task;
        if ($toggle_rb) {  # see definition 
            $change=1;
            my $task=$om.search-task-from($iter);
            $task.todo=$todo;
            $ts.set_value( $iter, 0,$om.search-task-from($iter).display-header);
            my Gnome::Gtk3::TextIter $start = $text-buffer.get-start-iter;
            my Gnome::Gtk3::TextIter $end = $text-buffer.get-end-iter;
            my $text=$text-buffer.get-text( $start, $end, 0);
            if $todo eq 'DONE' {
                if $text.encode.elems>0 {
                    update-text($iter,"CLOSED: [$now]\n"~$text);
                } else {
                    update-text($iter,"CLOSED: [$now]");
                }
            } elsif $todo eq 'TODO' && $text~~/^\s*CLOSED/ {
                $text~~s/^\s*CLOSED.*?\]\n?//;
                update-text($iter,$text);
            }
            if $task.text { # update display text
                my $text=$task.text.join("\n");
                $text-buffer.set-text($text);
            }
        }
        $toggle_rb=!$toggle_rb;
        1
    }
    method pop-button-click ( :$iter --> Int ) { # populate a task with TODO comment
        if $om.search-task-from($iter) {      # if not, it's a text not now editable 
            my $task=$om.search-task-from($iter);
            my $i=0;
            if $task.header.IO.e {
                for $task.header.IO.lines {
                    $i++;
                    if !($_ ~~ /NOTODO/) && $_ ~~ /^(.*?)" # TODO "(.*)$/ {     # NOTODO
                        my GtkTask $task-todo.=new(:header($1.Str),:todo('TODO'),:level($task.level+1)); # TODO create a sub with these 3 lines but I have a problem with parameters
                        $0 ~~ /^" "*(.*)/;
                        push($task-todo.text,$i ~ " " ~ $0.Str);
                        $task-todo.create_task($iter);
                        $task.tasks.push($task-todo);
                    }
                }
            }
        $dialog.gtk_widget_destroy;
        1
        }
    }
    method del-button-click ( :$iter --> Int ) {
        $om.delete-branch($iter);
        $dialog.gtk_widget_destroy;
        1
    }
    method del-children-button-click ( :$iter --> Int ) {
        if $om.search-task-from($iter) {      # if not, it's a text not now editable 
            my $task=$om.search-task-from($iter);
            if $task.tasks {
                for $task.tasks.Array {
                    $om.delete-branch($_.iter);
                }
            }
        }
        $dialog.gtk_widget_destroy;
        1
    }
    method display-branch ( :$iter --> Int ) {
        $display-branch-task=$om.search-task-from($iter);
        $i=0;
        $ts.clear();
        $om.delete-iter();
        $display-branch-task.create_task();
        $dialog.gtk_widget_destroy;
        1
    }
    method tv-button-click (N-GtkTreePath $path, N-GObject $column ) {
        my Gnome::Gtk3::TreePath $tree-path .= new(:native-object($path));
        my Gnome::Gtk3::TreeIter $iter = $ts.tree-model-get-iter($tree-path);

        # Dialog to manage task
        $dialog .= new(   # TODO global variable is necessary ?
            :title("Manage task"), 
            :parent($!top-window),
            :flags(GTK_DIALOG_DESTROY_WITH_PARENT),
            :button-spec( "Cancel", GTK_RESPONSE_NONE)
        );
        my Gnome::Gtk3::Box $content-area .= new(:native-object($dialog.get-content-area));

        # to edit task
        if $om.search-task-from($iter) {      # if not, it's a text not now editable 
            my $task=$om.search-task-from($iter);

            $content-area.gtk_container_add($.create-button('>','move-right-button-click',$iter));
            $content-area.gtk_container_add($.create-button('<','move-left-button-click',$iter));
            $content-area.gtk_container_add($.create-button('^','move-up-down-button-click',$iter,-1));
            $content-area.gtk_container_add($.create-button('v','move-up-down-button-click',$iter,1));

            $content-area.gtk_container_add($.create-button('Scheduling','scheduled',$iter,1));
            $content-area.gtk_container_add($.create-button('Deadline','deadline',$iter,1));

            # To edit task
            $e_edit  .= new();
            $e_edit.set-text($task.header);
            $content-area.gtk_container_add($e_edit);
            $content-area.gtk_container_add($.create-button('Update task','edit-button-click',$iter));
            
            # To edit tags
            $e_edit_tags  .= new();
            $e_edit_tags.set-text(join(" ",$task.tags));
            $content-area.gtk_container_add($e_edit_tags);
            $content-area.gtk_container_add($.create-button('Update tags','edit-tags-button-click',$iter));
            
            # To edit text
            $tev_edit_text .= new;
            $text-buffer .= new(:native-object($tev_edit_text.get-buffer));
            if $task.text {
                my $text=$task.text.join("\n");
                $text-buffer.set-text($text);
            }
            $content-area.gtk_container_add($tev_edit_text);
            $content-area.gtk_container_add($.create-button('Update text','edit-text-button-click',$iter));
            if $task.text {
                my $text=$task.text.join("\n");
                $text ~~ /(http:..\S*)/;
                $content-area.gtk_container_add($.create-button('Goto to link','go-to-link',$0.Str)) if $0;
            }
            
            # To manage priority A,B,C.
            $task=$om.search-task-from($iter);
            my Gnome::Gtk3::Grid $g_prio .= new;
            $content-area.gtk_container_add($g_prio);
            my Gnome::Gtk3::RadioButton $rb_pr1 .= new(:label('-'));
            my Gnome::Gtk3::RadioButton $rb_pr2 .= new( :group-from($rb_pr1), :label('A'));
            my Gnome::Gtk3::RadioButton $rb_pr3 .= new( :group-from($rb_pr1), :label('B'));
            my Gnome::Gtk3::RadioButton $rb_pr4 .= new( :group-from($rb_pr1), :label('C'));
            if    !$task.priority          { $rb_pr1.set-active(1);}
            elsif $task.priority eq '#A' { $rb_pr2.set-active(1);}
            elsif $task.priority eq '#B' { $rb_pr3.set-active(1);} 
            elsif $task.priority eq '#C' { $rb_pr4.set-active(1);} 
            $g_prio.gtk-grid-attach( $rb_pr1, 0, 0, 1, 1);
            $g_prio.gtk-grid-attach( $rb_pr2, 1, 0, 1, 1);
            $g_prio.gtk-grid-attach( $rb_pr3, 2, 0, 1, 1);
            $g_prio.gtk-grid-attach( $rb_pr4, 3, 0, 1, 1);
            $rb_pr1.register-signal(self, 'prior-button-click', 'clicked',:iter($iter),:prior(""));
            $rb_pr2.register-signal(self, 'prior-button-click', 'clicked',:iter($iter),:prior("A"));
            $rb_pr3.register-signal(self, 'prior-button-click', 'clicked',:iter($iter),:prior("B"));
            $rb_pr4.register-signal(self, 'prior-button-click', 'clicked',:iter($iter),:prior("C"));

            # To manage TODO/DONE
            $task=$om.search-task-from($iter);
            my Gnome::Gtk3::Grid $g_todo .= new;
            $content-area.gtk_container_add($g_todo);
            my Gnome::Gtk3::RadioButton $rb_td1 .= new(:label('-'));
            my Gnome::Gtk3::RadioButton $rb_td2 .= new( :group-from($rb_td1), :label('TODO'));
            my Gnome::Gtk3::RadioButton $rb_td3 .= new( :group-from($rb_td1), :label('DONE'));
            if    !$task.todo          { $rb_td1.set-active(1);}
            elsif $task.todo eq 'TODO' { $rb_td2.set-active(1);}
            elsif $task.todo eq 'DONE' { $rb_td3.set-active(1);} 
            $g_todo.gtk-grid-attach( $rb_td1, 0, 0, 1, 1);
            $g_todo.gtk-grid-attach( $rb_td2, 1, 0, 1, 1);
            $g_todo.gtk-grid-attach( $rb_td3, 2, 0, 1, 1);
            $rb_td1.register-signal(self, 'todo-button-click', 'clicked',:iter($iter),:todo(""));
            $rb_td2.register-signal(self, 'todo-button-click', 'clicked',:iter($iter),:todo("TODO"));
            $rb_td3.register-signal(self, 'todo-button-click', 'clicked',:iter($iter),:todo("DONE"));

            # To add a sub-task
            $e_add2  .= new();
            $content-area.gtk_container_add($e_add2);
            $content-area.gtk_container_add($.create-button('Add sub-task','add2-button-click',$iter));
            
            $content-area.gtk_container_add($.create-button('Delete task (and sub-tasks)','del-button-click',$iter));
            $content-area.gtk_container_add($.create-button('Delete sub-tasks','del-children-button-click',$iter));
            $content-area.gtk_container_add($.create-button('Display just this branch','display-branch',$iter));
            $content-area.gtk_container_add($.create-button('Populate with TODO from file','pop-button-click',$iter));

            # Show the dialog.
            $dialog.show-all;
            $dialog.gtk-dialog-run;
            $dialog.gtk_widget_destroy;
        } else {  # text
            # manage via dialog task
        }
        1
    }
}
my AppSignalHandlers $ash .= new(:$top-window);
$b_add.register-signal( $ash, 'add-button-click', 'clicked');
$tv.register-signal( $ash, 'tv-button-click', 'row-activated');
sub create-sub-menu($menu,$name,$ash,$method) {
    my Gnome::Gtk3::MenuItem $menu-item .= new(:label($name));
    $menu-item.set-use-underline(1);
    $menu.gtk-menu-shell-append($menu-item);
    $menu-item.register-signal( $ash, $method, 'activate');
} 
sub make-menubar-list-file( ) {
    my Gnome::Gtk3::Menu $menu .= new;
    create-sub-menu($menu,"_New",$ash,'file-new');
    create-sub-menu($menu,"_Save",$ash,'file-save');
    create-sub-menu($menu,"Save _as ...",$ash,'file-save-as');
    create-sub-menu($menu,"_Open File ...",$ash,'file-open');
    create-sub-menu($menu,"Open File _in a new tab ...",$ash,'file-open-tab');
    create-sub-menu($menu,"Save to _test",$ash,'file-save-test');
    create-sub-menu($menu,"_Quit",$ash,'file-quit');
    $menu
}
sub make-menubar-list-option() {
    my Gnome::Gtk3::Menu $menu .= new;
    create-sub-menu($menu,"_Presentation",$ash,'option-presentation');
    create-sub-menu($menu,"_No DONE",$ash,'option-no-done');
    create-sub-menu($menu,"#_A",$ash,'option-prior-A');
    create-sub-menu($menu,"_Top of tree",$ash,'option-rebase');
    $menu
}
sub make-menubar-list-debug() {
    my Gnome::Gtk3::Menu $menu .= new;
    create-sub-menu($menu,"_Inspect",$ash,'debug-inspect');
    $menu
}
sub make-menubar-list-help ( ) {
    my Gnome::Gtk3::Menu $menu .= new;
    create-sub-menu($menu,"_About",$ash,'help-about');
    $menu
}
#-----------------------------------sub-------------------------------
sub verifiy-read($name) {
    save("test.org");
    my $proc =     run 'diff','-Z',"$name",'test.org';
    say "Input file and save file are different. Problem with syntax or bug.
        You can view the file, but it's may be wrong.
        Don't save." if $proc.exitcode; 
}
sub open-file($name) {
    spurt $name~".bak",slurp $name; # fast backup
    demo_procedural_read($name);
    $om.scheduled-today();
    verifiy-read($name);
    $display-branch-task=$om;
    $om.create_task;
}
sub save($name) {
    $change=0;
	spurt $name, $om.to_text;
}
#-----------------------------------main--------------------------------
sub MAIN($arg = '') {
    $top-window.show-all;
    my $filename=$arg;
    $top-window.set-title('Org-Mode with GTK and raku : ' ~ split(/\//,$filename).Array.pop) if $filename; # TODO  improve code
    if $filename {
        open-file($filename);
    } else {
        $om .=new(:level(0)); 
        $display-branch-task=$om;
        $om.default;
    }
    $m.gtk-main;
}
