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

-module(lsim_simulations).
-author("Vitor Enes Duarte <vitorenesduarte@gmail.com").

-include("lsim.hrl").

%% lsim_simulations callbacks
-export([get_specs/1]).

%% @doc
-spec get_specs(atom()) -> [term()].
get_specs(Simulation) ->
    case Simulation of
        undefined ->
            [];
        basic ->
            StartFun = fun() ->
                ldb:create("SET", gset)
            end,
            EventFun = fun(EventNumber) ->
                Element = atom_to_list(node()) ++
                          integer_to_list(EventNumber),
                ldb:update("SET", {add, Element})
            end,
            TotalEventsFun = fun() ->
                {ok, Value} = ldb:query("SET"),
                sets:size(Value)
            end,
            create_spec(StartFun,
                        EventFun,
                        TotalEventsFun)
    end.

%% @private
create_spec(StartFun, EventFun, TotalEventsFun) ->
    [{lsim_simulation_runner,
      {lsim_simulation_runner, start_link,
       [StartFun,
        EventFun,
        TotalEventsFun]},
      permanent, 5000, worker, [lsim_simulation_runner]}].