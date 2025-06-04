-module(debug_tests).

slow_test_() ->
  {timeout, 60, fun() -> 
    slow_test(),
    ok 
  end}.

tuple_test() ->
  {ok, [System]} = file:consult("system_tuple"),

  global_state:with_new_state(fun() -> 
    ty_parser:set_symtab(System),
    maps:foreach(fun(VarName, AstTy) ->
      ty_parser:extend_symtab(VarName, {ty_scheme, [], AstTy})
    end, System),

    Ty1 = {named, noloc, {ty_ref, '.', a, 0}, []},
    Ty2 = {named, noloc, {ty_ref, '.', b, 0}, []},
    [
      begin
        {Time, Ty} = timer:tc(fun() -> ty_parser:parse(TT) end),
        io:format(user,"~p parse> ~p ms~n", [TTN, Time/1000]),
        {Time2, _} = timer:tc(fun() -> ty_node:is_empty(Ty) end),
        io:format(user,"~p is_empty> ~p ms~n", [TTN, Time2/1000])
      end
      || {_,_,{_,_,TTN,_},_} = TT <- [Ty1, Ty2]
    ],

    [
      begin
        {Time, Ty} = timer:tc(fun() -> ty_parser:parse(TT) end),
        io:format(user,"~p parse> ~p ms~n", [TTN, Time/1000]),
        {Time2, _} = timer:tc(fun() -> ty_node:is_empty(Ty) end),
        io:format(user,"~p is_empty> ~p ms~n", [TTN, Time2/1000])
      end
      || {_,_,{_,_,TTN,_},_} = TT <- [Ty1, Ty2]
    ],


    ok
  end).


slow_test() ->
  {ok, [System]} = file:consult("system"),
  dnf_ty_variable:any(),

  global_state:with_new_state(fun() -> 
    AllNames = [begin ty_parser:extend_symtab(VarName, {ty_scheme, [], AstTy}), VarName end  || VarName := AstTy <- System],
    [begin
        {Time, Ty} = timer:tc(fun() -> 
          % fprof:trace(start),
          TT = {named, noloc, {ty_ref, '.', Name, 0}, []},
          Z = ty_parser:parse(TT),
          % fprof:trace(stop),
          % fprof:profile(),
          % fprof:analyse(),
          Z
        end),
        io:format(user,"~p parse> ~p ms~n", [Name, Time/1000]),
        {Time2, _} = timer:tc(fun() -> 
        ty_node:is_empty(Ty) end),
        io:format(user,"~p is_empty> ~p ms~n", [Name, Time2/1000])
      end
      || Name <- AllNames
    ],

    ok
  end).


ast_test() ->
  {ok, [System]} = file:consult("system_ast"),
  dnf_ty_variable:any(),
  % io:format(user,"~p~n", [System]),

  global_state:with_new_state(fun() -> 
    maps:foreach(fun({ty_key,ast,VarName,_Arity}, AstTyScheme) ->
      ty_parser:extend_symtab(VarName, AstTyScheme)
    end, System),

    Ty = {named, noloc, {ty_ref, 'ast', ty, 0}, []},

    {Time, _} = timer:tc(fun() -> 
      % fprof:trace(start),
      Z = ty_parser:parse(Ty),
      % fprof:trace(stop),
      % fprof:profile(),
      % fprof:analyse(),
      Z
    end),
    io:format(user,"parse> ~p ms~n", [Time/1000]),

    ok
  end).
