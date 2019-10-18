! Copyright (C) 2005 Chris Double. All Rights Reserved.
! See http://factorcode.org/license.txt for BSD license.
!
! Concurrency library for Factor based on Erlang/Termite style
! concurrency.
USING: vectors dlists threads sequences continuations
       namespaces random math quotations words kernel match
       arrays io assocs serialize io.sockets io.server ;
IN: concurrency

#! Debug
USE:  prettyprint

TUPLE: mailbox threads data ;

: make-mailbox ( -- mailbox )
    V{ } clone <dlist> mailbox construct-boa ;

: mailbox-empty? ( mailbox -- bool )
    mailbox-data dlist-empty? ;

: mailbox-put ( obj mailbox -- )
    [ mailbox-data dlist-push-end ] keep
    [ mailbox-threads ] keep 0 <vector> swap set-mailbox-threads
    [ schedule-thread ] each yield ;

: (mailbox-block-unless-pred) ( pred mailbox -- pred2 mailbox2 )
    dup mailbox-data pick swap dlist-contains? [
        [ swap mailbox-threads push stop ] callcc0
        (mailbox-block-unless-pred)
    ] unless ;

: (mailbox-block-if-empty) ( mailbox -- mailbox2 )
    dup mailbox-empty? [
        [ swap mailbox-threads push stop ] callcc0
        (mailbox-block-if-empty)
    ] when ;

: mailbox-get ( mailbox -- obj )
    (mailbox-block-if-empty)
    mailbox-data dlist-pop-front ;

: (mailbox-get-all) ( mailbox -- )
    dup mailbox-empty? [
        drop
    ] [
        dup mailbox-data dlist-pop-front , (mailbox-get-all)
    ] if ;

: mailbox-get-all ( mailbox -- array )
    (mailbox-block-if-empty)
    [ (mailbox-get-all) ] { } make ;

: while-mailbox-empty ( mailbox quot -- )
    over mailbox-empty? [
        dup >r swap slip r> while-mailbox-empty
    ] [
        2drop
    ] if ; inline

: mailbox-get? ( pred mailbox -- obj )
    (mailbox-block-unless-pred) mailbox-data dlist-remove ;

TUPLE: node hostname port ;

C: <node> node

: localnode ( -- node )
    \ localnode get ;

TUPLE: process links pid mailbox ;

C: <process> process

TUPLE: remote-process node pid ;

C: <remote-process> remote-process

GENERIC: send ( message process -- )

: random-64 ( -- id )
    #! Generate a random id to use for pids
    "ID" 64 [ drop 10 random CHAR: 0 + ] map append ;

: make-process ( -- process )
    #! Return a process set to run on the local node. A process is
    #! similar to a thread but can send and receive messages to and
    #! from other processes. It may also be linked to other processes so
    #! that it receives a message if that process terminates.
    [ ] random-64 make-mailbox <process> ;

: make-linked-process ( process -- process )
    #! Return a process set to run on the local node. That process is
    #! linked to the process on the stack. It will receive a message if
    #! that process terminates.
    1quotation random-64 make-mailbox <process> ;

: self ( -- process )
    \ self get  ;

: init-main-process ( -- )
    #! Setup the main process.
    make-process \ self set-global ;

init-main-process

: with-process ( quot process -- )
    #! Calls the quotation with 'self' set
    #! to the given process.
    [
        \ self set
    ] H{ } make-assoc swap bind ;

DEFER: register-process
DEFER: unregister-process

: ((spawn)) ( quot -- )
    self dup process-pid swap register-process
    call
    self process-pid unregister-process ; inline

: (spawn) ( quot -- process )
    [ in-thread ] make-process [ with-process ] keep ;

: spawn ( quot -- process )
    [
        ((spawn))
    ] curry (spawn) ;

TUPLE: linked-exception error ;

C: <linked-exception> linked-exception

: while-no-messages ( quot -- )
    #! Run the quotation in a loop while no messages are in
    #! the processes mailbox. The quot should have stack effect
    #! ( -- ).
    >r self process-mailbox r> while-mailbox-empty ; inline

M: process send ( message process -- )
    process-mailbox mailbox-put ;

: receive ( -- message )
    self process-mailbox mailbox-get dup linked-exception? [
        linked-exception-error throw
    ] when ;

