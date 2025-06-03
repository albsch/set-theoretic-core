-module(dnf_ty_predef).

% TODO benchmark how much faster the bit representation is (O(n) vs O(1))
% predef(Predef) -> [Predef].
% empty() -> [].
% any() -> [ '[]', float, pid, port, reference ].
% is_empty([], ST) -> {true, ST};
% is_empty(_, ST) -> {false, ST}.
% negate(All) -> any() -- All.
% union(P1, P2) -> lists:usort(P1 ++ P2).
% intersect(P1, P2) -> [X || X <- P1, lists:member(X, P2)].
% diff(I1, I2) -> intersect(I1, negate(I2)).

-define(ELEMENTS, 5).
% Map each element to a unique bit position
predef('[]') -> <<1:?ELEMENTS>>; 
predef(float) -> <<2:?ELEMENTS>>;
predef(pid) -> <<4:?ELEMENTS>>;
predef(port) -> <<8:?ELEMENTS>>;
predef(reference) -> <<16:?ELEMENTS>>.

% The empty set (no bits set)
empty() -> <<0:?ELEMENTS>>.

% The full set (all bits set for ?ELEMENTS elements: 1+2+4+8+16 = 31)
any() -> <<31:?ELEMENTS>>.

% Check if the set is empty (bitmask is 0)
is_empty(<<0:?ELEMENTS>>, ST) -> {true, ST};
is_empty(_, ST) -> {false, ST}.

negate(<<N:?ELEMENTS>>) -> <<(31 bxor N):?ELEMENTS>>.

union(<<P1:?ELEMENTS>>, <<P2:?ELEMENTS>>) -> <<(P1 bor P2):?ELEMENTS>>.

intersect(<<P1:?ELEMENTS>>, <<P2:?ELEMENTS>>) -> <<(P1 band P2):?ELEMENTS>>.

diff(I1, I2) -> intersect(I1, negate(I2)).