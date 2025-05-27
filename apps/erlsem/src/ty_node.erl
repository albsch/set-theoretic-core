-module(ty_node).

-compile([export_all, nowarn_export_all]).

-export_type([local_cache/0]).

-behaviour(global_state).

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
compare({local_ref, _Id1}, {local_ref, _Id2}) -> eq.


make(Ty) ->
  define(new_ty_node(), Ty).

new_ty_node() ->
  {node, next_id()}.

define(Reference, Node) ->
  (S = #{system := System}) = global_state:get_state(?MODULE),
  New = System#{Reference => Node},
  global_state:set_state(?MODULE, S#{system => New}),
  Reference.

-spec init() -> _.
init() ->
  case ets:whereis(?MODULE) of
      undefined -> 
        ets:new(?MODULE, [set, named_table, {keypos, 1}]),
        ets:insert(?MODULE, {state, #{id => 0, system => #{}, p => #{}, n => #{}, s => stack:new()}});
      _ -> 
        ok % cleanup()
  end,
  % io:format(user, "ty_node state initialized~n", []).
  ok.

next_id() ->
  (S = #{id := Id}) = global_state:get_state(?MODULE),
  global_state:set_state(?MODULE, S#{id => Id + 1}),
  Id + 1.

-spec clean() -> _.
clean() ->
  case ets:whereis(?MODULE) of
      undefined -> ok;
      _ -> 
        % io:format(user, "ty_node state removed~n", []),
        ets:delete(?MODULE)
  end.

load(TyNode) ->
  (#{system := #{TyNode := Ty}}) = global_state:get_state(?MODULE),
  Ty.
  
leq(T1, T2) ->
  is_empty(difference(T1, T2)).

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
  (#{p := P, n := N}) = global_state:get_state(?MODULE), % TODO measure if it is enough to check only at the start of the chain
  Ty = load(TyNode),

  case {{P, N}, LocalCache} of
    {{#{Ty := false}, _}, _} -> 
      % io:format(user,"p", []),
      {false, LocalCache}; % global cache hit
    {{_, #{Ty := true}}, _} -> 
      % io:format(user,"n", []),
      {true, LocalCache}; % global cache hit
    {{_, _}, #{Ty := Res}} -> 
      % local cache hit
      {Res, LocalCache};
    _ -> 
      % assume type is empty and add to state
      % N U {t}
      {Result, LC_0} = ty_rec:is_empty(Ty, LocalCache#{Ty => true}),

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
          {false, LocalCache#{Ty => false}}
      end
  end.

negate(T) ->
  make(ty_rec:negate(load(T))).

intersect(T1, T2) ->
  make(ty_rec:intersect(load(T1), load(T2))).

union(T1, T2) ->
  make(ty_rec:union(load(T1), load(T2))).

difference(T1, T2) ->
  make(ty_rec:difference(load(T1), load(T2))).

any() ->
  make(ty_rec:any()).

empty() ->
  make(ty_rec:empty()).

disjunction(Nodes) ->
  lists:foldl(fun(E, Acc) -> union(E, Acc) end, empty(), Nodes).

conjunction(Nodes) ->
  lists:foldl(fun(E, Acc) -> intersect(E, Acc) end, any(), Nodes).