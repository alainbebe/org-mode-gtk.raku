#use Grammar::Tracer;
#use Data::Dump;
use OrgMode::Date;
use Gtk::Task; # TODO no Gtk here :refactoring:0.1:

grammar Content {
    token TOP        { ^ <stars> <keyword>? <priority>? <title> <tags>? \n?  # first line of a task
                            <closed>? <deadline>? <scheduled>?               # second optional line with time
                            <properties>?                                    # optional lines for properties
                            <text>? $                                        # optional lines for text
                     }
    token stars      { "*"+ )> " "};
    token keyword    { ["TODO"|"DONE"] )> " " }                              # TODO add NEXT for compatibility with :Orgzly:
    token priority   { "[#" <( [A|B|C] )> "] " }
    token title      { .*? <?before " :"\S || $$ > };                        # TODO fail if "* blabla :e ",
    token tags       {  " :"(\S+?":")+ }
    token closed     { " "* "CLOSED: [" <dateorg> "]"\n? }                  
    token deadline   { " "* "DEADLINE: <" <dateorg> ">"\n? }                
    token scheduled  { " "* "SCHEDULED: <" <dateorg> ">\n" }
    token properties { ^^ ":PROPERTIES:" \n  <property>+ %% \n ":END:" \n? }
    token property   { ^^ <!before ":END:" $$> ":" <name> ":" \s* <value>?  } # ":name: value" ":name:" (value missing)
    token name       {\w+}
    token value      {<!before ":END:" $$> \N+}
    token text       { .+ };
}

class Content-actions {
    method TOP($/) {
        my Gtk::Task $task.=new( 
            :title($<title>.made), 
            :stars($<stars>.made)
        );
        $task.keyword    =$<keyword>.made     if $<keyword>;
        $task.priority   =$<priority>.made    if $<priority>;
        $task.tags       =$<tags>.made        if $<tags>;
        $task.closed     =$<closed>.made      if $<closed>;
        $task.deadline   =$<deadline>.made    if $<deadline>;
        $task.scheduled  =$<scheduled>.made   if $<scheduled>;
        $task.properties =$<properties>.made  if $<properties>;
        $task.text       =$<text>.made        if $<text> && $<text>.made.chars>0;
        make $task;
    }
    method title($/) {
        make $/.Str.trim-trailing;
    }
    method stars($/) {
        make $/.Str.chars;
    }
    method keyword($/) {
        make $/.Str;
    }
    method priority($/) {
        make $/.Str;
    }
    method tags($/) {
        make split(/\:/,$/.Str)[1..^*-1];              # ":tag1:tag2:" => ("tag1","tag2")
    }
    method closed($/) {
        make date-from-dateorg($/{'dateorg'});
    }
    method deadline($/) {
        make date-from-dateorg($/{'dateorg'});
    }
    method scheduled($/) {
        make date-from-dateorg($/{'dateorg'});
    }
    method name($/) {
        make $/.Str;
    }
    method value($/) {
        make $/.Str;
    }
    method property($/) {
        make ($<name>.made,$<value>.made);
    }
    method properties($/) {
        make $<property>».made;
    }
    method text($/) {
        make chomp($/.Str);   # TODO rewrite to accept one blank line after text
        # TODO text is presently a Str, but before Array of Str (line). Choice the good representation a day :refactoring:O.x:
    }
}

my $stars="";
grammar OrgMode {                                                       # TODO to :translate:
    rule  TOP       { ^ <preface>? <tasks> $ }                          # un fichier org est une preface suivi de taches
    rule  preface   {  .*? <?before ^^"*"> }                            # la préface précède la première tache (commençant par "*")
    rule  tasks     {  <task>+ }                                        # des tâches est un liste de tâche
    token task      { <content> <tasks>? {$stars=$stars.substr(0,*-1)}} # une tache est la tâche elle-meme avec une liste de sous-tache
    rule  content   { ^^                                                
                        ($stars "*"+)" " {$stars=$0}                    # la tache en elle même commence par une ou plusieurs "*"
                        .*?                                             # et tout 
                        <?before ^^"*" || $ >                           # ce qui précède la tache suivante ou la fin du fichier
                    }   
    # TODO on devrait pouvoir intégrer "Grammar Content" ici, mais commment ?, et est-ce nécessaire ?
}
sub analyse-content($content) {
        my Gtk::Task $task=Content.parse($content,:actions(Content-actions)).made;
        return $task;
}
class OrgMode::Actions {
    method TOP($/) {
        my Gtk::Task $task.=new(:stars(0));                    # un fichier est vu comme une tâche de niveau 0
        $task.text = $<preface>.made       if $<preface> && $<preface>.made.chars > 0;
        $task.tasks=$<tasks>.made          if $<tasks>;
        $_.darth-vader=$task               for $task.tasks;  # pour faciliter les déplacements, on intègre le parent aux taches enfants
        make $task;
    }
    method preface($/) {
        make chomp($/.Str);
    }
    method tasks($/) {
        make $<task>».made ;
    }
    method task($/) {
        my Gtk::Task $task;
        $task=$<content>.made;
        $task.tasks=$<tasks>.made           if $<tasks>.made;
        $_.darth-vader=$task                for $task.tasks;
        make $task;
    }
    method content($/) {
        my Gtk::Task $task = analyse-content($/.Str);                             # Works :-)
#       my Gtk::Task $task=Content.parse($/.Str,:actions(Content-actions)).made;  # TODO Doesn't work. Why ?
                                                                        # Error : Cannot assign to a readonly variable or a value
        make $task;
    }
}
