%%
%% Copyright (c) 2018 Vitor Enes.  All Rights Reserved.
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

-module(exp_kube_orchestration).
-author("Vitor Enes <vitorenesduarte@gmail.com").

-include("exp.hrl").

-behaviour(exp_orchestration).

-export([get_tasks/3,
         stop_tasks/1]).

-spec get_tasks(atom(), node_port(), boolean()) -> [node_spec()].
get_tasks(Tag, Port, FilterByTimestamp) ->
    Path = pods_path() ++ selector(Tag, FilterByTimestamp),
    case http(get, Path) of
        {ok, Nodes} ->
            generate_nodes(Nodes, Port);
        {error, invalid} ->
            []
    end.

-spec stop_tasks([atom()]) -> ok.
stop_tasks(Tags) ->
    lists:foreach(
        fun(Tag) ->
            ok = delete_task(Tag)
        end,
        Tags
    ),
    ok.

%% @private
delete_task(Tag) ->
    Path = deploy_path() ++ "/" ++ name(Tag),

    Result = case http(get, Path) of
        {ok, Body0} ->
            Body1 = set_replicas_as_zero(Body0),
            PR = http(put, Path, Body1),
            DR = http(delete, Path),
            case {PR, DR} of
                {{ok, _}, {ok, _}} ->
                    ok;
                _ ->
                    error
            end;
        {error, invalid} ->
            error
    end,

    case Result of
        ok ->
            ok;
        error ->
            lager:info("Delete failed. Trying again in 1 second"),
            timer:sleep(1000),
            delete_task(Tag)
    end.

%% @private
http(Method, Path) ->
    URL = server() ++ Path,
    Headers = headers(),
    run_http(Method, {URL, Headers}).

%% @private
http(Method, Path, Body0) ->
    URL = server() ++ Path,
    Headers = headers(),
    ContentType = "application/json",
    Body1 = binary_to_list(ldb_json:encode(Body0)),
    run_http(Method, {URL, Headers, ContentType, Body1}).

%% @private
run_http(Method, Request) ->
    Options = [{body_format, binary}],

    case httpc:request(Method, Request, [], Options) of
        {ok, {{_, 200, _}, _, Body}} ->
            {ok, ldb_json:decode(Body)};
        {error, Reason} ->
            lager:info("Couldn't process ~p request. Reason ~p",
                       [Method, Reason]),
            {error, invalid}
    end.

%% @private
headers() ->
    Token = exp_config:get(exp_token),
    [{"Authorization", "Bearer " ++ Token}].

%% @private
server() ->
    exp_config:get(exp_api_server).

%% @private
timestamp() ->
    integer_to_list(exp_config:get(exp_timestamp)).

%% @private
pods_path() ->
    "/api/v1/pods".

%% @private
selector(Tag, FilterByTimestamp) ->
    Selector = "?labelSelector=" ++ "tag%3D" ++ atom_to_list(Tag),

    case FilterByTimestamp of
        true ->
            Selector ++ ",timestamp%3D" ++ timestamp();
        false ->
            Selector
    end.

%% @private
name(Tag) ->
    atom_to_list(Tag) ++ "-" ++ timestamp().

%% @private
prefix() ->
    "/apis/extensions/v1beta1/namespaces/default".

%% @private
deploy_path() ->
    prefix() ++ "/deployments".

%% @private
generate_nodes(Map, Port) ->
    Items = maps:get(items, Map),
    lists:foldl(
        fun(Item, Nodes) ->
            %% find ip
            Status = maps:get(status, Item),

            case maps:is_key(podIP, Status) of
                true ->
                    IP = binary_to_list(
                        maps:get(podIP, Status)
                    ),
                    Node = exp_util:generate_spec(IP, Port),
                    [Node | Nodes];
                false ->
                    Nodes
            end
        end,
        [],
        Items
    ).

%% @private
set_replicas_as_zero(Map) ->
    Spec0 = maps:get(spec, Map),
    Spec1 = maps:put(replicas, 0, Spec0),
    maps:put(spec, Spec1, Map).
