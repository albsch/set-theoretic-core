-module(debug_tests).


t1_test() ->
  Symtab = #{
    t9 =>
        {ty_scheme,[],
            {union,
                [
                  {fun_full,[{named,0,{ty_ref,'.',t9,0},[]}],{predef,any}},
                  {fun_full,[{predef,none}],{predef,any}}
                ]}}
  },

  
  global_state:with_new_state(fun() ->
    ty_parser:set_symtab(Symtab),
    %System = maps:keys(Symtab),
     
    Ty = {named, noloc, {ty_ref, '.', t9, 0}, []},
    Node = ty_parser:parse(Ty),

    io:format(user, "Check emptiness of ~p~n", [Node]),

    % emptiness
    ty_node:is_empty(Node),
    ty_node:is_empty(Node)

    % lists:foreach(fun(Name) -> 
    %   io:format(user, "Parsing ~p~n", [Name]),

    %   % parse
    %   Ty = {named, noloc, {ty_ref, '.', Name, 0}, []},
    %   Node = ty_parser:parse(Ty),

    %   io:format(user, "Check emptiness of ~p~n", [Node]),

    %   % emptiness
    %   ty_node:is_empty(Node),
    %   % cache
    %   ty_node:is_empty(Node)

    % end, System),
  end),
  ok.

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
        {Time, _} = timer:tc(fun() -> ty_parser:parse(TT) end),
        io:format(user,"~p> ~p ms~n", [TTN, Time/1000])
      end
      || {_,_,{_,_,TTN,_},_} = TT <- [Ty1, Ty2, Ty3, Ty4, Ty5, Ty6, Ty7, Ty8, Ty9, Ty10]
    ],

    [
      begin
        {Time, _} = timer:tc(fun() -> ty_parser:parse(TT) end),
        io:format(user,"~p> ~p ms~n", [TTN, Time/1000])
      end
      || {_,_,{_,_,TTN,_},_} = TT <- [Ty1, Ty2, Ty3, Ty4, Ty5, Ty6, Ty7, Ty8, Ty9, Ty10]
    ],


    ok
  end).
