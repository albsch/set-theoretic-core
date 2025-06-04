-module(ty_parser).

-compile([export_all, nowarn_export_all]).

-define(SYMTAB, ty_parser_symtab).
-define(TERMREFS, ty_parser_term_references).
-define(UNIFY, ty_parser_unify).
-define(CACHE, ty_parser_cache).
-define(REFTOTY, ty_parser_ref_to_ty).
-define(TYTOREF, ty_parser_ty_to_ref).
-define(ALL_ETS, [?CACHE, ?SYMTAB, ?TERMREFS]).

-define(TY, dnf_ty_variable).
-define(NODE, ty_node).

% global state
-spec init() -> _.
init() ->
  case ets:whereis(?SYMTAB) of
      undefined -> [ets:new(T, [set, named_table]) || T <- ?ALL_ETS];
      _ -> logger:info("~p state already initialized, skip init", [?MODULE])
  end,
  logger:debug("~p state initialized", [?MODULE]).

-spec clean() -> _.
clean() ->
  case ets:whereis(?SYMTAB) of
      undefined -> logger:info("~p state already deleted, skip clean", [?MODULE]);
      _ -> [ets:delete(T) || T <- ?ALL_ETS]
  end,
  logger:debug("~p state cleaned", [?MODULE]).

-type temporary_ref() :: 
    {local_ref, integer()}. % fresh type references created for the queue

% create an unique type reference
-spec new_local_ref() -> temporary_ref().
new_local_ref() -> {local_ref, erlang:unique_integer()}.

% new_local_ref(Term) -> {local_ref, erlang:phash2(Term)}.
new_local_ref(Term) -> 
  % essentially, this is what we want but is too slow
  % {local_ref, Term}.
  % we can't use hashing, it is fast but leads to collisions
  % {local_ref, erlang:phash2(Term)}.
  % therefore, generate a unique reference and save in a hash table to lookup
  case ets:lookup(?TERMREFS, Term) of
    [{Term, Ref}] -> Ref;
    _ -> 
      ets:insert(?TERMREFS, {Term, UniqueRef = new_local_ref()}),
      UniqueRef
  end.

extend_symtab(Ref, TyScheme) ->
  ets:insert(?SYMTAB, {Ref, TyScheme}).

set_symtab(Symtab) ->
  utils:update_ets_from_map(?SYMTAB, Symtab).

% -spec var_ref(ast:ty_var()) -> temporary_ref().
% var_ref(Var) -> {mu_ref, Var}.

lookup_ty({ty_ref, _, Ref, _}) ->
  [{Ref, {ty_scheme, [], Ty}}] = ets:lookup(?SYMTAB, Ref),
  {ty_scheme, [], Ty}.

