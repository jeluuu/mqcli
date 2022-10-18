%%%-------------------------------------------------------------------
%%% @author marco
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 06. Jun 2020 4:05 PM
%%%-------------------------------------------------------------------
-module(mqcli).
-author("marco").

-behaviour(gen_server).

%% API
-export([start_link/0,publish/3]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2,
  code_change/3]).

-include_lib("amqp_client/include/amqp_client.hrl").
-include("mqcli.hrl").

-define(SERVER, ?MODULE).

-record(mqcli_state, {connection, channel}).


-spec(publish(Exchange:: binary() | bitstring(), RoutingKey:: binary(), Msg:: term() | iodata() | binary()) -> ok).
publish(Exchange, RoutingKey, Msg) when is_binary(Msg) ->
  gen_server:cast(?MODULE, {publish, Exchange, RoutingKey, Msg}),
  ok;

publish(Exchange, RoutingKey, Msg) ->
  publish(Exchange, RoutingKey, jsx:encode(Msg)).


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
  {ok, State :: #mqcli_state{}} | {ok, State :: #mqcli_state{}, timeout() | hibernate} |
  {stop, Reason :: term()} | ignore).
init([]) ->
  case application:ensure_started(amqp_client) of
    ok ->
      io:format("start amqp client success.~n"),
      ok;
    {error, {already_started, Application}} ->
      io:format("amqp client already started.~p~n", [Application]),
      ok;
    Error ->
      io:format("start amqp client error.~n"),
      Error
  end,
  {ok, ConfigSpecs} = application:get_env(?APP, amqp_uri),
  {ok, AmqpConfig} = amqp_uri:parse(ConfigSpecs),
  lager:debug("amqp_uri: ~p~n", [AmqpConfig]),
  {ok, Connection} = amqp_connection:start(AmqpConfig),
%%  case amqp_connection:start(AmqpConfig) of
%%    {ok, _Connection} ->
%%      io:format("consumer connect success. ConnPid: ~p~n", [_Connection]);
%%    {error, _Error} ->
%%      io:format("consumer connect fail. Error: ~p~n", [_Error])
%%  end,

%%  {ok, Connection} = amqp_connection:start(
%%    #amqp_params_network{
%%      username = <<"marco">>,
%%      password = <<"top123.">>,
%%      port = 5672
%%    }
%%  ),

  io:format("publisher connect success. ConnPid: ~p~n", [Connection]),
  {ok, Channel} = amqp_connection:open_channel(Connection),
  io:format("publisher channel: ~p~n", [Channel]),
  #'exchange.declare_ok'{} = amqp_channel:call(Channel, #'exchange.declare'{
    exchange = <<"test">>,
    durable  = true
  }),
  io:format("publisher declare exchange: ~p~n", [<<"test">>]),
  {ok, #mqcli_state{
    connection = Connection,
    channel = Channel
  }}.

%% @private
%% @doc Handling call messages
-spec(handle_call(Request :: term(), From :: {pid(), Tag :: term()},
    State :: #mqcli_state{}) ->
  {reply, Reply :: term(), NewState :: #mqcli_state{}} |
  {reply, Reply :: term(), NewState :: #mqcli_state{}, timeout() | hibernate} |
  {noreply, NewState :: #mqcli_state{}} |
  {noreply, NewState :: #mqcli_state{}, timeout() | hibernate} |
  {stop, Reason :: term(), Reply :: term(), NewState :: #mqcli_state{}} |
  {stop, Reason :: term(), NewState :: #mqcli_state{}}).
handle_call(_Request, _From, State = #mqcli_state{}) ->
  {reply, ok, State}.

%% @private
%% @doc Handling cast messages
-spec(handle_cast(Request :: term(), State :: #mqcli_state{}) ->
  {noreply, NewState :: #mqcli_state{}} |
  {noreply, NewState :: #mqcli_state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #mqcli_state{}}).
handle_cast({publish, Exchange, RKey, Msg}, State = #mqcli_state{}) ->
  %% Publish a message
  Publish = #'basic.publish'{exchange = Exchange, routing_key = RKey },
  amqp_channel:cast(State#mqcli_state.channel, Publish, #amqp_msg{payload = Msg}),
  {noreply, State}.

%% @private
%% @doc Handling all non call/cast messages
-spec(handle_info(Info :: timeout() | term(), State :: #mqcli_state{}) ->
  {noreply, NewState :: #mqcli_state{}} |
  {noreply, NewState :: #mqcli_state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #mqcli_state{}}).
handle_info(_Info, State = #mqcli_state{}) ->
  {noreply, State}.

%% @private
%% @doc This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
-spec(terminate(Reason :: (normal | shutdown | {shutdown, term()} | term()),
    State :: #mqcli_state{}) -> term()).
terminate(_Reason, _State = #mqcli_state{}) ->
  ok.

%% @private
%% @doc Convert process state when code is changed
-spec(code_change(OldVsn :: term() | {down, term()}, State :: #mqcli_state{},
    Extra :: term()) ->
  {ok, NewState :: #mqcli_state{}} | {error, Reason :: term()}).
code_change(_OldVsn, State = #mqcli_state{}, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
