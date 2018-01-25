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

-module(lsim_overlay).
-author("Vitor Enes Duarte <vitorenesduarte@gmail.com").

-include("lsim.hrl").

-export([get/2,
         to_connect/3,
         partitions/2]).

%% @doc The first argument can be:
%%          - `hyparview'
%%          - `ring'
%%          - `fullmesh'
%%          - `line'
%%      The second argument is the number of nodes.
-spec get(atom(), pos_integer()) -> orddict:orddict().
get(_, 1) ->
    [];
get(fullmesh, N) ->
    All = lists:seq(0, N - 1),
    lists:foldl(
        fun(I, Acc) ->
            orddict:store(I, All -- [I], Acc)
        end,
        orddict:new(),
        All
    );
get(hyparview, N) ->
    %% In HyParView, everyone connects to a single node.
    lists:foldl(
        fun(I, Acc) ->
            orddict:store(I, [0], Acc)
        end,
        [{0, []}],
        lists:seq(1, N - 1)
    );
get(ring, N) ->
    lists:foldl(
        fun(I, Acc) ->
            Peers = [
                previous(I, N),
                next(I, N)
            ],
            orddict:store(I, Peers, Acc)
        end,
        orddict:new(),
        lists:seq(0, N - 1)
    );
get(line, N) ->
    T0 = get(ring, N),
    First = 0,
    Last = N - 1,
    T1 = lists:keyreplace(
        First,
        1,
        T0,
        {First, [next(First, N)]}
    ),
    T2 = lists:keyreplace(
        Last,
        1,
        T1,
        {Last, [previous(Last, N)]}
    ),
    T2.

%% @doc The first argument is my node spec,
%%      the second argument is a list of node specs,
%%      and the third argument is the overlay.
-spec to_connect(ldb_node_id(), list(node_spec()), atom()) ->
    list(node_spec()).
to_connect(MyName, Nodes, Overlay) ->
    NodeNumber = length(Nodes),

    %% name -> node
    NameToNode = name_to_node_map(Nodes),
    %% {id -> name, id}
    {IdToName, MyId} = id_to_name_map(MyName, NameToNode),
    %% id -> [id]
    Topology = get(Overlay, NodeNumber),

    find_peers(NameToNode, IdToName, MyId, Topology).

%% @doc The first argument is a list of node spec and
%%      the second argument is the number of partitions to create.
%%      Returns a map from partition number to list of ips
%%      that belong to that partition
%%      (and a inversed map for fast lookup).
%%
%%      Assumes ips are unique (as in Kubernetes pods).
-spec partitions(list(node_spec()), pos_integer()) ->
    {orddict:orddict(), orddict:orddict()}.
partitions(Nodes, N) ->
    NodeNumber = length(Nodes),

    %% the last partition may have a different
    %% number of nodes in the partition
    NodesPerPartition = round(NodeNumber / N),

    %% name -> node
    NameToNode = name_to_node_map(Nodes),

    {PToIPs, IPToP, _, _} = lists:foldl(
        fun({_Name, {_, IP, _}}, {PartitionToIPs0,
                                  IPToPartition0,
                                  Partition0,
                                  Added0}) ->

            PartitionToIPs = orddict:append(Partition0, IP, PartitionToIPs0),
            IPToPartition = orddict:store(IP, Partition0, IPToPartition0),

            ShouldNextPartition = Added0 + 1 == NodesPerPartition
                     andalso Partition0 + 1 < N,

            {Partition, Added} = case ShouldNextPartition of
                true ->
                    {Partition0 + 1, 0};
                false ->
                    {Partition0, Added0 + 1}
            end,

            {PartitionToIPs,
             IPToPartition,
             Partition,
             Added}

        end,
        {orddict:new(), orddict:new(), 0, 0},
        NameToNode
    ),

    {PToIPs, IPToP}.

%% @private
previous(I, N) ->
    First = 0,
    case I of
        First ->
            N - 1;
        _ ->
            I - 1
    end.

%% @private
next(I, N) ->
    Last = N - 1,
    case I of
        Last ->
            0;
        _ ->
            I + 1
    end.

%% @private
name_to_node_map(Nodes) ->
    lists:foldl(
        fun({Name, _, _}=Node, Acc) ->
            orddict:store(Name, Node, Acc)
        end,
        orddict:new(),
        Nodes
    ).

%% @private
id_to_name_map(MyName, NameToNode) ->
    {IdToName, MyId, _} = lists:foldl(
        fun({Name, _}, {IdToName0, MyId0, Counter0}) ->
            IdToName1 = orddict:store(Counter0, Name, IdToName0),
            MyId1 = case MyName == Name of
                true ->
                    Counter0;
                false ->
                    MyId0
            end,
            Counter1 = Counter0 + 1,
            {IdToName1, MyId1, Counter1}
        end,
        {orddict:new(), undefined, 0},
        NameToNode
    ),

    {IdToName, MyId}.

%% @private
find_peers(NameToNode, IdToName, MyId, Topology) ->
    %% [id]
    IdsToConnect = orddict:fetch(MyId, Topology),

    %% [node]
    lists:map(
        fun(PeerId) ->
            PeerName = orddict:fetch(PeerId, IdToName),
            orddict:fetch(PeerName, NameToNode)
        end,
        IdsToConnect
    ).
