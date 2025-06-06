-module(ty_node).

-compile([export_all, nowarn_export_all]).

-export_type([local_cache/0]).

-behaviour(global_state).

-define(ID, ty_node_id).
-define(SYSTEM, ty_node_system).
-define(UNIQUETABLE, ty_record_to_node).
-define(P, ty_node_p).
-define(N, ty_node_n).
-define(ALL_ETS, [?ID, ?SYSTEM, ?P, ?N, ?UNIQUETABLE]).
-define(TY, dnf_ty_variable).

-spec init() -> _.
init() ->
  case ets:whereis(?ID) of
      undefined -> 
        [ets:new(T, [set, named_table]) || T <- ?ALL_ETS],
        ets:insert(?ID, {id, 0});
      _ -> 
        ok % cleanup()
  end,
  % io:format(user, "ty_node state initialized~n", []).
  ok.

-spec clean() -> _.
clean() ->
  case ets:whereis(?ID) of
      undefined -> ok;
      _ -> 
        [ets:delete(T) || T <- ?ALL_ETS]
  end.

% -record(ty_node, {id :: integer(), definition :: term()}).
-type type() :: any(). %TODO
-opaque local_cache() :: #{}. % TODO type cache is only allowed to be inspected in this module

compare({node, Id1}, {node, Id2}) when Id1 < Id2 -> lt;
compare({node, Id1}, {node, Id2}) when Id1 > Id2 -> gt;
compare({node, _Id1}, {node, _Id2}) -> eq;
% this is an architecture hack;
% ty_rec is used differently in ty_parser with local references
% ty_node has to support comparing these local temporary references
compare({local_ref, Id1}, {local_ref, Id2}) when Id1 < Id2 -> lt;
compare({local_ref, Id1}, {local_ref, Id2}) when Id1 > Id2 -> gt;
compare({local_ref, _Id1}, {local_ref, _Id2}) -> eq;
compare({local_ref, _}, {node, _}) -> lt;
compare({node, _}, {local_ref, _}) -> gt.

make(Ty) ->
  Res = ets:lookup(?UNIQUETABLE, Ty),
  case Res of
    [{_, Ref}] -> Ref;
    _ -> define(new_ty_node(), Ty)
  end.

is_consed(Ty) ->
  Res = ets:lookup(?UNIQUETABLE, Ty),
  case Res of
    [{Ty, Node}] -> {true, Node};
    _ -> false
  end.

is_defined(Node) ->
  Res = ets:lookup(?SYSTEM, Node),
  case Res of
    [{_, _}] -> true;
    _ -> false
  end.

new_ty_node() ->
  {node, next_id()}.

define(Reference, Node) ->
  [] = ets:lookup(?SYSTEM, Reference),
  [] = ets:lookup(?UNIQUETABLE, {Node, Reference}),
  ets:insert(?SYSTEM, {Reference, Node}),
  ets:insert(?UNIQUETABLE, {Node, Reference}),
  Reference.

next_id() ->
  NextId = ets:update_counter(?ID, id, 1),
  NextId.

load(TyNode) ->
  [{TyNode, Ty}] = ets:lookup(?SYSTEM, TyNode),
  Ty.
  
leq(T1, T2) ->
  is_empty(difference(T1, T2)).

leq(T1, T2, Cache) ->
  is_empty(difference(T1, T2), Cache).

-spec is_empty(type()) -> boolean().
is_empty(TyNode) ->
  % TODO update global cache with local cache entries
  {Result, _LocalCache} = is_empty(TyNode, #{}),
  Result.

% see Frisch PhD thesis
% TODO merge P and N into one ETS table
% TODO implement backtracking-free algorithm
-spec is_empty(type(), local_cache()) -> {boolean(), local_cache()}.
is_empty(TyNode, LocalCache) ->
  % (#{p := P, n := N}) = global_state:get_state(?MODULE), % TODO measure if it is enough to check only at the start of the chain
  Ty = load(TyNode),

  case {{ok, ok}, LocalCache} of
    % {{#{Ty := false}, _}, _} -> 
    %   io:format(user,"X", []),
    %   {false, LocalCache}; % global cache hit
    % {{_, #{Ty := true}}, _} -> 
    %   io:format(user,"X", []),
    %   {true, LocalCache}; % global cache hit
    {{_, _}, #{Ty := Res}} -> 
      % local cache hit
      {Res, LocalCache};
    _ -> 
      % assume type is empty and add to state
      % N U {t}
      {Result, LC_0} = ?TY:is_empty(Ty, LocalCache#{Ty => true}),

      case Result of 
        % empty; 
        % local cache can be kept as is 
        % Ty is empty is now cached, and all intermediate results are also cached
        true -> 
          {true, LC_0};

        % not empty;
        % invalidate all types that were assumed to be empty
        %  => recover initial N
        % and add Ty to be non-empty to the cache
        % we don't need to backtrack (there is no single global cache), 
        % use the LocalCache from the arguments
        false -> 
          {false, LocalCache}
      end
  end.

negate(T) ->
  make(?TY:negate(load(T))).

intersect(T1, T2) ->
  % io:format(user, "~p~n", [load(T1)]),
  % io:format(user, "~p~n", [load(T2)]),
  make(?TY:intersect(load(T1), load(T2))).

union(T1, T2) ->
  make(?TY:union(load(T1), load(T2))).

difference(T1, T2) ->
  make(?TY:difference(load(T1), load(T2))).

any() ->
  make(?TY:any()).

empty() ->
  make(?TY:empty()).

disjunction(Nodes) ->
  lists:foldl(fun(E, Acc) -> union(E, Acc) end, empty(), Nodes).

conjunction(Nodes) ->
  lists:foldl(fun(E, Acc) -> intersect(E, Acc) end, any(), Nodes).

dump(Ty) ->
  do_dump([Ty], #{}).

do_dump([], Res) -> Res;
do_dump([Ty | T], Res) ->
  case maps:is_key(Ty, Res) of
    true -> do_dump(T, Res);
    false -> 
      Rec = load(Ty),
      MoreTys = utils:everything(
        fun(E = {node, _}) -> {ok, E};(_) -> error end,
        Rec
      ),
      do_dump(T ++ MoreTys, Res#{Ty => Rec})
  end.