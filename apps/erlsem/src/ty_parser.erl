-module(ty_parser).

-compile([export_all, nowarn_export_all]).

-define(SYMTAB, ty_parser_symtab).
-define(TERMREFS, ty_parser_term_references).
-define(UNIFY, ty_parser_unify).
-define(CACHE, ty_parser_cache).
-define(REFTOTY, ty_parser_ref_to_ty).
-define(TYTOREF, ty_parser_ty_to_ref).
-define(ALL_ETS, [?TERMREFS, ?UNIFY, ?CACHE, ?REFTOTY, ?TYTOREF, ?SYMTAB]).

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
  LocalRef = new_local_ref(Ty),

  % if parsed and unified already, return
  case ets:lookup(?UNIFY, LocalRef) of
    [{LocalRef, ReplacedRef}] -> 
      ReplacedRef;
    _ ->
      % 0. local snapshot of state
      RefToTy = maps:from_list(ets:tab2list(?REFTOTY)),
      TyToRef = maps:from_list(ets:tab2list(?TYTOREF)),
      Cache = maps:from_list(ets:tab2list(?CACHE)),

      % 1. Convert to temporary local representation
      %    Create a temporary type equation with a first entrypoint LocalRef = ...
      %    and parse the type layer by layer
      %    use local type references stored in a local map
      ({Result = {NewR,NewTUnsorted}, NewCache}) = convert(queue:from_list([{LocalRef, Ty}]), {RefToTy, TyToRef}, Cache),
      NewT = #{K => lists:usort(V) || K := V <- NewTUnsorted},
      
      % 2. Unify the results
      %    There can be many duplicate type references;
      %    these will be substituted with their representative
      % update global ref, ty mapping, and cache
      utils:update_ets_from_map(?REFTOTY, NewR),
      utils:update_ets_from_map(?TYTOREF, NewT),
      utils:update_ets_from_map(?CACHE, NewCache),

      % 2.1 unify
      {UnifiedRef, UnifiedResult} = unify(LocalRef, Result),

      % 2.2 create new type references and replace temporary ones
      %     return result reference
      ReplaceRefs = maps:from_list([{Ref, ty_node:new_ty_node()} || Ref <- maps:keys(UnifiedResult)]),
      {ReplacedRef, ReplacedResults} = replace_all({UnifiedRef, UnifiedResult}, ReplaceRefs),

      % 2.3 define types
      [ty_node:define(Ref, ToDefineTy) || Ref := ToDefineTy <- ReplacedResults],

      % 2.4 save unify result
      ets:insert(?UNIFY, {LocalRef, ReplacedRef}),
      
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
      % io:format(user, "Cache hit for parse: ~p~n~p -> ~p~n", [Ref, NewRef, Ty]),
      {Ty, Q, R, Cache};
    _ ->
      % find ty in global table
      % io:format(user,"Lookup: ~p~n", [Ref]),
      ({ty_scheme, [], Ty}) = lookup_ty(Ref),

      % TODO apply args to ty scheme
      % Map = subst:from_list(lists:zip([V || {V, _Bound} <- Vars], Args)),
      % NewTy = subst:apply(Map, Ty, no_clean),
      NewTy = Ty,
      
      % create a new reference (ref args pair) and memoize
      NewRef = new_local_ref(X),

      {InternalTy, NewQ, {R0, R1}, C0} = do_convert({NewTy, R}, Q, Cache#{{Ref, Args} => NewRef}),
      
      {InternalTy, NewQ, {R0#{NewRef => InternalTy}, group(R1, InternalTy, NewRef)}, C0}
  end;
 
% built-ins
do_convert({{predef, any}, R}, Q, Cache) -> {ty_rec:any(), Q, R, Cache};
do_convert({{predef, none}, R}, Q, Cache) -> {ty_rec:empty(), Q, R, Cache};

% boolean operators
do_convert({{union, []}, R}, Q, Cache) -> {ty_rec:empty(), Q, R, Cache};
do_convert({{union, [A]}, R}, Q, Cache) -> do_convert({A, R}, Q, Cache);
do_convert({{union, [A|T]}, R}, Q, Cache) -> 
  {R1, Q1, RR1, C1} = do_convert({A, R}, Q, Cache),
  {R2, Q2, RR2, C2} = do_convert({{union, T}, RR1}, Q1, C1),
  {ty_rec:union(R1, R2), Q2, RR2, C2};

do_convert({{intersection, []}, R}, Q, Cache) -> {ty_rec:any(), Q, R, Cache};
do_convert({{intersection, [A]}, R}, Q, Cache) -> do_convert({A, R}, Q, Cache);
do_convert({{intersection, [A|T]}, R}, Q, Cache) -> 
  {R1, Q1, RR0, C0} = do_convert({A, R}, Q, Cache),
  {R2, Q2, RR1, C1} = do_convert({{intersection, T}, RR0}, Q1, C0),
  {ty_rec:intersect(R1, R2), Q2, RR1, C1};

do_convert({{negation, Ty}, R}, Q, Cache) -> 
  {NewR, Q0, RR0, C0} = do_convert({Ty, R}, Q, Cache),
  {ty_rec:negate(NewR), Q0, RR0, C0};

% functions
do_convert({{fun_full, Comps, Result}, R}, Q, Cache) ->
    {RevETy, Q0} = lists:foldl(
        fun(Element, {Components, OldQ}) ->
            % to be converted later, add to queue
            Id = new_local_ref(Element),
            {[Id | Components], queue:in({Id, Element}, OldQ)}
        end, {[], Q}, Comps),
    ETy = lists:reverse(RevETy),

    % add fun result to queue
    Id = new_local_ref(Result),
    Q1 = queue:in({Id, Result}, Q0),
    
    T = ty_functions:singleton(length(Comps), dnf_ty_function:singleton(ty_function:function(ETy, Id))),
    {ty_rec:functions(T), Q1, R, Cache};

do_convert({{tuple, Comps}, R}, Q, Cache) ->
  {RevETy, Q0} = lists:foldl(
    fun(Element, {Components, OldQ}) ->
      % to be converted later, add to queue
      Id = new_local_ref(Element),
      {[Id | Components], queue:in({Id, Element}, OldQ)}
    end, {[], Q}, Comps),
  ETy = lists:reverse(RevETy),
    
  T = ty_tuples:singleton(length(Comps), dnf_ty_tuple:singleton(ty_tuple:tuple(ETy))),
  {ty_rec:tuples(T), Q0, R, Cache};

do_convert({{singleton, Atom}, R}, Q, Cache) when is_atom(Atom) ->
  TAtom = dnf_ty_atom:finite([Atom]),
  {ty_rec:atom(TAtom), Q, R, Cache};

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


% -spec unify(temporary_ref(), result()) -> {temporary_ref(), #{temporary_ref() => ty_rec()}}.
unify(Ref, {IdToTy, TyToIds}) ->
  % map with references to unify, pick representatives
  ToUnify = maps:to_list(#{K => choose_representative(V) || K := V <- TyToIds, length(V) > 1}), 

  % replace equivalent refs with representative
  {UnifiedRef, {UnifiedIdToTy, _UnifiedTyToIds}} = unify(Ref, {IdToTy, TyToIds}, ToUnify),
  {UnifiedRef, UnifiedIdToTy}.

% -spec choose_representative([temporary_ref()]) -> {temporary_ref(), [temporary_ref()]}.
% in previous versions, named_ref existed, which was picked preferrably. 
% now, we pick the first element
choose_representative([H | T]) -> {H, T}.

unify(Ref, Db, All) ->
  ToReplace = maps:from_list(lists:flatten([[{Single, Represent} || Single <- Dupl ] || {_, {Represent, Dupl}}<- All])),

  utils:everywhere(fun
    (RRef = {X, _}) when X == local_ref; X == mu_ref -> 
      case ToReplace of 
        #{RRef := Representative} -> {ok, Representative};
        _ -> error
      end;
    (_) -> error
  end, {Ref, Db}).