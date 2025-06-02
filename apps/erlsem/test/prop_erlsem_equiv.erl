-module(prop_erlsem_equiv).

-include_lib("proper/include/proper.hrl").
-include_lib("eunit/include/eunit.hrl").

tany() -> {predef, any}.
tempty() -> {predef, none}.
tnegation(A) -> {negation, A}.
tunion(A, B) -> {union, [A, B]}.
tintersection(A, B) -> {intersection, [A, B]}.
tarrow(A, B) -> {fun_full, [A], B}.
tproduct(A, B) -> {tuple, [A, B]}.
tlist(A) -> {list, A}.
tfun(As, B) -> {fun_full, As, B}.
tvar(Variables) ->
  ?LET(Varname, oneof(Variables), {named, 0, {ty_ref, '.', Varname, 0}, []}).
tpredef() ->
  ?LET(Predef, oneof([float, reference, pid, port]), {predef, Predef}).

limited_formula(Variables) ->
  ?SIZED(Size, limited_formula(Variables, Size, toplevel)).

tvar_if_not_toplevel(Variables, Mode) -> 
  case Mode of toplevel -> []; _ -> [{1, tvar(Variables)}] end.

-define(F, limited_formula(Variables, Size div 2, Mode)).
-define(Fi, limited_formula(Variables, Size div 2, inside)).

limited_formula(Variables, Size, Mode) when Size =< 1 ->
  frequency([
    {1, tempty()},
    {2, tpredef()},
    {3, {empty_list}},
    {1, tany()}
  ] ++ tvar_if_not_toplevel(Variables, Mode)
);
limited_formula(Variables, Size, Mode) ->
  frequency([
    {2, tempty()},
    {2, tany()},
    {1, ?LAZY(?LET(A, ?F, tnegation(A))) },
    {4, ?LAZY(?LET({A, B}, {?F, ?F}, tunion(A, B))) },
    {4, ?LAZY(?LET({A, B}, {?F, ?F}, tintersection(A, B))) },
    {8, ?LAZY(?LET({A, B}, {?Fi, ?Fi}, tproduct(A, B))) },
    {1, ?LAZY(?LET({A}, {?Fi}, tlist(A))) },
    {4, ?LAZY(?LET({A, B}, {?Fi, ?Fi}, tarrow(A, B))) },
    {1, ?LAZY(?LET({As, B}, {list(?Fi), ?Fi}, tfun(As, B))) }
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
        % T0 = os:system_time(millisecond),
        Parsed = ty_parser:parse(Ty),
        % maybe 
        %   true ?= (T00 = os:system_time(millisecond)) - T0 > 100,
        %   io:format(user,"~p parse> ~p ms~n", [ty, (T00 - T0)]),
        %   io:format(user,"~p~n", [X]),
        %   error(exit),
        %   ok
        % end,
        % T1 = os:system_time(millisecond),
        ty_node:is_empty(Parsed),
        % maybe 
        %   true ?= (T11 = os:system_time(millisecond)) - T1 > 10,
        %   io:format(user,"~p is_empty> ~p ms~n", [ty, (T11 - T1)])
        % end,
        true
      end, X),
      true 
    end)
  end).

prop_subtype_instances() -> 
  ?FORALL(X, ?LET(Types, nonempty_list(atom()), system(Types)), begin 
    global_state:with_new_state(fun() ->
      maps:foreach(fun(VarName, AstTy) ->
        ty_parser:extend_symtab(VarName, {ty_scheme, [], AstTy})
      end, X),

      AllTypes = [ty_parser:parse({named, noloc, {ty_ref, '.', Name, 0}, []}) || {Name, _} <- maps:to_list(X)],

      Instances = [ty_node:intersect(A, ty_node:negate(B)) || A <- AllTypes, B <- AllTypes],
      T0 = os:system_time(millisecond),
      lists:foreach(fun(Ty) -> ty_node:is_empty(Ty) end, Instances),
      io:format(user,"~p instances in ~p ms~n", [length(Instances), os:system_time(millisecond) - T0]),

      true 
    end)
  end).

valid_system(System) ->
  lists:all(fun valid_rec/1, maps:to_list(System)).
  
valid_rec({_, {empty_list}}) -> true;
valid_rec({_, {predef, _}}) -> true;
valid_rec({Ty, {negation, L}}) -> valid_rec({Ty, L});
valid_rec({Ty, {union, L}}) -> lists:all(fun(E) -> valid_rec({Ty, E}) end, L);
valid_rec({Ty, {intersection, L}}) -> lists:all(fun(E) -> valid_rec({Ty, E}) end, L);
valid_rec({_, {fun_full, _, _}}) -> true;
valid_rec({_, {list, _}}) -> true;
valid_rec({_, {tuple, _}}) -> true;
valid_rec({Ty, {named, _, {ty_ref, '.', Ty, 0}, []}}) -> false;
valid_rec({_, {named, _, _Ty, []}}) -> false. % lets say recursion happens only under a type constructor for any variable
  