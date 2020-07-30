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
sub d-now is export {
    return $d-now.Str;
}
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
sub now is export {
    return $now.Str;
}
my token year   {\d\d\d\d}
my token month  {\d\d}
my token day    {\d\d}
my token wday   {<alpha>+}                     # TODO append boundary check
my token hour   {\d\d}
my token minute {\d\d}
my token time   {<hour>":"<minute>}
my token repeat {(\.?\+\+?)(\d+)(\w+)}         # +, ++, .+
my token delay  {(\-\-?)(\d+)(\w+)}            # -, --
my token dateorg is export { <year>"-"<month>"-"<day>
                (" "<wday>)?                   # TODO change ( by [ ?
                (" "<time>("-"<time>)?)? 
                (" "<repeat>)?
                (" "<delay>)?
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

sub date-from-dateorg($do) is export {
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
