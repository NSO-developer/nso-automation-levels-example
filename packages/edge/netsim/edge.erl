-module(edge).

-include_lib("econfd.hrl").
-include("econfd_errors.hrl").

-export([toggle_jitter/0]).

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
    print("waiting for confd to start~n", []),
    timer:sleep(1000),

    process_flag(trap_exit, true),
    ConfdPort = os:getenv("CONFD_IPC_PORT"),
    print("CONFD_IPC_PORT = ~p~n", [ConfdPort]),
    {ok, Daemon} = econfd:init_daemon(edge, ?CONFD_TRACE, user, none,
                                      {127,0,0,1}, ConfdPort),
    register(edge_dp, self()),

    TransCbs = #confd_trans_cbs{init = fun init_trans/1},
    ok = econfd:register_trans_cb(Daemon, TransCbs),

    DataCbs = #confd_data_cbs{callpoint = edge,
                              get_elem  = fun get_elem/2},
    ok = econfd:register_data_cb(Daemon, DataCbs),

    %% FIXME
    %% * add toggle_jitter rpc

    ok = econfd:register_done(Daemon),

    loop([{high_jitter, false}]).


%% FIXME
%% * separate total and per content metrics
%% * mutliply per content metrics with length of list
%% * set high and low jitter
loop([{high_jitter, HighJitter}] = State) ->
    receive
        {From, toggle_jitter} ->
            From ! {edge_dp, {ok, not HighJitter}},
            loop([{high_jitter, not HighJitter}]);

        {From, {get_elem, ['buffer-fill' | _]}} ->
            Base = 70,
            Rand = rand:uniform(30),
            From ! {edge_dp, {ok, {?C_UINT8, Base + Rand}}},
            loop(State);

        {From, {get_elem, [jitter | _]}} ->
            FractionDigits = 3,
            Base =
                case HighJitter of
                    true  -> 10;
                    false -> 0
                end,
            Rand = abs(rand:normal()),
            Jitter = abs(trunc((Base + Rand) * 1000)),
            From ! {edge_dp, {ok, {?C_DECIMAL64, {Jitter, FractionDigits}}}},
            loop(State);

        {From, {get_elem, _Path}} ->
            Base = 10 * 1024 * 1024,
            Rand = rand:uniform(1024 * 1024),
            From ! {edge_dp, {ok, {?C_UINT64, Base + Rand}}},
            loop(State)
    end.


init_trans(_) -> ok.

get_elem(_Tx, Path) ->
    edge_dp ! {self(), {get_elem, Path}},
    receive
        {edge_dp, Res} ->
            Res
    after 1000 ->
              not_found
    end.

toggle_jitter() ->
    edge_dp ! {self(), toggle_jitter},
    receive
        {edge_dp, Res} ->
            Res
    after 1000 ->
              error
    end.


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
