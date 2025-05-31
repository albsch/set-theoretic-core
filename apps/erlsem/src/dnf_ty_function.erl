-module(dnf_ty_function).

-compile([export_all, nowarn_export_all]).

-define(ATOM, ty_function).
-define(LEAF, ty_bool).
-define(NODE, ty_node).

-include("dnf/bdd.hrl").

-type type() :: any(). % TODO
% -spec function(ty_function()) -> dnf_ty_function().
% function(TyFunction) -> node(TyFunction).

% leq(T1, T2) ->
%   is_empty(difference(T1, T2)).
 
% -type is_empty(type(), X) :: {boolean(), X}.

% -> {boolean(), local_cache()}.
is_empty_line({AllPos, Neg, T}, ST) ->
  case {AllPos, Neg, ?LEAF:empty()} of
    {_, _, T} -> {true, ST};
    {Ps, Ns, _} ->
      % continue searching for any arrow ∈ N such that the line becomes empty
      lists:foldl(
        fun
          (_NegatedFun, {true, ST0}) -> {true, ST0}; 
          (NegatedFun, {false, ST0}) -> is_empty_cont(Ps, NegatedFun, ST0) 
        end, 
        {false, ST}, 
        Ns
      )
  end.

% -> {boolean(), local_cache()}.
is_empty_cont(Ps, NegatedFun, ST0) ->
  %% ∃ Ts-->T2 ∈ N s.t.
  %%    Ts is in the domains of the function
  T1 = ty_function:domain(NegatedFun),

  AllDomains = lists:map(fun ty_function:domain/1, Ps),
  Disj = ?NODE:disjunction(AllDomains),
  maybe 
    {true, ST1} ?= ?NODE:leq(T1, Disj, ST0),
    NegatedCodomain = ?NODE:negate(ty_function:codomain(NegatedFun)),
    explore_function(T1, NegatedCodomain, Ps, ST1)
  end.

% optimized phi' (4.10) from paper covariance and contravariance
% justification for this version of phi can be found in `prop_phi_function.erl`
%-spec explore_function(ty_ref(), ty_ref(), [term()]) -> boolean().
explore_function(_T1, _T2, [], ST) ->
  {true, ST};
explore_function(T1, T2, [Function | Ps], ST0) ->
  {S1, S2} = {ty_function:domain(Function), ty_function:codomain(Function)},
  maybe 
    {true, ST1} ?= phi(T1, ?NODE:intersect(T2, S2), Ps, ST0),
    phi(?NODE:difference(T1, S1), T2, Ps, ST1)
  end.

phi(T1, T2, [], ST0) ->
  maybe
    {false, ST1} ?= ?NODE:is_empty(T1, ST0),
    ?NODE:is_empty(T2, ST1)
  end;
phi(T1, T2, [Function | Ps], ST0) ->
  {S1, S2} = {ty_function:domain(Function), ty_function:codomain(Function)},
  maybe 
    {false, ST1} ?= ?NODE:is_empty(T1, ST0),
    {false, ST2} ?= ?NODE:is_empty(T2, ST1),
    maybe
      {true, ST4} ?= maybe
        {false, ST3} ?= ?NODE:leq(T1, S1, ST2),
        Codomains = lists:map(fun ty_function:codomain/1, Ps),
        Conj = ?NODE:conjunction(Codomains),
        ?NODE:leq(Conj, ?NODE:negate(T2), ST3)
      end,
      {true, ST5} ?= phi(T1, ?NODE:intersect(T2, S2), Ps, ST4),
      phi(?NODE:difference(T1, S1), T2, Ps, ST5)
    end
  end.

% TODO tally
% normalize_corec(_Size, DnfTyFunction, [], [], Fixed, M) ->
%   dnf(DnfTyFunction, {
%     fun(Pos, Neg, DnfTyList) -> normalize_coclause_corec(Pos, Neg, DnfTyList, Fixed, M) end,
%     fun constraint_set:meet/2
%   })
% ;
% normalize_corec(Size, DnfTyFunction, PVar, NVar, Fixed, M) ->
%   Ty = ty_rec:function(Size, dnf_var_ty_function:function(DnfTyFunction)),
%   % ntlv rule
%   ty_variable:normalize_corec(Ty, PVar, NVar, Fixed, fun(Var) -> ty_rec:function(Size, dnf_var_ty_function:var(Var)) end, M).

% normalize_coclause_corec([], [], T, _Fixed, _M) ->
%   case ty_bool:empty() of T -> [[]]; _ -> [] end;
% normalize_coclause_corec(Pos, Neg, T, Fixed, M) ->
%   case ty_bool:empty() of
%     T -> [[]];
%     _ ->
%       [First | _] = Pos ++ Neg,
%       Size = length(ty_function:domains(First)),
%       S = lists:foldl(fun ty_rec:union/2, ty_rec:empty(), [domains_to_tuple(Refs) || {ty_function, Refs, _} <- Pos]),
%       normalize_no_vars_corec(Size, S, Pos, Neg, Fixed, M)
%   end.

% normalize_no_vars_corec(_Size, _, _, [], _Fixed, _) -> []; % non-empty
% normalize_no_vars_corec(Size, S, P, [Function | N], Fixed, M) ->
%   T1 = domains_to_tuple(ty_function:domains(Function)),
%   T2 = ty_function:codomain(Function),
%   %% ∃ T1-->T2 ∈ N s.t.
%   %%   T1 is in the domain of the function
%   %%   S is the union of all domains of the positive function intersections
%   X1 = ?F(ty_rec:normalize_corec(ty_rec:intersect(T1, ty_rec:negate(S)), Fixed, M)),
%   X2 = ?F(explore_function_norm_corec(Size, T1, ty_rec:negate(T2), P, Fixed, M)),
%   R1 = ?F(constraint_set:meet(X1, X2)),
%   %% Continue searching for another arrow ∈ N
%   R2 = ?F(normalize_no_vars_corec(Size, S, P, N, Fixed, M)),
%   constraint_set:join(R1, R2).


% explore_function_norm_corec(_Size, BigT1, T2, [], Fixed, M) ->
%   NT1 = ?F(ty_rec:normalize_corec(BigT1, Fixed, M)),
%   NT2 = ?F(ty_rec:normalize_corec(T2, Fixed, M)),
%   constraint_set:join( NT1, NT2 );
% explore_function_norm_corec(Size, T1, T2, [Function | P], Fixed, M) ->
%   NT1 = ?F(ty_rec:normalize_corec(T1, Fixed, M)),
%   NT2 = ?F(ty_rec:normalize_corec(T2, Fixed, M)),

%   S1 = domains_to_tuple(ty_function:domains(Function)),
%   S2 = ty_function:codomain(Function),

%   NS1 = ?F(explore_function_norm_corec(Size, T1, ty_rec:intersect(T2, S2), P, Fixed, M)),
%   NS2 = ?F(explore_function_norm_corec(Size, ty_rec:diff(T1, S1), T2, P, Fixed, M)),

%   constraint_set:join(NT1,
%     ?F(constraint_set:join(NT2,
%       ?F(constraint_set:meet(NS1, NS2))))).

% apply_to_node(Node, Map, Memo) ->
%   substitute(Node, Map, Memo, fun(N, S, M) -> ty_function:substitute(N, S, M) end).
