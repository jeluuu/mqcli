%%%-------------------------------------------------------------------
%%% @author marco
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 06. Jun 2020 6:22 PM
%%%-------------------------------------------------------------------
-author("marco").

-define(APP, mqcli).


-record(message, {
  %% Global unique message ID
  id :: binary(),
  %% Message QoS
  qos = 0,
  %% Message from
  from :: atom() | binary(),
  %% Message flags
  flags :: #{atom() => boolean()},
  %% Message headers, or MQTT 5.0 Properties
  headers :: map(),
  %% Topic that the message is published to
  topic :: binary(),
  %% Message Payload
  payload :: binary(),
  %% Timestamp (Unit: millisecond)
  timestamp :: integer()
}).