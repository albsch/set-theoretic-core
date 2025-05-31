-ifndef(MULTIARITY).
-define(MULTIARITY, dnf_ty_function).
-endif.

compare(Fs1, Fs2) ->
  error({todo, impl, Fs1, Fs2}).

empty() ->
  {?MULTIARITY:empty(), #{}}.

any() ->
  {?MULTIARITY:any(), #{}}.

is_empty({Default, All}, ST) ->
  maybe
    {false, ST1} ?= ?MULTIARITY:is_empty(Default, ST),
    maps:fold(fun
      (_Size, _V, {false, ST0}) -> {false, ST0};
      (_Size, V, {true, ST0}) -> ?MULTIARITY:is_empty(V, ST0) 
    end, {true, ST1}, All)
  end.

singleton(Length, Dnf) when is_integer(Length) ->
  remove_redundant({?MULTIARITY:empty(), #{Length => Dnf}}).

negate({Default, Ty}) ->
  remove_redundant({?MULTIARITY:negate(Default), maps:map(fun(_K,V) -> ?MULTIARITY:negate(V) end, Ty)}).


union({DefaultF1, F1}, {DefaultF2, F2}) ->
  % get all keys
  AllKeys = maps:keys(F1) ++ maps:keys(F2),
  UnionKey = fun(Key) ->
    ?MULTIARITY:union(
      maps:get(Key, F1, DefaultF1),
      maps:get(Key, F2, DefaultF2)
    )
                 end,
  remove_redundant({?MULTIARITY:union(DefaultF1, DefaultF2), maps:from_list([{Key, UnionKey(Key)} || Key <- AllKeys])}).

intersect({DefaultF1, F1}, {DefaultF2, F2}) ->
  % get all keys
  AllKeys = maps:keys(F1) ++ maps:keys(F2),
  IntersectKey = fun(Key) ->
    ?MULTIARITY:intersect(
      maps:get(Key, F1, DefaultF1),
      maps:get(Key, F2, DefaultF2)
    )
                 end,
  remove_redundant({?MULTIARITY:intersect(DefaultF1, DefaultF2), maps:from_list([{Key, IntersectKey(Key)} || Key <- AllKeys])}).

difference({DefaultF1, F1}, {DefaultF2, F2}) ->
  % get all keys
  AllKeys = maps:keys(F1) ++ maps:keys(F2),
  DifferenceKey = fun(Key) ->
    ?MULTIARITY:difference(
      maps:get(Key, F1, DefaultF1),
      maps:get(Key, F2, DefaultF2)
    )
                 end,
  remove_redundant({?MULTIARITY:difference(DefaultF1, DefaultF2), maps:from_list([{Key, DifferenceKey(Key)} || Key <- AllKeys])}).

% removes mappings in others which are syntactically equivalent to the default value
remove_redundant({Default, Others}) ->
  {
    Default,
    #{Arity => TypeOfArity || Arity := TypeOfArity <- Others, TypeOfArity /= Default}
  }.

% TODO tally
% normalize_corec({Default, AllFunctions}, Fixed, M) ->
%   Others = ?F(
%     maps:fold(fun(Size, V, Acc) ->
%       constraint_set:meet(
%         ?F(Acc),
%         ?F(dnf_var_ty_function:normalize_corec(Size, V, Fixed, M))
%       )
%               end, [[]], AllFunctions)
%   ),

%   DF = ?F(dnf_var_ty_function:normalize_corec({default, maps:keys(AllFunctions)}, Default, Fixed, M)),

%   constraint_set:meet(
%     DF,
%     Others
%   ).


% substitute({DefaultFunction, AllFunctions}, SubstituteMap, Memo) ->
%   % see multi_substitute for comments
%   % TODO refactor abstract into one function for both tuples and funcions
%   NewDefaultFunction = dnf_var_ty_function:substitute(DefaultFunction, SubstituteMap, Memo, fun(Ty) -> ty_rec:pi({function, default}, Ty) end),
%   AllVars = dnf_var_ty_function:all_variables(DefaultFunction),
%   % TODO erlang 26 map comprehensions
%   Keys = maps:fold(fun(K,V,AccIn) -> case lists:member(K, AllVars) of true -> ty_rec:function_keys(V) -- maps:keys(AllFunctions) ++ AccIn; _ -> AccIn end end, [], SubstituteMap),
%   % Keys = [function_keys(V) || K := V <- SubstituteMap, lists:member(K, AllVars)],
%   OtherFunctionKeys = lists:usort(lists:flatten(Keys)),
%   NewDefaultOtherFunctions = maps:from_list([{Length, dnf_var_ty_function:substitute(DefaultFunction, SubstituteMap, Memo, fun(Ty) -> ty_rec:pi({function, Length}, Ty) end)} || Length <- OtherFunctionKeys]),
%   AllKeys = maps:keys(AllFunctions) ++ maps:keys(NewDefaultOtherFunctions),

%   NewOtherFunctions = maps:from_list(lists:map(fun(Key) ->
%     {Key, case maps:is_key(Key, AllFunctions) of
%             true -> dnf_var_ty_function:substitute(maps:get(Key, AllFunctions), SubstituteMap, Memo, fun(Ty) -> ty_rec:pi({function, Key}, Ty) end);
%             _ -> maps:get(Key, NewDefaultOtherFunctions, NewDefaultFunction)
%           end}
%                                             end, AllKeys)),

%   {NewDefaultFunction, NewOtherFunctions}.