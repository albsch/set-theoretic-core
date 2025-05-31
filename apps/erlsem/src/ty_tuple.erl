-module(ty_tuple).

-ifndef(NODE).
-define(NODE, ty).
-endif.
%% n-tuple representation

compare(A, B) when A < B -> lt;
compare(A, B) when A > B -> gt;
compare(_, _) -> eq.

equal(P1, P2) -> compare(P1, P2) =:= eq.

tuple(Refs) -> {ty_tuple, length(Refs), Refs}.

empty(Size) -> {ty_tuple, Size, [ty_rec:empty() || _ <- lists:seq(1, Size)]}.
any(Size) -> {ty_tuple, Size, [ty_rec:any() || _ <- lists:seq(1, Size)]}.


components({ty_tuple, _, Refs}) -> Refs.
pi(I, {ty_tuple, _, Refs}) -> lists:nth(I, Refs).

big_intersect([]) -> error(illegal_state);
big_intersect([X]) -> X;
big_intersect([X | Y]) ->
    lists:foldl(fun({ty_tuple, _, Refs}, {ty_tuple, Dim, Refs2}) ->
        true = length(Refs) == length(Refs2),
        {ty_tuple, Dim, [ty_rec:intersect(S, T) || {S, T} <- lists:zip(Refs, Refs2)]}
                end, X, Y).

% substitute({ty_tuple, Dim, Refs}, Map, Memo) ->
%     {ty_tuple, Dim, [ ty_rec:substitute(B, Map, Memo) || B <- Refs ] }.

all_variables({ty_tuple, _, Refs}, M) ->
    lists:flatten([ty_rec:all_variables(E, M) || E <- Refs]).

% -ifdef(TEST).
% -include_lib("eunit/include/eunit.hrl").

% usage_test() ->
%     % (int, int)
%     TIa = ty_rec:interval(dnf_var_ty_interval:int(dnf_ty_interval:interval('*', '*'))),
%     TIb = ty_rec:interval(dnf_var_ty_interval:int(dnf_ty_interval:interval('*', '*'))),

%     _Ty_Tuple = ty_tuple:tuple([TIa, TIb]),

%     ok.

% -endif.
