-module(edge).

-include_lib("econfd.hrl").
-include("econfd_errors.hrl").


-define(NS, 'http://tail-f.com/ns/cleu24/tecops-2665/edge').

-record(state, {maapi       :: econfd:socket(),
                high_jitter :: boolean()}).


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

    {ok, MaapiSock} = econfd_maapi:connect({127,0,0,1}, ConfdPort),

    TransCbs = #confd_trans_cbs{init = fun init_trans/1},
    ok = econfd:register_trans_cb(Daemon, TransCbs),

    DataCbs = #confd_data_cbs{callpoint = edge,
                              get_elem  = fun get_elem/2},
    ok = econfd:register_data_cb(Daemon, DataCbs),

    ActionCbs = #confd_action_cb{actionpoint = 'toggle-jitter',
                                 action = fun toggle_jitter/4},
    ok = econfd:register_action_cb(Daemon, ActionCbs),

    ok = econfd:register_done(Daemon),

    loop(#state{maapi = MaapiSock, high_jitter = false}).


%% * separate total and per content metrics
%% * mutliply per content metrics with length of list
%% * set high and low jitter
loop(#state{maapi = MaapiSock, high_jitter = HighJitter} = State) ->
    receive
        %% rpc
        {From, toggle_jitter} ->
            From ! {edge_dp, ok},
            loop(State#state{high_jitter = not HighJitter});

        %% jitter
        {From, {get_elem, [jitter | _]}} ->
            N = num_instances(MaapiSock),
            From ! {edge_dp, {ok, {?C_DECIMAL64, jitter(N, HighJitter)}}},
            loop(State);

        %% per content metrics
        {From, {get_elem, ['buffer-fill', {_}, content | _]}} ->
            From ! {edge_dp, {ok, {?C_UINT8, buffer_fill(1)}}},
            loop(State);

        {From, {get_elem, [_Leaf, {_}, content | _]}} ->
            From ! {edge_dp, {ok, {?C_UINT64, traffic(1)}}},
            loop(State);

        %% totals metrics
        {From, {get_elem, ['buffer-fill' | _]}} ->
            N = num_instances(MaapiSock),
            From ! {edge_dp, {ok, {?C_UINT8, buffer_fill(N)}}},
            loop(State);

        {From, {get_elem, _Path}} ->
            N = num_instances(MaapiSock),
            From ! {edge_dp, {ok, {?C_UINT64, traffic(N)}}},
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

toggle_jitter(_Uinfo, _Name, _IKP, _Params) ->
    edge_dp ! {self(), toggle_jitter},
    receive
        {edge_dp, Res} ->
            Res
    after 1000 ->
              error
    end.


%% uint8
buffer_fill(0) -> 0;
buffer_fill(_) -> 70 + rand:uniform(30).

-define(JITTER_FRACTION_DIGITS, 3).

%% decimal64
jitter(0, _) ->
    {0, ?JITTER_FRACTION_DIGITS};
jitter(_, HighJitter) ->
    Base =
        case HighJitter of
            true  -> 10;
            false -> 0
        end,
    Rand = abs(rand:normal()),
    Jitter = abs(trunc((Base + Rand) * 1000)),
    {Jitter, ?JITTER_FRACTION_DIGITS}.

%% uint64
traffic(N) ->
    Base = 10 * 1024 * 1024,
    Rand = rand:uniform(1024 * 1024),
    N * (Base + Rand).

num_instances(MaapiSock) ->
    ok = econfd_maapi:start_user_session(MaapiSock, <<"admin">>, <<"maapi">>,
                                         [<<"admin">>], {127,0,0,1},
                                         ?CONFD_PROTO_TCP),
    {ok, Th} = econfd_maapi:start_trans(MaapiSock, ?CONFD_RUNNING, ?CONFD_READ),
    {ok, Num} =
        econfd_maapi:num_instances(MaapiSock, Th, [content, [?NS|edge]]),
    ok = econfd_maapi:finish_trans(MaapiSock, Th),
    ok = econfd_maapi:end_user_session(MaapiSock),
    Num.


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
