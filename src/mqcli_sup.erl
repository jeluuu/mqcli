%%%-------------------------------------------------------------------
%%% @author marco
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%% @end
%%%-------------------------------------------------------------------
-module(mqcli_sup).

-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
  {ok, {{one_for_one, 1, 5}, []}}.
%%  AChild = #{id => 'AName',
%%    start => {'AModule', start_link, []},
%%    restart => permanent,
%%    shutdown => 2000,
%%    type => worker,
%%    modules => ['AModule']},

%%  {ok, {#{strategy => one_for_one,
%%    intensity => 5,
%%    period => 30}}
%%%%    [AChild]}
%%  }.
