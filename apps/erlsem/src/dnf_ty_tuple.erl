-module(dnf_ty_tuple).

-define(ATOM, ty_tuple).
-define(LEAF, ty_bool).
-define(F(Z), fun() -> Z end).

% -export([is_empty_corec/2, normalize_corec/6, substitute/4, apply_to_node/3]).
% -export([tuple/1, phi_corec/3, phi_norm_corec/5]).

-include("dnf/bdd.hrl").



is_empty_line({AllPos, Neg, T}, ST) ->
  case {AllPos, Neg, ty_bool:empty()} of
    {_, _, T} -> {true, ST};
    {[], [], _} -> {false, ST};
    {[], [TNeg | _], _} ->
      Dim = length(ty_tuple:components(TNeg)),
      PosAny = ty_tuple:any(Dim),
      BigS = ty_tuple:big_intersect([PosAny]),
      phi(ty_tuple:components(BigS), Neg, ST);
    {Pos, Neg, _} ->
      BigS = ty_tuple:big_intersect(Pos),
      phi(ty_tuple:components(BigS), Neg, ST)
  end.

phi(BigS, [], ST) ->
  % TODO how big of a performance hit is non-shortcut behavior of the true branch?
  lists:foldl(
    fun(_, {true, ST0}) -> {true, ST0};
       (S, {false, ST0}) -> ty_rec:is_empty_corec(S, ST0) 
    end, 
    {false, ST}, 
  BigS);
phi(BigS, [Ty | N], ST) ->
  Solve = fun
    (_, {false, ST2}) -> {false, ST2};
    ({Index, {_PComponent, NComponent}}, {true, ST2}) ->
      begin
      % remove pi_Index(NegativeComponents) from pi_Index(PComponents) and continue searching
        DoDiff = fun({IIndex, PComp}) ->
          case IIndex of
            Index -> ty_rec:diff(PComp, NComponent);
            _ -> PComp
          end
                 end,
        NewBigS = lists:map(DoDiff, lists:zip(lists:seq(1, length(BigS)), BigS)),
        phi(NewBigS, N, ST2)
      end
          end,

  maybe
    {false, ST1} ?= lists:foldl(fun(_S, {true, ST0}) -> {true, ST0}; (S, {false, ST0}) -> ty_rec:is_empty_corec(S, ST0) end, {false, ST}, BigS),
    lists:foldl(
      Solve, 
      {true, ST1}, 
      lists:zip(lists:seq(1, length(ty_tuple:components(Ty))), lists:zip(BigS, ty_tuple:components(Ty))))
  end.

% normalize_corec(Size, Ty, [], [], Fixed, M) ->
%   dnf(Ty, {
%     fun
%       ([], [], T) ->
%         case ty_bool:empty() of T -> [[]]; _ -> [] end;
%       ([], Neg = [TNeg | _], T) ->
%         case ty_bool:empty() of
%           T -> [[]];
%           _ ->
%             Dim = length(ty_tuple:components(TNeg)),
%             PosAny = ty_tuple:any(Dim),
%             BigS = ty_tuple:big_intersect([PosAny]),
%             phi_norm_corec(Size, ty_tuple:components(BigS), Neg, Fixed, M)
%         end;
%       (Pos, Neg, T) ->
%         case ty_bool:empty() of
%           T -> [[]];
%           _ ->
%             BigS = ty_tuple:big_intersect(Pos),
%             phi_norm_corec(Size, ty_tuple:components(BigS), Neg, Fixed, M)
%         end
%     end,
%     fun constraint_set:meet/2
%   });
% normalize_corec(Size, DnfTy, PVar, NVar, Fixed, M) ->
%   Ty = ty_rec:tuple(Size, dnf_var_ty_tuple:tuple(DnfTy)),
%   % ntlv rule
%   ty_variable:normalize_corec(Ty, PVar, NVar, Fixed, fun(Var) -> ty_rec:tuple(Size, dnf_var_ty_tuple:var(Var)) end, M).

% phi_norm_corec(_Size, BigS, [], Fixed, M) ->
%   lists:foldl(fun(S, Res) -> constraint_set:join(?F(Res), ?F(ty_rec:normalize_corec(S, Fixed, M))) end, [], BigS);
% phi_norm_corec(Size, BigS, [Ty | N], Fixed, M) ->
%   Solve = fun({Index, {_PComponent, NComponent}}, Result) ->
%     constraint_set:meet(
%       ?F(Result),
%       ?F(begin
%       % remove pi_Index(NegativeComponents) from pi_Index(PComponents) and continue searching
%         DoDiff = fun({IIndex, PComp}) ->
%           case IIndex of
%             Index ->
%               ty_rec:diff(PComp, NComponent);
%             _ -> PComp
%           end
%                  end,
%         NewBigS = lists:map(DoDiff, lists:zip(lists:seq(1, length(BigS)), BigS)),
%         phi_norm_corec(Size, NewBigS, N, Fixed, M)
%       end)
%     )
%           end,

%   constraint_set:join(
%     ?F(lists:foldl(fun(S, Res) -> constraint_set:join(?F(Res), ?F(ty_rec:normalize_corec(S, Fixed, M))) end, [], BigS)),
%     ?F(lists:foldl(Solve, [[]], lists:zip(lists:seq(1, length(ty_tuple:components(Ty))), lists:zip(BigS, ty_tuple:components(Ty)))))
%   ).


% apply_to_node(Node, Map, Memo) ->
%   substitute(Node, Map, Memo, fun(N, S, M) -> ty_tuple:substitute(N, S, M) end).

% -ifdef(TEST).
% -include_lib("eunit/include/eunit.hrl").

% empty_0tuple_test() ->
%   Tuple = {node,{ty_tuple,0,[]},{terminal,0},{terminal,1}},
%   true = is_empty_corec(Tuple, #{}),
%   ok.

% -endif.
