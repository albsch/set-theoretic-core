-module(dnf_ty_atom).

equal({_, finite},{_, cofinite}) -> false;
equal({_, cofinite},{_, finite}) -> false;
equal({S, _}, {T, _}) -> gb_sets:is_subset(S,T) andalso gb_sets:is_subset(T,S).

compare(R1, R2) -> case R1 < R2 of true -> -1; _ -> case R1 > R2 of true -> 1; _ -> 0 end end.

empty() -> {{0, nil}, finite}.
any() -> {{0, nil}, cofinite}.

finite([]) -> any();
finite([X | Xs]) -> intersect({gb_sets:from_list([X]), finite}, finite(Xs)).

cofinite(ListOfBasic) -> {gb_sets:from_list(ListOfBasic), cofinite}.

negate({S, finite}) -> {S, cofinite};
negate({S, cofinite}) -> {S, finite}.

intersect(_, Z = {{0, nil}, finite}) -> Z;
intersect(Z = {{0, nil}, finite}, _) -> Z;
intersect({{0, nil}, cofinite}, S) -> S;
intersect(S, {{0, nil}, cofinite}) -> S;
intersect(S = {_, cofinite}, T = {_, finite}) -> intersect(T, S);
intersect({S, finite}, {T, finite}) ->
  {gb_sets:intersection(S, T), finite};
intersect({S, finite}, {T, cofinite}) ->
  {gb_sets:difference(S, T), finite};
intersect({S, cofinite}, {T, cofinite}) ->
  {gb_sets:union(S,T), cofinite}.

union(S,T) -> negate(intersect(negate(S), negate(T))).

difference(S,T) -> intersect(S, negate(T)).

is_empty(Rep, ST) ->
  case Rep of
    {{0, nil}, finite} -> {true, ST};
    _ -> {false, ST}
  end.

is_any(Rep) ->
  case Rep of
    {{0, nil}, cofinite} -> true;
    _ -> false
  end.


% normalize_corec(TyAtom, [], [], _Fixed, _) ->
%   % Fig. 3 Line 3
%   case is_empty(TyAtom) of
%     true -> [[]];
%     false -> []
%   end;
% normalize_corec(TyAtom, PVar, NVar, Fixed, M) ->
%   Ty = ty_rec:atom(dnf_var_ty_atom:ty_atom(TyAtom)),
%   % ntlv rule
%   ty_variable:normalize_corec(Ty, PVar, NVar, Fixed, fun(Var) -> ty_rec:atom(dnf_var_ty_atom:var(Var)) end, M).