: receive-if ( pred -- message )
    self process-mailbox mailbox-get? dup linked-exception? [
        linked-exception-error throw
    ] when ;

: rethrow-linked ( error -- )
    #! Rethrow the error to the linked process
    self process-links [
        over <linked-exception> swap send
    ] each drop ;

: (spawn-link) ( quot -- process )
    [ in-thread ] self make-linked-process
    [ with-process ] keep ;

: spawn-link ( quot -- process )
    [ catch [ rethrow-linked ] when* ] curry
    [
        ((spawn))
    ] curry (spawn-link) ;

: (recv) ( msg form -- )
    #! Process a form with the following format:
    #!   [ pred match-quot ]
    #! 'pred' is a word that has stack effect ( msg -- bool ). It is
    #! executed with the message on the stack. It should return a
    #! boolean if it is a message this form should process.
    #! 'match-quot' is a quotation with stack effect ( msg -- ). It
    #! will be called with the message on the top of the stack if
    #! the 'pred' word returned true.
    [ first execute ] 2keep rot [ second call ] [ 2drop ] if ;

: recv ( forms -- )
    #! Get a message from the processes mailbox. Compare it against the
    #! forms to run a quotation if it matches the given message. 'forms'
    #! is a list of quotations in the following format:
    #!   [ pred match-quot ]
    #! 'pred' is a word that has stack effect ( msg -- bool ). It is
    #! executed with the message on the stack. It should return a
    #! boolean if it is a message this form should process.
    #! 'match-quot' is a quotation with stack effect ( msg -- ). It
    #! will be called with the message on the top of the stack if
    #! the 'pred' word returned true.
    #! Each form in the list will be matched against the message,
    #! even if a prior match succeeded. This means multiple quotations
    #! may be run against the message.
    receive swap [ dupd (recv) ] each drop ;

MATCH-VARS: ?from ?tag ;

: tag-message ( message -- tagged-message )
    #! Given a message, wrap it with the sending process and a unique tag.
    >r self random-64 r> 3array ;

: send-synchronous ( message process -- reply )
    #! Sends a message to the process synchronously. The
    #! message will be wrapped to include the process of the sender
    #! and a unique tag. After being sent the sending process will
    #! block for a reply tagged with the same unique tag.
    >r tag-message dup r> send second _ 2array [ match ] curry
    receive-if second ;

: forever ( quot -- )
    #! Loops forever executing the quotation.
    dup slip forever ;

SYMBOL: quit-cc

: (spawn-server) ( quot -- )
    #! Receive a message, and run 'quot' on it. If 'quot'
    #! returns true, start again, otherwise exit loop.
    #! The quotation should have stack effect ( message -- bool ).
    "Waiting for message in server: " write
    self process-pid print
    receive over call [ (spawn-server) ] when ;

: spawn-server ( quot -- process )
    #! Spawn a server that receives messages, calling the
    #! quotation on the message. If the quotation returns false
    #! the spawned process exits. If it returns true, the process
    #! starts from the beginning again. The quotation should have
    #! stack effect ( message -- bool ).
    [
        (spawn-server)
        "Exiting process: " write self process-pid print
    ] curry spawn ;

: spawn-linked-server ( quot -- process )
    #! Similar to 'spawn-server' but the parent process will be linked
    #! to the child.
    [
        (spawn-server)
        "Exiting process: " write self process-pid print
    ] curry spawn-link ;

: server-cc ( -- cc | process )
    #! Captures the current continuation and returns the value.
    #! If that CC is called with a process on the stack it will
    #! set 'self' for the current process to it. Otherwise it will
    #! return the value. This allows capturing a continuation in a server,
    #! and jumping back into it from a spawn and keeping the 'self'
    #! variable correct. It's a workaround until I can find out how to
    #! stop 'self' from being clobbered back to its old value.
    [ ] callcc1 dup process? [ \ self set-global f ] when ;

: call-server-cc ( server-cc -- )
    #! Calls the server continuation passing the current 'self'
    #! so the server continuation gets its new self updated.
    self swap call ;

: future ( quot -- future )
    #! Spawn a process to call the quotation and immediately return
    #! a 'future' on the stack. The future can later be queried with
    #! ?future. If the quotation has completed the result will be returned.
    #! If not, the process will block until the quotation completes.
    #! 'quot' must have stack effect ( -- X ).
    [ self send ] compose spawn ;