% -spec ast_to_erlang_ty(ast:ty(), symtab:t()) -> ty_rec:ty_ref().
parse(Ty) ->
  % create a reference, check if is inside the cache
  LocalRef = new_local_ref(Ty),

  case ets:lookup(?CACHE, LocalRef) of
    [{LocalRef, Node}] -> 
      Node;
    _ ->
      % 1. Convert to temporary local representation
      %    Create a temporary type equation with a first entrypoint LocalRef = ...
      %    and parse the type layer by layer
      %    use local type references stored in a local map
      ({{NewR,NewTUnsorted}, _NewCache}) = convert(queue:from_list([{LocalRef, Ty}]), {_RefToTy = #{}, _TyToRef = #{}}, #{}),
      % can have duplicates, e.g. TODO explain
      NewT = #{K => lists:usort(V) || K := V <- NewTUnsorted},

      % 2. Unify the results
      %    There can be many duplicate type references;
      %    these will be substituted with their representative
      {UnifiedRef, UnifiedResult} = unify(LocalRef, {NewR, NewT}),

      % 3. create new type references and replace temporary ones
      %    return result reference
      ReplaceRefs = maps:from_list([{Ref, ?NODE:new_ty_node()} || Ref <- maps:keys(UnifiedResult)]),
      {ReplacedRef, ReplacedResults} = replace_all({UnifiedRef, UnifiedResult}, ReplaceRefs),

      % 4. define types
      [?NODE:define(Ref, ToDefineTy) || Ref := ToDefineTy <- ReplacedResults],

      % 5. update global cache, there are now old entries to overwrite
      %    this invariant has to be kept up inside do_convert
      %    whenever a new reference is created with new_local_ref(...),
      %    we need to check the global cache if that reference does not already point
      %    to a real node inside the global system
      %    the true = ... check is a sanity check
      [true = ets:insert_new(?CACHE, {LLocalRef, Node}) || LLocalRef := Node <- ReplaceRefs],
      
      ReplacedRef
  end.

replace_all({Ref, All}, Map) ->
  utils:everywhere(fun
    (RRef = {X, _}) when X == local_ref; X == mu_ref ->
      case Map of
        #{RRef := Replace} -> {ok, Replace};
        _ -> error
      end;
    (_) -> error
  end, {Ref, All}).

% -spec group(#{A => list(X)}, A, X) -> #{A := list(X)}.
group(M, Key, Value) ->
  maps:update_with(Key, fun(Group) -> [Value | Group] end, [Value], M).

% -spec convert(queue(), symtab:t(), result()) -> result().
convert(Queue, Res, LocalCache) ->
  case queue:is_empty(Queue) of
    true -> 
      {Res, LocalCache}; 
    _ -> % convert next layer
      {{value, {LocalRef, Ty}}, Q} = queue:out(Queue),
      % sanity: don't convert something that is already in the global system
      [] = ets:lookup(?CACHE, LocalRef),
      {ErlangRecOrLocalRef, NewQ, {R1, R2}, NewCache} = do_convert({Ty, Res}, Q, LocalCache),
      convert(NewQ, {R1#{LocalRef => ErlangRecOrLocalRef}, group(R2, ErlangRecOrLocalRef, LocalRef)}, NewCache)
  end.

% -spec do_convert({ast:ty(), result()}, queue(), symtab:t(), memo()) -> {ty_rec(), queue(), result()}.

% entrypoint for recursion
% named
do_convert({X = {named, _, Ref, Args}, R = {IdTy, _}}, Q, Cache) ->
  case Cache of
    #{{Ref, Args} := NewRef} ->
      #{NewRef := Ty} = IdTy,
      {Ty, Q, R, Cache};
    _ ->
      % find ty in global table
      ({ty_scheme, [], Ty}) = lookup_ty(Ref),

      % TODO apply args to ty scheme
      % Map = subst:from_list(lists:zip([V || {V, _Bound} <- Vars], Args)),
      % NewTy = subst:apply(Map, Ty, no_clean),
      NewTy = Ty,
      
      % create a new reference (ref args pair) and memoize
      NewRef = new_local_ref(X),
      case ets:lookup(?CACHE, NewRef) of 
        [] -> 
          {InternalTy, NewQ, {R0, R1}, C0} = do_convert({NewTy, R}, Q, Cache#{{Ref, Args} => NewRef}),
          {InternalTy, NewQ, {R0#{NewRef => InternalTy}, group(R1, InternalTy, NewRef)}, C0};
        [{NewRef, CachedNode}] -> 
          InternalTy = ty_node:load(CachedNode),
          {InternalTy, Q, R, Cache}
      end
  end;
 
% built-ins
do_convert({{predef, any}, R}, Q, Cache) -> {?TY:any(), Q, R, Cache};
do_convert({{predef, none}, R}, Q, Cache) -> {?TY:empty(), Q, R, Cache};
do_convert({{predef, atom}, R}, Q, Cache) -> {?TY:atom(dnf_ty_atom:any()), Q, R, Cache};
do_convert({{predef, integer}, R}, Q, Cache) -> {?TY:interval(dnf_ty_interval:any()), Q, R, Cache};

% boolean operators
do_convert({{union, []}, R}, Q, Cache) -> {?TY:empty(), Q, R, Cache};
do_convert({{union, [A]}, R}, Q, Cache) -> do_convert({A, R}, Q, Cache);
do_convert({{union, [A|T]}, R}, Q, Cache) -> 
  {R1, Q1, RR1, C1} = do_convert({A, R}, Q, Cache),
  {R2, Q2, RR2, C2} = do_convert({{union, T}, RR1}, Q1, C1),
  {?TY:union(R1, R2), Q2, RR2, C2};

do_convert({{intersection, []}, R}, Q, Cache) -> {?TY:any(), Q, R, Cache};
do_convert({{intersection, [A]}, R}, Q, Cache) -> do_convert({A, R}, Q, Cache);
do_convert({{intersection, [A|T]}, R}, Q, Cache) -> 
  {R1, Q1, RR0, C0} = do_convert({A, R}, Q, Cache),
  {R2, Q2, RR1, C1} = do_convert({{intersection, T}, RR0}, Q1, C0),
  {?TY:intersect(R1, R2), Q2, RR1, C1};

do_convert({{negation, Ty}, R}, Q, Cache) -> 
  {NewR, Q0, RR0, C0} = do_convert({Ty, R}, Q, Cache),
  {?TY:negate(NewR), Q0, RR0, C0};

% functions
do_convert({{fun_full, Comps, Result}, R}, Q, Cache) ->
  {RevETy, Q0} = lists:foldl(
    fun(Element, {Components, OldQ}) ->
      {IdOrNode, QQ} = queue_if_new(Element, OldQ),
      {[IdOrNode | Components], QQ}
   end, {[], Q}, Comps),
  ETy = lists:reverse(RevETy),

  % add fun result to queue
  {IdOrNode, Q1} = queue_if_new(Result, Q0),
    
  T = ty_functions:singleton(length(Comps), dnf_ty_function:singleton(ty_function:function(ETy, IdOrNode))),
  {?TY:functions(T), Q1, R, Cache};

do_convert({{tuple, Comps}, R}, Q, Cache) ->
  {RevETy, Q0} = lists:foldl(
    fun(Element, {Components, OldQ}) ->
      {IdOrNode, QQ} = queue_if_new(Element, OldQ),
      {[IdOrNode | Components], QQ}
    end, {[], Q}, Comps),
  ETy = lists:reverse(RevETy),
    
  T = ty_tuples:singleton(length(Comps), dnf_ty_tuple:singleton(ty_tuple:tuple(ETy))),
  {?TY:tuples(T), Q0, R, Cache};

do_convert({{singleton, Atom}, R}, Q, Cache) when is_atom(Atom) ->
  TAtom = dnf_ty_atom:finite([Atom]),
  {?TY:atom(TAtom), Q, R, Cache};

do_convert({{range, From, To}, R}, Q, Cache) ->
  Int = dnf_ty_interval:interval(From, To),
  {?TY:interval(Int), Q, R, Cache};

do_convert({{predef_alias, Alias}, R}, Q, Cache) ->
  do_convert({expand_predef_alias(Alias), R}, Q, Cache);

do_convert({{list, Ty}, R}, Q, Cache) ->
  do_convert({
  {union, [
    {improper_list, Ty, {empty_list}}, 
    {empty_list}
  ]}, R}, Q, Cache);
do_convert({{nonempty_list, Ty}, R}, Q, Cache) ->
  do_convert({{nonempty_improper_list, Ty, {empty_list}}, R}, Q, Cache);
do_convert({{nonempty_improper_list, Ty, Term}, R}, Q, Cache) ->
  do_convert({{intersection, [{list, Ty}, {negation, Term}]} , R}, Q, Cache);
do_convert({{improper_list, A, B}, R}, Q, Cache) ->
  {T1, Q0} = queue_if_new(A, Q),
  {T2, Q1} = queue_if_new(B, Q0),
    
  {?TY:list(dnf_ty_list:singleton(ty_tuple:tuple([T1, T2]))), Q1, R, Cache};
do_convert({{empty_list}, R}, Q, Cache) ->
  {?TY:predefined(dnf_ty_predefined:predefined('[]')), Q, R, Cache};
do_convert({{predef, T}, R}, Q, Cache) when T == pid; T == port; T == reference; T == float ->
  {?TY:predefined(dnf_ty_predefined:predefined(T)), Q, R, Cache};

% % var
% do_convert({V = {var, A}, R = {IdTy, _}}, Q) ->
%   error(todovar);
%   % % FIXME overloading of mu variables and normal variables
%   % case M of
%   %   #{V := Ref} -> % mu variable
%   %     % io:format(user,"R: ~p~n", [{Ref, R}]),
%   %     #{Ref := Ty} = IdTy,
%   %     % We are allowed to load the memoized ref
%   %     % because the second occurrence of the mu variable
%   %     % is below a type constructor, 
%   %     % i.e. the memoized reference is fully (partially) defined
%   %     {Ty, Q, R};
%   %   _ -> 
%   %     % if this is a special $mu_integer()_name() variable, convert to that representation
%   %     case string:prefix(atom_to_list(A), "$mu_") of 
%   %       nomatch -> 
%   %         {ty_rec:s_variable(ty_variable:new_with_name(A)), Q, R};
%   %       IdName -> 
%   %         % assumption: erlang types generates variables only in this pattern: $mu_integer()_name()
%   %         [Id, Name] = string:split(IdName, "_"),
%   %         {ty_rec:s_variable(ty_variable:new_with_name_and_id(list_to_integer(Id), list_to_atom(Name))), Q, R}
%   %     end
%   % end;

do_convert(T, _Q, _) ->
  erlang:error({"Transformation from ast:ty() to ty_rec:ty() not implemented or malformed type", T}).

queue_if_new(Element, Queue) ->
  Id = new_local_ref(Element),
  case ets:lookup(?CACHE, Id) of
    % to be converted later, add to queue, if not already cached
    [] -> {Id, queue:in({Id, Element}, Queue)};
    % if already known, don't process and add a real reference as part of the tuple components
    [{Id, Node}] -> {Node, Queue}
  end.

% -spec unify(temporary_ref(), result()) -> {temporary_ref(), #{temporary_ref() => ty_rec()}}.
unify(Ref, {IdToTy, TyToIds}) ->
  % map with references to unify, pick representatives
  % in previous versions, named_ref existed, which was picked preferrably as the representative
  % now, we pick the first element
  ToUnify = maps:to_list(#{K => {H, T} || K := (V = [H | T]) <- TyToIds, length(V) > 1}), 

  % replace equivalent refs with representative
  ToReplace = maps:from_list(lists:flatten([[{Single, Represent} || Single <- Dupl ] || {_, {Represent, Dupl}}<- ToUnify])),

  {NewRef, NewDb} = utils:everywhere(fun
    (RRef = {X, _}) when X == local_ref; X == mu_ref -> 
      case ToReplace of 
        #{RRef := Representative} -> {ok, Representative};
        _ -> error
      end;
    (_) -> error
  end, {Ref, IdToTy}),

  {NewRef, NewDb}.


-spec expand_predef_alias(ast:predef_alias_name()) -> ast:ty().
expand_predef_alias(term) -> {predef, any};
% TODO better binaries
expand_predef_alias(binary) -> {bitstring};
expand_predef_alias(nonempty_binary) -> {bitstring};
expand_predef_alias(bitstring) -> {bitstring};
expand_predef_alias(nonempty_bitstring) -> {bitstring};
expand_predef_alias(boolean) -> {union, [{singleton, true}, {singleton, false}]};
expand_predef_alias(byte) -> {range, 0, 255};
expand_predef_alias(char) -> {range, 0, 1114111};
expand_predef_alias(nil) -> {empty_list};
expand_predef_alias(number) -> {union, [{predef, float}, {predef, integer}]};
expand_predef_alias(list) -> {list, {predef, any}};
% also see code in ast_transform for expanding predefined aliases applied to arguments
expand_predef_alias(nonempty_list) -> {nonempty_list, {predef, any}};
expand_predef_alias(maybe_improper_list) -> {improper_list, {predef, any}, {predef, any}};
expand_predef_alias(nonempty_maybe_improper_list) -> {nonempty_list, {predef, any}};
expand_predef_alias(string) -> {list, expand_predef_alias(char)};
expand_predef_alias(nonempty_string) -> {nonempty_list, expand_predef_alias(char)};
expand_predef_alias(iodata) -> {union, [expand_predef_alias(iolist), expand_predef_alias(binary)]};
expand_predef_alias(iolist) ->
    % TODO fix variable IDs
    RecVarID = erlang:unique_integer(),
    Var = {var, erlang:list_to_atom("mu" ++ integer_to_list(RecVarID))},
    RecType = {improper_list, {union, [expand_predef_alias(byte), expand_predef_alias(binary), Var]}, {union, [expand_predef_alias(binary), {empty_list}]}},
    {mu, Var, RecType};
expand_predef_alias(map) -> {map, [{map_field_opt, {predef, any}, {predef, any}}]};
expand_predef_alias(function) -> {fun_simple};
expand_predef_alias(module) -> {predef, atom};
expand_predef_alias(mfa) -> {tuple, [{predef, atom}, {predef, atom}, {predef, integer}]};
expand_predef_alias(arity) -> {predef, integer};
expand_predef_alias(identifier) -> {union, [{predef, pid}, {predef, port}, {predef, reference}]};
expand_predef_alias(node) -> {predef, atom};
expand_predef_alias(timeout) -> {union, [{singleton, infinity}, expand_predef_alias(non_neg_integer)]};
expand_predef_alias(no_return) -> {predef, none};
expand_predef_alias(non_neg_integer) -> {range, 0, '*'};
expand_predef_alias(pos_integer) -> {range, 1, '*'};
expand_predef_alias(neg_integer) -> {range, '*', -1};

expand_predef_alias(Name) ->
    logger:error("Not expanding: ~p", [Name]),
    errors:not_implemented(utils:sformat("expand_predef_alias for ~w", Name)).