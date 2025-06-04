-module(representation_tests).

-include_lib("eunit/include/eunit.hrl").

redundant_default_test() ->
  % {ty,{{leaf,0},#{1 => {leaf,0},26 => {leaf,0}}}},
  global_state:with_new_state(fun() ->
    Ty = ty_parser:parse({fun_full, [{predef, any}], {predef, any}}),
    % Ty2 = parse({negation, {fun_full, [{predef, any}], {predef, any}}}),
    Ty2 = ty_node:negate(Ty),
    Ty3 = ty_node:intersect(Ty, Ty2),

    io:format(user, "~p : ~p~n", [Ty3, ty_node:load(Ty3)]),
    ok

  end),
  ok.

operations_on_recursive_types_test() ->
  {ok, [System]} = file:consult("system_rec"),
  global_state:with_new_state(fun() -> 
    maps:foreach(fun({ty_key,ast,VarName,_Arity}, AstTyScheme) -> ty_parser:extend_symtab(VarName, AstTyScheme) end, System),

    Ty = ty_parser:parse({named, {loc,"src/ast.erl",405,30}, {ty_ref, 'ast', ty, 0}, []}),
    Ty2 = ty_parser:parse({named, {loc,"src/ast.erl",415,37}, {ty_ref, 'ast', ty_tuple, 0}, []}),
    Ty = ty_node:union(Ty, Ty2),
    ok
  end).