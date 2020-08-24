use Task;

class File {
    has Int                         $.change        is rw =0;           # for ask question to save when quit
    has                             $.no-done       is rw =True;       # display with no DONE
    has                             $.prior-A       is rw =False;      # display #A          
    has                             $.prior-B       is rw =False;      # display #B          
    has                             $.prior-C       is rw =False;      # display #C          
}

