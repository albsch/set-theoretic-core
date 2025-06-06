-module(representation_tests).

-include_lib("eunit/include/eunit.hrl").

% {leaf,0},#{1 => {leaf,0}} should simplify to {{leaf,0},#{}}
redundant_default_test() ->
  global_state:with_new_state(fun() ->
    Ty = ty_parser:parse({fun_full, [{predef, any}], {predef, any}}),
    Ty2 = ty_node:negate(Ty),
    Ty3 = ty_node:intersect(Ty, Ty2),
    true = dnf_ty_variable:empty() =:= ty_node:load(Ty3)
  end).

% parser should map sub-structures of a recursive type to the same ID
% across parse passes
share_sub_recursive_types_test() ->
  {ok, [System]} = file:consult("system_rec"),
  global_state:with_new_state(fun() -> 
    maps:foreach(fun({ty_key,ast,VarName,_Arity}, AstTyScheme) -> ty_parser:extend_symtab(VarName, AstTyScheme) end, System),

    Ty = ty_parser:parse({named, {loc,"src/ast.erl",405,30}, {ty_ref, 'ast', ty, 0}, []}),
    Ty2 = ty_parser:parse({named, {loc,"src/ast.erl",415,37}, {ty_ref, 'ast', ty_tuple, 0}, []}),
    true = Ty =:= ty_node:union(Ty, Ty2),
    ok
  end).

share_same_recursive_types_test() ->
  {ok, [System]} = file:consult("system_rec"),
  global_state:with_new_state(fun() -> 
    maps:foreach(fun({ty_key,ast,VarName,_Arity}, AstTyScheme) -> ty_parser:extend_symtab(VarName, AstTyScheme) end, System),

    Ty = ty_parser:parse({named, {loc,"src/ast.erl",405,30}, {ty_ref, 'ast', ty, 0}, []}),
    Ty2 = ty_parser:parse(
      {union, [
        {named, {loc,"src/ast.erl",415,37}, {ty_ref, 'ast', ty, 0}, []}
      ]}
    ),
    true = Ty =:= Ty2,
    ok
  end).

% types parsed to the same structure should be shared
% across parse passes
share_simple_types_test() ->
  global_state:with_new_state(fun() ->
    Ty2 = ty_parser:parse({tuple, [{intersection, [{singleton, foo}]}]}),
    Ty2 = ty_parser:parse({tuple, [{singleton, foo}]}),
    ok
  end).

share_simple_types_2_test() ->
  global_state:with_new_state(fun() ->
    Ty = {tuple, [ {singleton, foo} ]},
    TyParsed = ty_parser:parse(Ty),

    Ty2 = {tuple, [ {union, [{singleton, foo}]} ]},
    TyParsed = ty_parser:parse(Ty2),
    TyParsed = ty_parser:parse(Ty2),
    ok
  end).

share_topological_recursive_types_test() ->
  {ok, [System]} = file:consult("system_topological"),
  global_state:with_new_state(fun() ->
    maps:foreach(fun({ty_key,'.',VarName,_Arity}, AstTyScheme) -> ty_parser:extend_symtab(VarName, AstTyScheme) end, System),

    Ty = {tuple, [ % root
      {tuple, [{tuple, [{tuple, [{singleton, bar}, {singleton ,foo}]}]}]}, %a %b % d, k
      {tuple, [{tuple, [{named, noloc, {ty_ref, '.', c, 0}, []}]}]}, % f, c
      {named, noloc, {ty_ref, '.', e, 0}, []} % e
    ]},
    % Graph = #{
    %     root => [a, f, e]
    %     a => [b], b => [d, k],
    %     f => [c], c => [e],
    %     e => [c, k], k => [], d => []
    % },
    % Order of definitions: 
    %   * the first part of the root tuple should always be shared
    %   * the 'k' part of e should be shared
    % [[k],[e,c],[f],[d],[b],[a], [root]]
    TyP = ty_parser:parse(Ty),

    Ty2 = {tuple, [ % root
      {intersection, [{tuple, [{tuple, [{tuple, [{singleton, bar}, {singleton ,foo}]}]}]}]}, %a %b % d, k
      {intersection, [{tuple, [{tuple, [{named, noloc, {ty_ref, '.', c, 0}, []}]}]}]}, % f, c
      {intersection, [{named, noloc, {ty_ref, '.', e, 0}, []}]} % e
    ]},
    TyP = ty_parser:parse(Ty2),
    ok
  end).

share_isomorphic_recursive_types_test() ->
  global_state:with_new_state(fun() ->
    % TODO test case with two isomorphic recursive types
    % TODO not implemented yet, might be too expensive
    ok
  end).
