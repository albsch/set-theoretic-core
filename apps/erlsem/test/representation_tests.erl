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
share_sub_types_test() ->
  {ok, [System]} = file:consult("system_rec"),
  global_state:with_new_state(fun() -> 
    maps:foreach(fun({ty_key,ast,VarName,_Arity}, AstTyScheme) -> ty_parser:extend_symtab(VarName, AstTyScheme) end, System),

    Ty = ty_parser:parse({named, {loc,"src/ast.erl",405,30}, {ty_ref, 'ast', ty, 0}, []}),
    Ty2 = ty_parser:parse({named, {loc,"src/ast.erl",415,37}, {ty_ref, 'ast', ty_tuple, 0}, []}),
    true = Ty =:= ty_node:union(Ty, Ty2),
    ok
  end).

% types parsed to the same structure should be shared
% across parse passes
share_simple_types_test() ->
  global_state:with_new_state(fun() ->
    Ty = ty_parser:parse({singleton, foo}),
    Ty2 = ty_parser:parse({intersection, [{singleton, foo}]}),
    io:format(user,"~p~n", [Ty]),
    io:format(user,"~p~n", [Ty2]),
    % true = dnf_ty_variable:empty() =:= ty_node:load(Ty3)
    ok
  end).

share_isomorphic_recursive_types_test() ->
  global_state:with_new_state(fun() ->
    Ty = ty_parser:parse({singleton, foo}),
    Ty2 = ty_parser:parse({intersection, [{singleton, foo}]}),
    io:format(user,"~p~n", [Ty]),
    io:format(user,"~p~n", [Ty2]),
    % true = dnf_ty_variable:empty() =:= ty_node:load(Ty3)
    ok
  end).