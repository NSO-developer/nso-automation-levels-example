-module(vvsim).

-include_lib("econfd.hrl").
-include("econfd_errors.hrl").

-on_load(on_load/0).

-define(NS, 'urn:test:tailf-vv').

on_load() ->
    Self = self(),
    proc_lib:spawn(fun() -> print_start(Self) end),
    receive
        print_started ->
            ok
    end,
    proc_lib:spawn(fun start/0),
    ok.

start() ->
    %% wait for confd to come up
    print("waiting for confd to start~n", []),
    timer:sleep(2000),

    {ok, Daemon} = econfd:init_daemon(vvsim, ?CONFD_TRACE, user, none,
                                      {127,0,0,1}, ?CONFD_PORT),
    ok = econfd:register_done(Daemon),

    try
        {S, SubS, Sub} = worker_init(),
        worker_loop(S, SubS, Sub)
    catch
        Type:What:Stack ->
            print("ERR worker_init failed ~p:~p~n", [Type, What]),
            print("~p~n", [Stack])
    end.

worker_init() ->
    print("connect to confd~n", []),
    {ok, S} = econfd_cdb:connect({127,0,0,1}, ?CONFD_PORT),
    econfd_cdb:wait_start(S),

    print("subscribe to confd~n", []),
    {ok, SubS} = econfd_cdb:connect({127,0,0,1}, ?CONFD_PORT),
    {ok, Sub} = econfd_cdb:subscribe_session(SubS),
    {ok, Point} = econfd_cdb:subscribe(Sub, 1, ?NS, "/slow"),
    ok = econfd_cdb:subscribe_done(Sub),

    print("subscribe done ~p, starting~n", [Point]),
    {S, SubS, Sub}.

worker_loop(S, SubS, Sub) ->
    Reader = fun(Points) ->
                     reader(Points, S, Sub)
             end,
    try
        econfd_cdb:wait(Sub, 20000, Reader)
    catch Type:What:Stack ->
            print("ERR cdb wait failed ~p:~p~n", [Type, What]),
            print("~p~n", [Stack])
    end,

    worker_loop(S, SubS, Sub).

iter(IKeypath, _Op, _, _, Acc) ->
    case lists:reverse(IKeypath) of
        [[?NS|slow]|_] ->
            DelayMs = 5000,
            print("delay write by ~ps~n", [DelayMs / 1000]),
            timer:sleep(DelayMs),
            {ok, ?ITER_STOP, Acc};
        _ ->
            {ok, ?ITER_STOP, Acc}
    end.

reader(Points, _S , Sub) ->
    print("subscription point = ~p~n", [Points]),
    [Point] = Points,
    {ok, _Res} = econfd_cdb:diff_iterate(
                   Sub, Point, fun iter/5,
                   ?CDB_ITER_WANT_PREV bor ?CDB_ITER_WANT_ANCESTOR_DELETE, []),
    ?CDB_DONE_PRIORITY.

print(Fmt, Args) ->
    printer ! {print, Fmt, Args}.

print_start(From) ->
    register(printer, self()),
    {ok, Fd} = file:open("./logs/vvsim.log", [write]),
    From ! print_started,
    print_loop(Fd).

print_loop(Fd) ->
    receive
        {print, Fmt, Args} ->
            io:format(Fd, Fmt, Args),
            print_loop(Fd)
    end.
