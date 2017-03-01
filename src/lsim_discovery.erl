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

-module(lsim_discovery).
-author("Vitor Enes Duarte <vitorenesduarte@gmail.com").

-include("lsim.hrl").

-export([nodes/0]).

%% @doc Returns the specs of the running nodes.
-callback nodes() -> [node_spec()].

-spec nodes() -> [node_spec()].
nodes() ->
    do(nodes, []).

%% @private
do(Function, Args) ->
    Orchestration = lsim_config:get(lsim_orchestration),
    case Orchestration of
        kubernetes ->
            erlang:apply(lsim_kube_discovery, Function, Args)
    end.