-module(dnf_ty_variable).

-compile([export_all, nowarn_export_all]).

-define(ATOM, ty_variable).
-define(LEAF, ty_rec).
% -define(NODE, ty_node).

-include("dnf/bdd.hrl").

-type type() :: any(). % TODO
% -spec function(ty_function()) -> dnf_ty_function().
% function(TyFunction) -> node(TyFunction).

% -> {boolean(), local_cache()}.
is_empty_line({AllPos, Neg, T}, ST) ->
  case {AllPos, Neg, ?LEAF:empty()} of
    {_, _, T} -> {true, ST};
    {[], [], _} ->
      ?LEAF:is_empty(T, ST);
    {Ps, Ns, _} ->
      error({todo_var_emptyness, {Ps, Ns, T}})
  end.

% helper constructors (used by ty_parser)
atom(DnfTyAtom) -> leaf(ty_rec:atom(DnfTyAtom)).
interval(DnfTyInterval) -> leaf(ty_rec:interval(DnfTyInterval)).
functions(DnfTyFunctions) -> leaf(ty_rec:functions(DnfTyFunctions)).
tuples(DnfTyTuples) -> leaf(ty_rec:tuples(DnfTyTuples)).
list(DnfTyList) -> leaf(ty_rec:list(DnfTyList)).
predefined(DnfTyPredef) -> leaf(ty_rec:predefined(DnfTyPredef)).