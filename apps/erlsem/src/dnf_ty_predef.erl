-module(dnf_ty_predef).

% predef(Predef) -> [Predef].
% empty() -> [].
% any() -> [ '[]', float, pid, port, reference ].
% is_empty([], ST) -> {true, ST};
% is_empty(_, ST) -> {false, ST}.
% negate(All) -> any() -- All.
% union(P1, P2) -> lists:usort(P1 ++ P2).
% intersect(P1, P2) -> [X || X <- P1, lists:member(X, P2)].
% diff(I1, I2) -> intersect(I1, negate(I2)).

% Map each element to a unique bit position
predef('[]')      -> <<1:5>>; 
predef(float)     -> <<2:5>>;
predef(pid)       -> <<4:5>>;
predef(port)      -> <<8:5>>;
predef(reference) -> <<16:5>>.

% The empty set (no bits set)
empty() -> <<0:5>>.

% The universal set (all bits set for 5 elements: 1+2+4+8+16 = 31)
any() -> <<31:5>>.

% Check if the set is empty (bitmask is 0)
is_empty(<<0:5>>, ST) -> {true, ST};
is_empty(_, ST) -> {false, ST}.

negate(<<N:5>>) -> <<(31 bxor N):5>>.

union(<<P1:5>>, <<P2:5>>) -> <<(P1 bor P2):5>>.

intersect(<<P1:5>>, <<P2:5>>) -> <<(P1 band P2):5>>.

diff(I1, I2) -> intersect(I1, negate(I2)).