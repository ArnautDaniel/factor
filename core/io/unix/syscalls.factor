! Copyright (C) 2005, 2007 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
IN: unix-internals
USING: alien errors kernel math namespaces ;

! Alien wrappers for various Unix libc functions.

LIBRARY: factor
FUNCTION: int err_no ( ) ;

LIBRARY: libc
FUNCTION: char* strerror ( int errno ) ;
FUNCTION: int open ( char* path, int flags, int prot ) ;
FUNCTION: void close ( int fd ) ;
FUNCTION: int fcntl ( int fd, int cmd, int arg ) ;
FUNCTION: ssize_t read ( int fd, void* buf, size_t nbytes ) ;
FUNCTION: ssize_t write ( int fd, void* buf, size_t nbytes ) ;

C-STRUCT: timeval
    { "long" "sec" }
    { "long" "usec" } ;

: make-timeval ( ms -- timeval )
    1000 /mod 1000 *
    "timeval" <c-object>
    [ set-timeval-usec ] keep
    [ set-timeval-sec ] keep ;

FUNCTION: int select ( int nfds, void* readfds, void* writefds, void* exceptfds, timeval* timeout ) ;

C-STRUCT: hostent
    { "char*" "name" }
    { "void*" "aliases" }
    { "int" "addrtype" }
    { "int" "length" }
    { "void*" "addr-list" } ;

: hostent-addr hostent-addr-list *void* *uint ;

: gethostbyname ( name -- hostent )
    "hostent*" "libc" "gethostbyname" [ "char*" ] alien-invoke ;

FUNCTION: int socket ( int domain, int type, int protocol ) ;
FUNCTION: int setsockopt ( int s, int level, int optname, void* optval, socklen_t optlen ) ;
FUNCTION: int connect ( int s, sockaddr-in* name, socklen_t namelen ) ;
FUNCTION: int bind ( int s, sockaddr-in* name, socklen_t namelen ) ;
FUNCTION: int listen ( int s, int backlog ) ;
FUNCTION: int accept ( int s, sockaddr-in* sockaddr, socklen_t* socklen ) ;

FUNCTION: ssize_t recv ( int s, void* buf, size_t nbytes, int flags ) ;
FUNCTION: ssize_t recvfrom ( int s, void* buf, size_t nbytes, int flags, sockaddr-in* from, socklen_t* fromlen ) ;
FUNCTION: ssize_t sendto ( int s, void* buf, size_t len, int flags, sockaddr-in* to, socklen_t tolen ) ;

FUNCTION: uint htonl ( uint n ) ;
FUNCTION: ushort htons ( ushort n ) ;
FUNCTION: uint ntohl ( uint n ) ;
FUNCTION: ushort ntohs ( ushort n ) ;
