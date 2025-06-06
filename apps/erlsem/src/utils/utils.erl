-module(utils).

-compile([export_all, nowarn_export_all]).

-spec compare (fun((T, T) -> lt | gt | eq), [T], [T]) -> lt | gt | eq.
compare(_Cmp, [], []) -> eq;
compare(Cmp, [T1 | Ts1], [T2 | Ts2]) ->
  case Cmp(T1, T2) of
    eq -> compare(Cmp, Ts1, Ts2);
    R -> R
  end.

% -spec equal (fun((T, T) -> boolean()), [T], [T]) -> boolean().
% equal(_Eq, [], []) -> eg;
% equal(Eq, [T1 | Ts1], [T2 | Ts2]) ->
%   case Eq(T1, T2) of
%     true -> equal(Eq, Ts1, Ts2);
%     false -> false
%   end.

% -spec everywhere(fun((term()) -> t:opt(term())), T) -> T.
everywhere(F, T) ->
    TransList = fun(L) -> lists:map(fun(X) -> everywhere(F, X) end, L) end,
    case F(T) of
        error ->
            case T of
                X when is_list(X) -> TransList(X);
                X when is_tuple(X) -> list_to_tuple(TransList(tuple_to_list(X)));
                X when is_map(X) -> #{everywhere(F, K) => everywhere(F, V) || K := V <- X};
                X -> X
            end;
        {ok, X} -> X;
        {rec, X} -> F(F, X)
    end.

everything(F, T) ->
    TransList = fun(L) -> lists:flatmap(fun(X) -> everything(F, X) end, L) end,
    case F(T) of
        error ->
            case T of
                X when is_list(X) -> TransList(X);
                X when is_tuple(X) -> TransList(tuple_to_list(X));
                X when is_map(X) -> TransList(maps:to_list(X));
                _ -> []
            end;
        {ok, X} -> [X]
    end.



replace(Term, Mapping) ->
    replace_term(Term, Mapping).

replace_term({node, _} = Ref, Mapping) ->
    case maps:find(Ref, Mapping) of
        {ok, NewTerm} -> NewTerm;
        error -> Ref
    end;
replace_term({local_ref, _} = Ref, Mapping) ->
    case maps:find(Ref, Mapping) of
        {ok, NewTerm} -> NewTerm;
        error -> Ref
    end;
replace_term(Tuple, Mapping) when is_tuple(Tuple) ->
    list_to_tuple([replace_term(Element, Mapping) || Element <- tuple_to_list(Tuple)]);
replace_term([H|T], Mapping) ->
    [replace_term(H, Mapping) | replace_term(T, Mapping)];
replace_term(Map, Mapping) when is_map(Map) ->
    maps:from_list([{replace_term(K, Mapping), replace_term(V, Mapping)} || {K, V} <- maps:to_list(Map)]);
replace_term(Term, _Mapping) ->
    Term.


size(Term) ->
  (erts_debug:size(Term) * 8)/1024.

update_ets_from_map(EtsTable, LocalMap) ->
  % Filter LocalMap to only new/changed entries
  ChangedEntries = maps:fold(
      fun(K, V, Acc) ->
          case ets:lookup(EtsTable, K) of
              [{K, V}] -> Acc;      % Skip unchanged
              _ -> [{K, V} | Acc]   % Collect changes
          end
      end,
      [],
      LocalMap
  ),
  
  % Bulk-insert changes (faster than one-by-one)
  ets:insert(EtsTable, ChangedEntries).


-spec scc(Graph) -> SCCs when
    Graph :: #{term() => [term()]},
    SCCs :: #{term() => term()}.
