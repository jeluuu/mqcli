%%%-------------------------------------------------------------------
%%% @author marco
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 08. Jun 2020 5:40 PM
%%%-------------------------------------------------------------------
-module(mqcli_consume).
-author("marco").

-behaviour(gen_server).

%% API
-export([start_link/0]).

-include_lib("amqp_client/include/amqp_client.hrl").

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2,
  code_change/3]).

-define(SERVER, ?MODULE).

-record(mqcli_consume_state, {connection, channel}).

%%%===================================================================
%%% API
%%%===================================================================

%% @doc Spawns the server and registers the local name (unique)
-spec(start_link() ->
  {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%% @private
%% @doc Initializes the server
-spec(init(Args :: term()) ->
  {ok, State :: #mqcli_consume_state{}} | {ok, State :: #mqcli_consume_state{}, timeout() | hibernate} |
  {stop, Reason :: term()} | ignore).
init([]) ->
%%  application:ensure_started(amqp_client),

  case application:ensure_started(amqp_client) of
    ok ->
      io:format("start amqp client success.~n"),
      ok;
    {error, {already_started, Application}} ->
      io:format("amqp client already started.~n"),
      ok;
    Error ->
      io:format("start amqp client error.~n"),
      Error
  end,

  {ok, ConfigSpecs} = application:get_env(mqcli, amqp_uri),
  {ok, AmqpConfig} = amqp_uri:parse(ConfigSpecs),
  lager:debug("amqp_uri: ~p~n", [AmqpConfig]),
  {ok, Connection} = amqp_connection:start(AmqpConfig),
%%  {ok, Connection} = case amqp_connection:start(#amqp_params_network{port = 5672}) of
%%                       {ok, _Connection} ->
%%                         io:format("consumer connect success. ConnPid: ~p~n", [_Connection]);
%%                       {error, _Error} ->
%%                         io:format("consumer connect fail. Error: ~p~n", [_Error])
%%                     end,

  io:format("consumer connect success. ConnPid: ~p~n", [Connection]),

  {ok, Channel} = amqp_connection:open_channel(Connection),
  io:format("consumer channel: ~p~n", [Channel]),

  #'exchange.declare_ok'{} = amqp_channel:call(Channel, #'exchange.declare'{
    exchange = <<"test">>,
    durable  = true
  }),
  io:format("consumer declare exchange: ~p~n", [<<"test">>]),

  #'queue.declare_ok'{queue = Q} = amqp_channel:call(Channel, #'queue.declare'{queue = <<"erlang">>, durable = false}),
  io:format("declare queue: ~p~n", [Q]),


  Binding = #'queue.bind'{queue = Q,
    exchange = <<"test">>,
    routing_key = <<"he">>
  },
  #'queue.bind_ok'{} = amqp_channel:call(Channel, Binding),
  io:format("binding queue: ~p~n", [Q]),

  #'basic.consume_ok'{consumer_tag = Tag} =
    amqp_channel:call(Channel, #'basic.consume'{queue = Q}, self()),
  io:format("create consumer: ~p~n", [Tag]),

  read(Channel),

  {ok, #mqcli_consume_state{
    connection = Connection,
    channel = Channel
  }}.

read(Channel) ->
  receive
  %% This is the first message received
    #'basic.consume_ok'{} ->
      read(Channel);

  %% This is received when the subscription is cancelled
    #'basic.cancel_ok'{} ->
      ok;

  %% A delivery
    {#'basic.deliver'{delivery_tag = Tag}, Content} ->
      %% Do something with the message payload
      %% (some work here)

      %% Ack the message
      amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag}),

      %% Loop
      read(Channel)
  end.

%% @private
%% @doc Handling call messages
-spec(handle_call(Request :: term(), From :: {pid(), Tag :: term()},
    State :: #mqcli_consume_state{}) ->
  {reply, Reply :: term(), NewState :: #mqcli_consume_state{}} |
  {reply, Reply :: term(), NewState :: #mqcli_consume_state{}, timeout() | hibernate} |
  {noreply, NewState :: #mqcli_consume_state{}} |
  {noreply, NewState :: #mqcli_consume_state{}, timeout() | hibernate} |
  {stop, Reason :: term(), Reply :: term(), NewState :: #mqcli_consume_state{}} |
  {stop, Reason :: term(), NewState :: #mqcli_consume_state{}}).
handle_call(_Request, _From, State = #mqcli_consume_state{}) ->
  {reply, ok, State}.

%% @private
%% @doc Handling cast messages
-spec(handle_cast(Request :: term(), State :: #mqcli_consume_state{}) ->
  {noreply, NewState :: #mqcli_consume_state{}} |
  {noreply, NewState :: #mqcli_consume_state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #mqcli_consume_state{}}).
handle_cast(_Request, State = #mqcli_consume_state{}) ->
  {noreply, State}.

%% @private
%% @doc Handling all non call/cast messages
-spec(handle_info(Info :: timeout() | term(), State :: #mqcli_consume_state{}) ->
  {noreply, NewState :: #mqcli_consume_state{}} |
  {noreply, NewState :: #mqcli_consume_state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #mqcli_consume_state{}}).
handle_info(_Info, State = #mqcli_consume_state{}) ->
  {noreply, State}.

%% @private
%% @doc This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
-spec(terminate(Reason :: (normal | shutdown | {shutdown, term()} | term()),
    State :: #mqcli_consume_state{}) -> term()).
terminate(_Reason, _State = #mqcli_consume_state{}) ->
  ok.

%% @private
%% @doc Convert process state when code is changed
-spec(code_change(OldVsn :: term() | {down, term()}, State :: #mqcli_consume_state{},
    Extra :: term()) ->
  {ok, NewState :: #mqcli_consume_state{}} | {error, Reason :: term()}).
code_change(_OldVsn, State = #mqcli_consume_state{}, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
