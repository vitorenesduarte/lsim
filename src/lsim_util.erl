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

-module(lsim_util).
-author("Vitor Enes Duarte <vitorenesduarte@gmail.com").

-include("lsim.hrl").

-export([generate_spec/2]).

%% @doc Given an IP string and port string
%%      genenerate the node spec.
-spec generate_spec(list(), list()) -> node_spec().
generate_spec(IpStr, PortStr) ->
    NameStr = "lsim-" ++ PortStr ++ "@" ++ IpStr,

    ParsedName = list_to_atom(NameStr),
    {ok, ParsedIp} = inet_parse:address(IpStr),
    ParsedPort = list_to_integer(PortStr),

    {ParsedName, ParsedIp, ParsedPort}.