scc(Graph) ->
    Nodes = maps:keys(Graph),
    lists:foldl(fun(Node, Acc) ->
        case maps:is_key(Node, Acc) of
            true -> Acc;
            false -> dfs(Node, Graph, #{}, Acc, 0)
        end
    end, #{}, Nodes).

dfs(Node, Graph, Path, SCCs, Depth) ->
    Children = maps:get(Node, Graph, []),
    {NewSCCs, Shallowest} = lists:foldl(fun(Child, {AccSCCs, CurrentShallowest}) ->
        case maps:is_key(Child, Path) of
            true ->
                {AccSCCs, shallower_node(CurrentShallowest, Child, Path)};
            false ->
                ChildPath = Path#{Node => Depth},
                ChildSCCs = dfs(Child, Graph, ChildPath, AccSCCs, Depth + 1),
                ChildShallowest = maps:get(Child, ChildSCCs),
                {ChildSCCs, shallower_node(CurrentShallowest, ChildShallowest, Path)}
        end
    end, {SCCs, Node}, Children),
    NewSCCs#{Node => Shallowest}.

shallower_node(Old, Candidate, Path) ->
    case {maps:get(Old, Path, undefined), maps:get(Candidate, Path, undefined)} of
        {_, undefined} -> Old;
        {undefined, _} -> Candidate;
        {DOld, DCand} when DCand < DOld -> Candidate;
        _ -> Old
    end.


-spec condense(Graph) -> {SCCs, CondensedGraph} when
    Graph :: #{term() => [term()]},
    SCCs :: #{term() => term()},  % Maps each node to its root (SCC representative)
    CondensedGraph :: #{term() => [term()]}.  % Adjacency list of SCC roots

condense(Graph) ->
  % First find SCCs using your implementation
  SCCs = scc(Graph),
  
  % Build a mapping from each node to its root (SCC representative)
  Roots = SCCs,
  
  % Get all unique SCC roots
  AllRoots = lists:usort(maps:values(Roots)),
  
  % Initialize the condensed graph with all roots (even those with no edges)
  BaseGraph = maps:from_list([{Root, []} || Root <- AllRoots]),
  
  % Build the condensed graph by:
  % 1. Collecting all edges between different SCCs
  % 2. Avoiding duplicate edges
  CondensedGraph = maps:fold(
      fun(Node, Neighbors, Acc) ->
          Root = maps:get(Node, Roots),
          lists:foldl(
              fun(Neighbor, InnerAcc) ->
                  NeighborRoot = maps:get(Neighbor, Roots),
                  case Root =/= NeighborRoot of
                      true ->
                          % Add edge from Root to NeighborRoot if not already present
                          CurrentEdges = maps:get(Root, InnerAcc),
                          case lists:member(NeighborRoot, CurrentEdges) of
                              false ->
                                  maps:put(Root, [NeighborRoot | CurrentEdges], InnerAcc);
                              true ->
                                  InnerAcc
                          end;
                      false ->
                          InnerAcc
                  end
              end,
              Acc,
              Neighbors
          )
      end,
      BaseGraph,  % Start with all roots already included
      Graph
  ),
  
  {Roots, CondensedGraph}.


dfs(Graph) ->
    Nodes = maps:keys(Graph),
    Visited = sets:new(),
    {Order, _} = lists:foldl(
        fun(Node, {Acc, VisitedSet}) ->
            case sets:is_element(Node, VisitedSet) of
                false ->
                    {NewAcc, NewVisited} = dfs_visit(Graph, Node, Acc, VisitedSet),
                    {NewAcc, NewVisited};
                true ->
                    {Acc, VisitedSet}
            end
        end,
        {[], Visited},
        Nodes
    ),
    lists:reverse(Order).

dfs_visit(Graph, Node, Acc, VisitedSet) ->
    NewVisited = sets:add_element(Node, VisitedSet),
    Neighbors = maps:get(Node, Graph, []),
    {NewAcc, FinalVisited} = lists:foldl(
        fun(Neighbor, {CurrentAcc, CurrentVisited}) ->
            case sets:is_element(Neighbor, CurrentVisited) of
                false ->
                    dfs_visit(Graph, Neighbor, CurrentAcc, CurrentVisited);
                true ->
                    {CurrentAcc, CurrentVisited}
            end
        end,
        {Acc, NewVisited},
        Neighbors
    ),
    {[Node | NewAcc], FinalVisited}.

revert_map(OriginalMap) ->
    maps:fold(fun(Key, Values, Acc) ->
        lists:foldl(fun(Value, InnerAcc) ->
            maps:put(Value, Key, InnerAcc)
        end, Acc, Values)
    end, #{}, OriginalMap).

reverse_graph(Graph) ->
    Keys = maps:keys(Graph),
    lists:foldl(
        fun(Key, Acc) ->
            case maps:get(Key, Graph) of
                [] -> Acc;  % No need to process nodes with no edges
                Values -> 
                    lists:foldl(
                        fun(Value, InnerAcc) ->
                            case maps:get(Value, InnerAcc, []) of
                                Existing -> InnerAcc#{Value => [Key | Existing]}
                            end
                        end,
                        Acc,
                        Values
                    )
            end
        end,
        #{K => [] || K <- Keys},  % Initialize with all keys pointing to empty lists
        Keys
    ).


map_with_context(Fun, List) ->
    map_with_context(Fun, List, []).

map_with_context(_Fun, [], Acc) ->
    lists:reverse(Acc);
map_with_context(Fun, [H|T], Acc) ->
    {Result, NewT} = Fun({H, T}),
    map_with_context(Fun, NewT, [Result|Acc]).


fold_with_context(_Fun, Acc, []) ->
    Acc;
fold_with_context(Fun, Acc, [H|T]) ->
    {NewAcc, NewT} = Fun({Acc, H, T}),
    fold_with_context(Fun, NewAcc, NewT).