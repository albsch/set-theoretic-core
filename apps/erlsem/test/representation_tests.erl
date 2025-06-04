-module(representation_tests).


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
