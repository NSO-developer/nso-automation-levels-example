-module(edge).

-include_lib("econfd.hrl").
-include("econfd_errors.hrl").

-on_load(on_load/0).

on_load() ->
    start(),
    ok.

start() ->
    start_log(),
    spawn(fun init/0).

start_log() ->
    Self = self(),
    proc_lib:spawn(fun() -> print_start(Self) end),
    receive
        print_started ->
            ok
    end.


init() ->
    %% wait for confd to come up
    print("waiting for confd to start~n", []),
    timer:sleep(1000),

    process_flag(trap_exit, true),
    ConfdPort = os:getenv("CONFD_IPC_PORT"),
    print("CONFD_IPC_PORT = ~p~n", [ConfdPort]),
    {ok, Daemon} = econfd:init_daemon(edge, ?CONFD_TRACE, user, none,
                                      {127,0,0,1}, ConfdPort),

    TransCbs = #confd_trans_cbs{init = fun init_trans/1},
    ok = econfd:register_trans_cb(Daemon, TransCbs),

    DataCbs = #confd_data_cbs{callpoint = edge,
                              get_elem  = fun get_elem/2},
    ok = econfd:register_data_cb(Daemon, DataCbs),

    ok = econfd:register_done(Daemon),

    loop().


loop() ->
    receive
    after infinity ->
              ok
    end.

init_trans(_) -> ok.

%% FIXME
%% * separate total and per content metrics
%% * mutliply per content metrics with length of list
%% * set high and low jitter
get_elem(_Tx, ['buffer-fill' | _]) ->
    Base = 70,
    Rand = rand:uniform(30),
    {ok, {?C_UINT8, Base + Rand}};
get_elem(_Tx, [jitter | _]) ->
    FractionDigits = 3,
    Base = 0,
    Rand = abs(rand:normal()),
    Jitter = abs(trunc((Base + Rand) * 1000)),
    {ok, {?C_DECIMAL64, {Jitter, FractionDigits}}};
get_elem(_Tx, _Path) ->
    Base = 10 * 1024 * 1024,
    Rand = rand:uniform(1024 * 1024),
    {ok, {?C_UINT64, Base + Rand}}.


print(Fmt, Args) ->
    printer ! {print, Fmt, Args}.

print_start(From) ->
    register(printer, self()),
    {ok, Fd} = file:open("./" ++ atom_to_list(?MODULE) ++ ".log", [write]),
    From ! print_started,
    print_loop(Fd).

print_loop(Fd) ->
    receive
        {print, Fmt, Args} ->
            io:format(Fd, Fmt, Args),
            print_loop(Fd)
    end.
