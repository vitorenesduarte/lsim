%%
%% Copyright (c) 2016 SyncFree Consortium.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

-module(lsim_rsg_master).
-author("Vitor Enes Duarte <vitorenesduarte@gmail.com").

-include("lsim.hrl").

-behaviour(gen_server).

%% lsim_rsg_master callbacks
-export([start_link/0]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-record(state, {nodes :: undefined | list(node_spec()),
                connect_done:: ordsets:ordset(ldb_node_id()),
                sim_done :: ordsets:ordset(ldb_node_id()),
                metrics_done :: ordsets:ordset(ldb_node_id()),
                metrics_nodes :: undefined | list(ldb_node_id()),
                start_time :: undefined | timestamp()}).

-define(BARRIER_PEER_SERVICE, lsim_barrier_peer_service).
-define(INTERVAL, 3000).

-spec start_link() -> {ok, pid()} | ignore | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% gen_server callbacks
init([]) ->
    schedule_create_barrier(),
    lager:info("lsim_rsg_master initialized"),

    {ok, #state{nodes=undefined,
                connect_done=ordsets:new(),
                sim_done=ordsets:new(),
                metrics_done=ordsets:new(),
                metrics_nodes=undefined,
                start_time=undefined}}.

handle_call(Msg, _From, State) ->
    lager:warning("Unhandled call message: ~p", [Msg]),
    {noreply, State}.

handle_cast({connect_done, NodeName},
            #state{nodes=Nodes,
                   connect_done=ConnectDone0}=State) ->

    lager:info("Received CONNECT DONE from ~p", [NodeName]),

    ConnectDone1 = ordsets:add_element(NodeName, ConnectDone0),

    {T1, MetricsNodes1} = case ordsets:size(ConnectDone1) == node_number() of
        true ->
            lager:info("Everyone is CONNECT DONE. SIM GO!"),

            MetricsNodes0 = configure_break_link_metrics(Nodes),

            T0 = ldb_util:unix_timestamp(),
            tell(sim_go),
            {T0, MetricsNodes0};
        false ->
            {undefined, undefined}
    end,

    {noreply, State#state{connect_done=ConnectDone1,
                          metrics_nodes=MetricsNodes1,
                          start_time=T1}};

handle_cast({sim_done, NodeName},
            #state{sim_done=SimDone0,
                   metrics_nodes=MetricsNodes}=State) ->

    lager:info("Received SIM DONE from ~p", [NodeName]),

    SimDone1 = ordsets:add_element(NodeName, SimDone0),

    case ordsets:size(SimDone1) == node_number() of
        true ->
            lager:info("Everyone is SIM DONE. METRICS GO to ~p!", [MetricsNodes]),
            tell(metrics_go, MetricsNodes);
        false ->
            ok
    end,

    {noreply, State#state{sim_done=SimDone1}};

handle_cast({metrics_done, NodeName},
            #state{metrics_done=MetricsDone0,
                   metrics_nodes=MetricsNodes,
                   start_time=StartTime}=State) ->

    lager:info("Received METRICS DONE from ~p", [NodeName]),

    MetricsDone1 = ordsets:add_element(NodeName, MetricsDone0),

    case ordsets:size(MetricsDone1) == length(MetricsNodes) of
        true ->
            lager:info("Everyone is METRICS DONE. STOP!!!"),
            lsim_simulations_support:push_lsim_metrics(StartTime),
            lsim_orchestration:stop_tasks([lsim, rsg]);
        false ->
            ok
    end,

    {noreply, State#state{metrics_done=MetricsDone1}};

handle_cast(Msg, State) ->
    lager:warning("Unhandled cast message: ~p", [Msg]),
    {noreply, State}.

handle_info(create_barrier, State) ->
    Nodes = lsim_orchestration:get_tasks(lsim, ?BARRIER_PORT, true),

    case length(Nodes) == node_number() of
        true ->
            ok = connect(Nodes);
        false ->
            schedule_create_barrier()
    end,
    {noreply, State#state{nodes=Nodes}};

handle_info(break_link, #state{metrics_nodes=MetricsNodes}=State) ->
    lager:info("BREAK LINK ~p", [MetricsNodes]),
    tell(break_link, MetricsNodes),
    schedule_heal_link(),
    {noreply, State};

handle_info(heal_link, #state{metrics_nodes=MetricsNodes}=State) ->
    lager:info("HEAL LINK"),
    tell(heal_link, MetricsNodes),
    {noreply, State};

handle_info(Msg, State) ->
    lager:warning("Unhandled info message: ~p", [Msg]),
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% @private
configure_break_link_metrics(Nodes) ->
    %% list of nodes from which we want metrics
    %% - in case of break link, only the involved nodes
    %% - otherwise, all
    case lsim_config:get(lsim_break_link) of
        true ->
            Overlay = lsim_config:get(lsim_overlay),
            {{AName, _, _}=A, {BName, _, _}=B} = lsim_overlay:break_link(Nodes, Overlay),

            tell({break_link_info, B}, [AName]),
            tell({break_link_info, A}, [BName]),

            schedule_break_link(),

            [AName, BName];
        false ->
            rsgs()
    end.

%% @private
node_number() ->
    lsim_config:get(lsim_node_number).

%% @private
schedule_create_barrier() ->
    timer:send_after(?INTERVAL, create_barrier).

%% @private
schedule_break_link() ->
    NodeEventNumber = lsim_config:get(lsim_node_event_number),
    %% wait ~50% of simulation time before breaking link
    Seconds = NodeEventNumber div 2,
    timer:send_after(Seconds * 1000, break_link).

%% @private
schedule_heal_link() ->
    NodeEventNumber = lsim_config:get(lsim_node_event_number),
    %% wait ~25% of simulation time before healing
    Seconds = NodeEventNumber div 4,
    timer:send_after(Seconds * 1000, heal_link).

%% @private
connect([]) ->
    ok;
connect([Node|Rest]=All) ->
    case ?BARRIER_PEER_SERVICE:join(Node) of
        ok ->
            connect(Rest);
        Error ->
            lager:info("Couldn't connect to ~p. Reason ~p. Will try again in ~p ms",
                       [Node, Error, ?INTERVAL]),
            timer:sleep(?INTERVAL),
            connect(All)
    end.

%% @private send to all
tell(Msg) ->
    tell(Msg, rsgs()).

%% @private send to some
tell(Msg, Peers) ->
    lists:foreach(
        fun(Peer) ->
            ?BARRIER_PEER_SERVICE:forward_message(
               Peer,
               lsim_rsg,
               Msg
            )
        end,
        Peers
     ).

%% @private
rsgs() ->
    {ok, Members} = ?BARRIER_PEER_SERVICE:members(),
    without_me(Members).

%% @private
without_me(Members) ->
    Members -- [ldb_config:id()].