: ?future ( future -- result )
    #! Block the process until the future has completed and then
    #! place the result on the stack. Return the result
    #! immediately if the future has completed.
    process-mailbox mailbox-get ;

: parallel-map ( seq quot -- newseq )
    #! Spawn a process to apply quot to each element of seq,
    #! joining the results into a sequence at the end.
    [ curry future ] curry map [ ?future ] map ;

: parallel-each ( seq quot -- newseq )
    #! Spawn a process to apply quot to each element of seq,
    #! and waits for all processes to complete.
    [ f ] compose parallel-map drop ;

TUPLE: promise fulfilled? value processes ;

: <promise> ( -- <promise> )
    f f V{ } clone promise construct-boa ;

: fulfill ( value promise  -- )
    #! Set the future of the promise to the given value. Threads
    #! blocking on the promise will then be released.
    dup promise-fulfilled? [
        [ set-promise-value ] keep
        [ t swap set-promise-fulfilled? ] keep
        [ promise-processes ] keep
        0 <vector> swap set-promise-processes
        [ schedule-thread ] each yield
    ] unless ;

 : (maybe-block-promise) ( promise -- promise )
    #! Block the process if the promise is unfulfilled. This is different from
    #! (mailbox-block-if-empty) in that when a promise is fulfilled, all threads
    #! need to be resumed, rather than just one.
    dup promise-fulfilled? [
        [ swap promise-processes push stop ] callcc0
    ] unless ;

: ?promise ( promise -- result )
    (maybe-block-promise) promise-value ;

! ******************************
! Experimental code below
! ******************************
: (lazy) ( v -- )
    receive {
        { { ?from ?tag _ }
            [ ?tag over 2array ?from send (lazy) ] }
    } match-cond ;

: lazy ( quot -- lazy )
    #! Spawn a process that immediately blocks and return it.
    #! When '?lazy' is called on the returned process, call the quotation
    #! and return the result. The quotation must have stack effect ( -- X ).
    [
        receive {
            { { ?from ?tag _ }
                [ call ?tag over 2array ?from send (lazy) ] }
        } match-cond
    ] spawn nip ;

: ?lazy ( lazy -- result )
    #! Given a process spawned using 'lazy', evaluate it and return the result.
    f swap send-synchronous ;

! ******************************
! Standard Processes
! ******************************
MATCH-VARS: ?process ?name ;
SYMBOL: register
SYMBOL: unregister

: process-registry ( table -- )
    receive {
        { { register ?name ?process }
            [ ?process ?name pick set-at ] }
        { { unregister ?name }
            [ ?name over delete-at ] }
        { { ?from ?tag { process ?name } }
            [ ?tag ?name pick at 2array ?from send ] }
    } match-cond process-registry ;

: register-process ( name process -- )
    [ register , swap , , ] { } make
    \ process-registry get send ;

: unregister-process ( name -- )
    [ unregister , , ] { } make
    \ process-registry get send ;

: get-process ( name -- )
    [ process , , ] { } make
    \ process-registry get send-synchronous ;

[
    H{ } clone process-registry
] (spawn) \ process-registry set-global

: handle-node-client ( -- )
    [ deserialize ] with-serialized first2 get-process send ;

: node-server ( port -- )
    local-server [ handle-node-client ] with-server ;

: send-to-node ( msg pid  host port -- )
    <inet> <client> [ 2array [ serialize ] with-serialized ] with-stream ;

: start-node ( hostname port -- )
    [ node-server ] in-thread
    <node> \ localnode set-global ;

M: remote-process send ( message process -- )
    #! Send the message via the inter-node protocol
    [ remote-process-pid ] keep
    remote-process-node
    [ node-hostname ] keep
    node-port send-to-node ;

M: process serialize ( obj -- )
    localnode swap process-pid <remote-process> serialize ;

SYMBOL: line
: (test-node1)
    receive dup line set {
        ! { { ?from ?tag _ }
        !   [ ?tag "ack" 2array ?from send (test-node1) ] }
        { _ [ line get . ] }
    } match-cond ;

: test-node1 ( -- )
    [ (test-node1) ] spawn
    "test1" swap register-process ;

: test-node2 ( hostname port -- )
    [
        <node> "test1" <remote-process>
        "message" swap send-synchronous .
    ] spawn 2drop ;
