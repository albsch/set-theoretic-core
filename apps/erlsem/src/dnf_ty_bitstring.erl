-module(dnf_ty_bitstring).

% currently only supported: bitstring yes/no

compare(0, 0) -> 0; compare(1, 1) -> 0; compare(1, 0) -> 1; compare(0, 1) -> -1.
equal(X, Y) -> X =:= Y.
empty() -> 0.
any() -> 1.
union(X, Y) -> erlang:max(X, Y).
intersect(X, Y) -> erlang:min(X, Y).
difference(_, 1) -> 0; difference(X, _) -> X.
negate(1) -> 0; negate(0) -> 1.
is_any(1) -> true; is_any(_) -> false.
is_empty(0, S) -> {true, S}; is_empty(_, S) -> {false, S}.
substitute(_,X,_,_) -> X.
% there is nothing to substitute in a ty_bool
map_pi(_) -> #{}.
has_ref(_,_) -> false.
all_variables(_, _) -> [].
raw_transform(T, Op) -> transform(T, Op).
transform(0, #{empty := E}) -> E();
transform(1, #{any := A}) -> A().
