%%%-------------------------------------------------------------------
%%% @author wangdongxing
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%% @end
%%%-------------------------------------------------------------------
-module(mqcli_nsq_hook).
-author("marco").
-behaviour(gen_server).

-include("mqcli.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2,
  code_change/3]).

%% Message Pubsub Hooks
-export([ on_message_publish/2
]).

-define(SERVER, ?MODULE).

-record(mqcli_nsq_hook_state, {}).


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

%%%===================================================================
%%% Spawning and gen_server implementation
%%%===================================================================

start_link() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

init([]) ->
  io:format("nsq hook started, ~p~n", [self()]),
  {ok, #mqcli_nsq_hook_state{}}.

handle_call(_Request, _From, State = #mqcli_nsq_hook_state{}) ->
  {reply, ok, State}.

handle_cast({on_message_publish, Message}, State = #mqcli_nsq_hook_state{}) ->
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
  mqcli_nsq_pub:publish(<<"test">>, Msg),
  lager:debug("publish message finished. ~n client: ~s,  topic: ~s,  payload: ~p~n", [ClientId, Topic, Payload]),
  {noreply, State};
handle_cast(_Request, State = #mqcli_nsq_hook_state{}) ->
  {noreply, State}.

handle_info(_Info, State = #mqcli_nsq_hook_state{}) ->
  {noreply, State}.

terminate(_Reason, _State = #mqcli_nsq_hook_state{}) ->
  ok.

code_change(_OldVsn, State = #mqcli_nsq_hook_state{}, _Extra) ->
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