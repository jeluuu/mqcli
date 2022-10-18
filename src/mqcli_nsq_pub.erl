%%%-------------------------------------------------------------------
%%% @author wangdongxing
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%% @end
%%%-------------------------------------------------------------------
-module(mqcli_nsq_pub).

-behaviour(gen_server).

-include("mqcli.hrl").

-export([publish/2]).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2,
  code_change/3]).

-define(SERVER, ?MODULE).

-record(mqcli_nsq_pub_state, {}).

-spec(publish(Topic:: binary() | bitstring(), Msg:: term() | iodata() | binary()) -> ok).
publish(Topic, Msg) when is_binary(Msg) ->
  gen_server:cast(?MODULE, {publish, Topic, Msg}),
  lager:debug("publish message finished. ~n topic: ~s,  payload: ~p~n", [Topic, Msg]),
  ok;

publish(Topic, Msg) ->
  publish(Topic, jsx:encode(Msg)).


%%%===================================================================
%%% Spawning and gen_server implementation
%%%===================================================================

start_link() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

init([]) ->
  {ok, DiscoveryServers} = application:get_env(?APP, nsqlookupd),
  {ok, Workers} = application:get_env(?APP, nsqd),

  lager:info("nsqloopupd: ~p, nsqd: ~p~n", [DiscoveryServers, Workers]),

  Channels = [
    {<<"test1">>, ensq_debug_callback},       %% Callback Module
    {<<"test2">>, ensq_debug_callback}
  ],

  Topics = [
    {<<"test">>, Channels, Workers},
    {<<"topic1">>, Channels, Workers},
    {<<"topic2">>, Channels, Workers}
  ],

  ensq:init({DiscoveryServers, Topics}),
  lager:debug("ensq init finished."),

  %% Sending a message to a topic
  %%  ensq:send(test, <<"hello there!">>),
  {ok, #mqcli_nsq_pub_state{}}.

handle_call(_Request, _From, State = #mqcli_nsq_pub_state{}) ->
  {reply, ok, State}.

handle_cast({publish, Topic, Msg}, State = #mqcli_nsq_pub_state{}) ->
  %% Publish a message
  lager:debug("send message start. ~n topic: ~s,  payload: ~p~n", [Topic, Msg]),
  ensq:send(test, <<"hello there!">>),
  lager:debug("send message finished. ~n topic: ~s,  payload: ~p~n", [Topic, Msg]),
%%  ensq:send(topic1, Msg),
  ensq:send(Topic, Msg),
  {noreply, State};
handle_cast(_Request, State = #mqcli_nsq_pub_state{}) ->
%%  ensq:send(<<"topic1">>, <<"hello there!">>),
%%  ensq:send(<<"topic2">>, <<"hello there!">>),
  {noreply, State}.

handle_info(_Info, State = #mqcli_nsq_pub_state{}) ->
  {noreply, State}.

terminate(_Reason, _State = #mqcli_nsq_pub_state{}) ->
  ok.

code_change(_OldVsn, State = #mqcli_nsq_pub_state{}, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
