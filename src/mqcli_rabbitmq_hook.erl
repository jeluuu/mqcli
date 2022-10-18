%%%-------------------------------------------------------------------
%%% @author marco
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 09. Jun 2020 7:56 PM
%%%-------------------------------------------------------------------
-module(mqcli_rabbitmq_hook).
-author("marco").

-behaviour(gen_server).

-include("mqcli.hrl").

%% API
-export([start_link/0]).

%% Client Lifecircle Hooks
-export([on_client_connected/3
  , on_client_disconnected/4
]).


%% Message Pubsub Hooks
-export([ on_message_publish/2
  , on_message_dropped/4
]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2,
  code_change/3]).

-define(SERVER, ?MODULE).

-record(hook_state, {}).

%%%===================================================================
%%% API
%%%===================================================================

%% @doc Spawns the server and registers the local name (unique)
-spec(start_link() ->
  {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link() ->
  lager:start(),
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%--------------------------------------------------------------------
%% Client Lifecircle Hooks
%%--------------------------------------------------------------------

on_client_connected(ClientInfo = #{clientid := ClientId}, ConnInfo, _Env) ->
  io:format("Client(~s) connected, ClientInfo:~n~p~n, ConnInfo:~n~p~n",
    [ClientId, ClientInfo, ConnInfo]).

on_client_disconnected(ClientInfo = #{clientid := ClientId}, ReasonCode, ConnInfo, _Env) ->
  io:format("Client(~s) disconnected due to ~p, ClientInfo:~n~p~n, ConnInfo:~n~p~n",
    [ClientId, ReasonCode, ClientInfo, ConnInfo]).

%%--------------------------------------------------------------------
%% Message PubSub Hooks
%%--------------------------------------------------------------------

%% Transform message and return
on_message_publish(Message = #message{topic = <<"$SYS/", _/binary>>}, _Env) ->
  {ok, Message};

on_message_publish(Message = #message{}, _Env) ->
  lager:debug("Publish emqx ~s~n", [format(Message)]),
  _Payload = Message#message.payload,
  lager:debug("Publish emqx payload ~p~n", [_Payload]),
  gen_server:cast(?MODULE, {on_message_publish, Message}),
  {ok, Message};

on_message_publish(Message, _Env) ->
  io:format("Publish ~s~n", [format(Message)]),
  {ok, Message}.

on_message_dropped(#message{topic = <<"$SYS/", _/binary>>}, _By, _Reason, _Env) ->
  ok;
on_message_dropped(Message, _By = #{node := Node}, Reason, _Env) ->
  io:format("Message dropped by node ~s due to ~s: ~s~n",
    [Node, Reason, format(Message)]).


%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%% @private
%% @doc Initializes the server
-spec(init(Args :: term()) ->
  {ok, State :: #hook_state{}} | {ok, State :: #hook_state{}, timeout() | hibernate} |
  {stop, Reason :: term()} | ignore).
init([]) ->
%%  case application:ensure_started(emqx) of
%%    ok ->
%%      io:format("start emqx success.~n"),
%%      ok;
%%    {error, {already_started, Application}} ->
%%      io:format("emqx already started.~p~n", [Application]),
%%      ok;
%%    Error ->
%%      io:format("start emqx error.~n"),
%%      Error
%%  end,
  io:format("rabbitmq hook started, ~p~n", [self()]),
  {ok, #hook_state{}}.

%% @private
%% @doc Handling call messages
-spec(handle_call(Request :: term(), From :: {pid(), Tag :: term()},
    State :: #hook_state{}) ->
  {reply, Reply :: term(), NewState :: #hook_state{}} |
  {reply, Reply :: term(), NewState :: #hook_state{}, timeout() | hibernate} |
  {noreply, NewState :: #hook_state{}} |
  {noreply, NewState :: #hook_state{}, timeout() | hibernate} |
  {stop, Reason :: term(), Reply :: term(), NewState :: #hook_state{}} |
  {stop, Reason :: term(), NewState :: #hook_state{}}).
handle_call(_Request, _From, State = #hook_state{}) ->
  {reply, ok, State}.

%% @private
%% @doc Handling cast messages
-spec(handle_cast(Request :: term(), State :: #hook_state{}) ->
  {noreply, NewState :: #hook_state{}} |
  {noreply, NewState :: #hook_state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #hook_state{}}).
handle_cast({on_message_publish, Message}, State = #hook_state{}) ->
  lager:debug("cast on_message_push, ~s~n", [format(Message)]),
  #message{
    from = ClientId,
    payload = Payload,
    topic = Topic
  } = Message,

  Msg = #{
    <<"clientid">> => ClientId,
    <<"topic">> => Topic,
    <<"timestamp">> => erlang:system_time(1000),
    <<"payload">> =>  Payload
  },

  lager:info("publish message: client: ~s,  topic: ~s,  payload: ~p~n", [ClientId, Topic, Payload]),
  mqcli:publish(<<"test">>, <<"he">>, Msg),
  lager:debug("publish message finished. ~n client: ~s,  topic: ~s,  payload: ~p~n", [ClientId, Topic, Payload]),
  {noreply, State};
handle_cast(_Request, State = #hook_state{}) ->
  io:format("handle cast~n"),
  {noreply, State}.

%% @private
%% @doc Handling all non call/cast messages
-spec(handle_info(Info :: timeout() | term(), State :: #hook_state{}) ->
  {noreply, NewState :: #hook_state{}} |
  {noreply, NewState :: #hook_state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #hook_state{}}).
handle_info(_Info, State = #hook_state{}) ->
  {noreply, State}.

%% @private
%% @doc This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
-spec(terminate(Reason :: (normal | shutdown | {shutdown, term()} | term()),
    State :: #hook_state{}) -> term()).
terminate(_Reason, _State = #hook_state{}) ->
  ok.

%% @private
%% @doc Convert process state when code is changed
-spec(code_change(OldVsn :: term() | {down, term()}, State :: #hook_state{},
    Extra :: term()) ->
  {ok, NewState :: #hook_state{}} | {error, Reason :: term()}).
code_change(_OldVsn, State = #hook_state{}, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

format(#message{id = Id, qos = QoS, topic = Topic, from = From, flags = Flags, headers = Headers}) ->
  io_lib:format("Message(Id=~s, QoS=~w, Topic=~s, From=~p, Flags=~s, Headers=~s)",
    [Id, QoS, Topic, From, format(flags, Flags), format(headers, Headers)]).


format(_, undefined) ->
  "";
format(flags, Flags) ->
  io_lib:format("~p", [[Flag || {Flag, true} <- maps:to_list(Flags)]]);
format(headers, Headers) ->
  io_lib:format("~p", [Headers]).
