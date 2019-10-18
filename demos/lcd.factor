USING: sequences kernel math io ;

: lcd-digit ( digit row -- str )
    {
        "  _       _  _       _   _   _   _   _  "
        " | |  |   _| _| |_| |_  |_    | |_| |_| "     
        " |_|  |  |_  _|   |  _| |_|   | |_|   | "
    } nth >r 4 * dup 4 + r> subseq ;

: lcd-row ( num row -- )
    swap [ CHAR: 0 - swap lcd-digit write ] each-with ;

: lcd ( digit-str -- )
    3 [ lcd-row terpri ] each-with ;

PROVIDE: demos/lcd ;

MAIN: demos/lcd "31337" lcd ;
