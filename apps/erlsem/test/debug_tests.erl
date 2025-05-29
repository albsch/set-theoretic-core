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
  {ok, [System]} = file:consult("system"),


  global_state:with_new_state(fun() -> 
    ty_parser:set_symtab(System),
    maps:foreach(fun(VarName, AstTy) ->
      % io:format(user,"~p~n", [AstTy]),
      ty_parser:extend_symtab(VarName, {ty_scheme, [], AstTy})
    end, System),

    % Ty1 = {named, noloc, {ty_ref, '.', t1, 0}, []},
    Ty2 = {named, noloc, {ty_ref, '.', t2, 0}, []},
    % Ty3 = {named, noloc, {ty_ref, '.', t3, 0}, []},
    % Ty4 = {named, noloc, {ty_ref, '.', t4, 0}, []},
    {_T1, _} = timer:tc(fun() -> ty_parser:parse(Ty2) end),
    % {T2, _} = timer:tc(fun() -> ty_parser:parse(Ty2) end),
    % {T3, _} = timer:tc(fun() -> ty_parser:parse(Ty3) end),
    % {T4, _} = timer:tc(fun() -> ty_parser:parse(Ty4) end),
    % {_T5, _} = timer:tc(fun() -> ty_parser:parse(Ty2) end),
    % {_, _} = timer:tc(fun() -> ty_parser:parse(Ty2) end),
    % {_, _} = timer:tc(fun() -> ty_parser:parse(Ty2) end),
    % {_, _} = timer:tc(fun() -> ty_parser:parse(Ty2) end),
    % {_, _} = timer:tc(fun() -> ty_parser:parse(Ty2) end),
    % {T7, _} = timer:tc(fun() -> ty_parser:parse(Ty2) end),
    % {T6, _Parsed} = timer:tc(fun() -> ty_parser:parse(Ty1) end),
    % io:format(user,"~p~n", [T6]),
    % {T7, _Parsed} = timer:tc(fun() -> ty_parser:parse(Ty1) end),
    % io:format(user,"~p~n", [T7]),
    % {T8, _Parsed} = timer:tc(fun() -> ty_parser:parse(Ty1) end),
    % io:format(user,"~p~n", [T8]),
    % {T9, _Parsed} = timer:tc(fun() -> ty_parser:parse(Ty1) end),
    % io:format(user,"~p~n", [T9]),

    % [
    %  begin
    %   {TT, _Parsed} = timer:tc(fun() -> ty_parser:parse(Ty1) end),
    %   io:format(user,"<all> ~pms~n~n", [TT/1000])
    %  end
    %  || _ <- lists:seq(1, 100)
    % ],

    ok
  end).
