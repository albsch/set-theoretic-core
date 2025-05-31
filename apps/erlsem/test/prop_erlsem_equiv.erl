-module(prop_erlsem_equiv).

-include_lib("proper/include/proper.hrl").
-include_lib("eunit/include/eunit.hrl").

tany() -> {predef, any}.
tempty() -> {predef, none}.
tnegation(A) -> {negation, A}.
tunion(A, B) -> {union, [A, B]}.
tintersection(A, B) -> {intersection, [A, B]}.
tarrow(A, B) -> {fun_full, [A], B}.
tfun(As, B) -> {fun_full, As, B}.
tvar(Variables) ->
  ?LET(Varname, oneof(Variables), {named, 0, {ty_ref, '.', Varname, 0}, []}).


limited_formula(Variables) ->
  ?SIZED(Size, limited_formula(Variables, Size, toplevel)).

tvar_if_not_toplevel(Variables, Mode) -> 
  case Mode of toplevel -> []; _ -> [{1, tvar(Variables)}] end.


limited_formula(Variables, Size, Mode) when Size =< 1 ->
  frequency([
    {1, tempty()},
    {1, tany()}
  ] ++ tvar_if_not_toplevel(Variables, Mode)
);
limited_formula(Variables, Size, Mode) ->
  frequency([
    {2, tempty()},
    {2, tany()},
    % TODO negation when tuples work
    % {1, ?LAZY(?LET(A, 
    %     limited_formula(Variables, Size div 2, Mode), 
    %     tnegation(A)))  },
    {4, ?LAZY(?LET({A, B}, 
        {limited_formula(Variables, Size div 2, Mode), limited_formula(Variables, Size div 2, Mode)}, 
        tunion(A, B)))  },
    {4, ?LAZY(?LET({A, B}, 
        {limited_formula(Variables, Size div 2, Mode), limited_formula(Variables, Size div 2, Mode)}, 
        tintersection(A, B)))  },
    {4, ?LAZY(?LET({A, B}, 
        {limited_formula(Variables, Size div 2, inside), limited_formula(Variables, Size div 2, inside)}, 
        tarrow(A, B)))  },
    {1, ?LAZY(?LET({As, B}, 
        {list(limited_formula(Variables, Size div 2, inside)), limited_formula(Variables, Size div 2, inside)}, 
        tfun(As, B)))  }
  ] ++ tvar_if_not_toplevel(Variables, Mode)
).

system(Variables) ->
  ?SUCHTHAT(Ty, ?LET(Formulas, [limited_formula(Variables) || _ <- Variables], 
    maps:from_list(lists:zip(Variables, Formulas))
  ), valid_system(Ty)).

% property that checks if we can parse any random type
prop_parse_and_emptiness() -> 
  ?FORALL(X, ?LET(Types, nonempty_list(atom()), system(Types)), begin 
    global_state:with_new_state(fun() ->
      maps:foreach(fun(VarName, AstTy) ->
        ty_parser:extend_symtab(VarName, {ty_scheme, [], AstTy})
      end, X),

      maps:map(fun(Name, _) -> 
        Ty = {named, noloc, {ty_ref, '.', Name, 0}, []},
        Parsed = ty_parser:parse(Ty),
        ty_node:is_empty(Parsed),
        true
      end, X),
      true 
    end)
  end).

valid_system(System) ->
  lists:all(fun valid_rec/1, maps:to_list(System)).
  
valid_rec({_, {predef, any}}) -> true;
valid_rec({_, {predef, none}}) -> true;
valid_rec({Ty, {negation, L}}) -> valid_rec({Ty, L});
valid_rec({Ty, {union, L}}) -> lists:all(fun(E) -> valid_rec({Ty, E}) end, L);
valid_rec({Ty, {intersection, L}}) -> lists:all(fun(E) -> valid_rec({Ty, E}) end, L);
valid_rec({_, {fun_full, _, _}}) -> true;
valid_rec({Ty, {named, _, {ty_ref, '.', Ty, 0}, []}}) -> false;
valid_rec({_, {named, _, _Ty, []}}) -> false. % lets say recursion happens only under a type constructor for any variable
  