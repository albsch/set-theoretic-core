-module(debug_tests).

slow_test_() ->
  {timeout, 60, fun() -> 
    slow_test(),
    ok 
  end}.

slow_test() ->
  {ok, [System]} = file:consult("system2"),


  global_state:with_new_state(fun() -> 
    ty_parser:set_symtab(System),
    maps:foreach(fun(VarName, AstTy) ->
      % io:format(user,"~p~n", [AstTy]),
      ty_parser:extend_symtab(VarName, {ty_scheme, [], AstTy})
    end, System),

    Ty1 = {named, noloc, {ty_ref, '.', t1, 0}, []},
    Ty2 = {named, noloc, {ty_ref, '.', t2, 0}, []},
    Ty3 = {named, noloc, {ty_ref, '.', t3, 0}, []},
    Ty4 = {named, noloc, {ty_ref, '.', t4, 0}, []},
    Ty5 = {named, noloc, {ty_ref, '.', t5, 0}, []},
    Ty6 = {named, noloc, {ty_ref, '.', t6, 0}, []},
    Ty7 = {named, noloc, {ty_ref, '.', t7, 0}, []},
    Ty8 = {named, noloc, {ty_ref, '.', t8, 0}, []},
    Ty9 = {named, noloc, {ty_ref, '.', t9, 0}, []},
    Ty10 = {named, noloc, {ty_ref, '.', t10, 0}, []},
    [
      begin
        {Time, Ty} = timer:tc(fun() -> ty_parser:parse(TT) end),
        io:format(user,"~p parse> ~p ms~n", [TTN, Time/1000]),
        {Time2, _} = timer:tc(fun() -> ty_node:is_empty(Ty) end),
        io:format(user,"~p is_empty> ~p ms~n", [TTN, Time2/1000])
      end
      || {_,_,{_,_,TTN,_},_} = TT <- [Ty1, Ty2, Ty3, Ty4, Ty5, Ty6, Ty7, Ty8, Ty9, Ty10]
    ],

    [
      begin
        {Time, Ty} = timer:tc(fun() -> ty_parser:parse(TT) end),
        io:format(user,"~p parse> ~p ms~n", [TTN, Time/1000]),
        {Time2, _} = timer:tc(fun() -> ty_node:is_empty(Ty) end),
        io:format(user,"~p is_empty> ~p ms~n", [TTN, Time2/1000])
      end
      || {_,_,{_,_,TTN,_},_} = TT <- [Ty1, Ty2, Ty3, Ty4, Ty5, Ty6, Ty7, Ty8, Ty9, Ty10]
    ],


    ok
  end).
