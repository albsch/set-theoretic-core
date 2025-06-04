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
        {ok, X} -> X
    end.

replace(Term, Mapping) ->
    replace_term(Term, Mapping).

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