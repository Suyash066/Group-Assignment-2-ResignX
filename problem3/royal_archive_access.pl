% =====================================================================
% Problem 3: Royal Archive Access Verification by Resolution Refutation
% Run:   swipl -q -s royal_archive_access.pl -g main -t halt
% =====================================================================
:- use_module(library(lists)).
:- dynamic stored/3.          % stored(Id, Literals, Parents) : clauses of the refutation

% ---------------------------------------------------------------------
% Step 1: Predicate logic representation
% ---------------------------------------------------------------------
% Constants : mira, scroll_7, royal_archive
% Variables : X (a person), R (a record)
% Predicates:
%   archivist(X)       X is an archivist
%   verifies(X,R)      X verifies record R
%   trusted(X)         X is trusted
%   access(X,R)        X has access to R
%   sealed(R)          R is sealed
%   permitted(X,R)     X is permitted to inspect R
%   inspects(X,R)      X actually inspects R
%   finds_mark(X,R)    X finds a hidden mark in R
%   stored(R,A)        R is stored in archive A
step1(1, 'forall X,R: archivist(X) & verifies(X,R) -> trusted(X)').
step1(2, 'forall X,R: trusted(X) & access(X,R) & sealed(R) -> permitted(X,R)').
step1(3, 'forall X,R: inspects(X,R) & finds_mark(X,R) -> verifies(X,R)').
step1(4, 'forall R: stored(R,royal_archive) -> sealed(R)').
step1(5, 'stored(scroll_7,royal_archive)').
step1(6, 'access(mira,scroll_7)').
step1(7, 'inspects(mira,scroll_7) & finds_mark(mira,scroll_7)').
step1(8, 'archivist(mira)').

% ---------------------------------------------------------------------
% Step 2: Negation of the goal
% ---------------------------------------------------------------------
% Goal: trusted(mira).   Negated goal added to the KB: ~trusted(mira)
step2(goal,     'trusted(mira)').
step2(negation, '~trusted(mira)').

% ---------------------------------------------------------------------
% Step 3: Implication removal  (A -> B  ==>  ~A | B)
% ---------------------------------------------------------------------
step3(1, 'forall X,R: ~(archivist(X) & verifies(X,R)) | trusted(X)').
step3(2, 'forall X,R: ~(trusted(X) & access(X,R) & sealed(R)) | permitted(X,R)').
step3(3, 'forall X,R: ~(inspects(X,R) & finds_mark(X,R)) | verifies(X,R)').
step3(4, 'forall R: ~stored(R,royal_archive) | sealed(R)').

% ---------------------------------------------------------------------
% Step 4: Negation movement (De Morgan: ~(A & B) ==> ~A | ~B)
% ---------------------------------------------------------------------
step4(1, 'forall X,R: ~archivist(X) | ~verifies(X,R) | trusted(X)').
step4(2, 'forall X,R: ~trusted(X) | ~access(X,R) | ~sealed(R) | permitted(X,R)').
step4(3, 'forall X,R: ~inspects(X,R) | ~finds_mark(X,R) | verifies(X,R)').
step4(4, 'forall R: ~stored(R,royal_archive) | sealed(R)').

% ---------------------------------------------------------------------
% Step 5: Standardization (a distinct variable pair per rule)
% ---------------------------------------------------------------------
step5(1, 'forall X1,R1: ~archivist(X1) | ~verifies(X1,R1) | trusted(X1)').
step5(2, 'forall X2,R2: ~trusted(X2) | ~access(X2,R2) | ~sealed(R2) | permitted(X2,R2)').
step5(3, 'forall X3,R3: ~inspects(X3,R3) | ~finds_mark(X3,R3) | verifies(X3,R3)').
step5(4, 'forall R4: ~stored(R4,royal_archive) | sealed(R4)').

% ---------------------------------------------------------------------
% Step 6: Skolemization
% ---------------------------------------------------------------------
% There are no existential quantifiers in the knowledge base, so no Skolem
% constants/functions are needed. Universal quantifiers are simply dropped
% (all remaining variables are implicitly universally quantified).
step6('No existential quantifiers: nothing to Skolemize. Drop the universal quantifiers.').

% ---------------------------------------------------------------------
% Step 7: CNF clauses
% ---------------------------------------------------------------------
% A literal is pos(Atom) or neg(Atom); a clause is a list of literals;
% Prolog variables play the role of the logical variables.
kb_clause(c1, [neg(archivist(X)), neg(verifies(X,R)), pos(trusted(X))]).
kb_clause(c2, [neg(trusted(X)), neg(access(X,R)), neg(sealed(R)), pos(permitted(X,R))]).
kb_clause(c3, [neg(inspects(X,R)), neg(finds_mark(X,R)), pos(verifies(X,R))]).
kb_clause(c4, [neg(stored(R,royal_archive)), pos(sealed(R))]).
kb_clause(c5, [pos(stored(scroll_7,royal_archive))]).
kb_clause(c6, [pos(access(mira,scroll_7))]).
kb_clause(c7, [pos(inspects(mira,scroll_7))]).
kb_clause(c8, [pos(finds_mark(mira,scroll_7))]).
kb_clause(c9, [pos(archivist(mira))]).
neg_goal_clause(c10, [neg(trusted(mira))]).     % negated goal

% ---------------------------------------------------------------------
% Step 8: Resolution implementation and execution
% ---------------------------------------------------------------------
% Strategy: set of support. The negated goal is the only initial support
% clause; each support clause (in FIFO order) is resolved against every
% clause already known. Search stops when the empty clause [] is derived.

% resolve(+C1, +C2, -Resolvent, -Lit1, -Lit2)
resolve(C1, C2, Res) :-
    copy_term(C1, D1), copy_term(C2, D2),          % rename variables apart
    select(L1, D1, Rest1),
    select(L2, D2, Rest2),
    complementary(L1, L2),                          % unifies the two atoms
    append(Rest1, Rest2, Raw),
    dedupe(Raw, Res),
    \+ tautology(Res).

complementary(pos(A), neg(B)) :- A = B.
complementary(neg(A), pos(B)) :- A = B.

dedupe([], []).
dedupe([L|T], [L|R]) :- exclude(==(L), T, T1), dedupe(T1, R).

tautology(C) :- member(pos(A), C), member(neg(B), C), A == B.

% variant check, to avoid storing the same clause twice
variant(A, B) :- \+ \+ ( copy_term(A, A1), copy_term(B, B1),
                          numbervars(A1, 0, N), numbervars(B1, 0, N), A1 == B1 ).

known(C) :- stored(_, K, _), variant(C, K), !.

init :-
    retractall(stored(_,_,_)),
    forall(kb_clause(Id, C), assertz(stored(Id, C, given))),
    neg_goal_clause(G, GC), assertz(stored(G, GC, negated_goal)).

% Main refutation loop: Queue holds the ids of support clauses to process.
refute :-
    neg_goal_clause(G, _),
    loop([G], 11).

loop([], _) :- !, writeln('Search exhausted: no refutation found.'), fail.
loop([Given|Queue], Next) :-
    stored(Given, GC, _),
    findall(Other, ( stored(Other, _, _), Other \== Given ), Others),
    expand(Given, GC, Others, Next, Next1, New),
    (   memberchk(empty(EmptyId), New)
    ->  print_proof(EmptyId)
    ;   append(Queue, New, Queue1), loop(Queue1, Next1)
    ).

% expand: resolve Given with each Other, assign ids n11, n12, ...
expand(_, _, [], N, N, []).
expand(G, GC, [O|Os], N, NOut, New) :-
    stored(O, OC, _),
    (   resolve(GC, OC, R), \+ known(R)
    ->  atom_concat(r, N, Id), N1 is N + 1,
        assertz(stored(Id, R, [G, O])),
        (   R == []
        ->  New = [empty(Id)]               % stop immediately: empty clause
        ;   New = [Id|NewRest],
            expand(G, GC, Os, N1, NOut, NewRest)
        )
    ;   expand(G, GC, Os, N, NOut, New)
    ).

% ---- proof printing: only the clauses that lead to [] ----
print_proof(EmptyId) :-
    ancestors(EmptyId, [], Used),               % ids in the proof
    findall(Id, (stored(Id,_,_), memberchk(Id, Used)), Ids0),
    sort_proof(Ids0, Ids),
    nl, writeln('--- Clauses used in the refutation ---'),
    forall(member(Id, Ids), show(Id)),
    nl,
    writeln('The empty clause [] was derived: the knowledge base plus ~trusted(mira)'),
    writeln('is contradictory, hence  trusted(mira)  follows from the facts and rules.').

ancestors(Id, Acc, Acc) :- memberchk(Id, Acc), !.
ancestors(Id, Acc, Out) :-
    stored(Id, _, P),
    (   is_list(P)
    ->  foldl(ancestors, P, [Id|Acc], Out)
    ;   Out = [Id|Acc]
    ).

% order: given clauses first (by name), then resolvents by creation order
sort_proof(Ids, Sorted) :-
    predsort(cmp_id, Ids, Sorted).
cmp_id(O, A, B) :- idkey(A, KA), idkey(B, KB), compare(O0, KA, KB),
                   ( O0 == (=) -> O = (<) ; O = O0 ).
idkey(Id, K) :- atom_chars(Id, [T|Ds]), atom_chars(DA, Ds), atom_number(DA, N),
                ( T == c -> K = 0-N ; K = 1-N ).

show(Id) :-
    stored(Id, C, P),
    copy_term(C, C1), numbervars(C1, 0, _),
    clause_text(C1, Txt),
    (   is_list(P) -> P = [A,B], format('~w: ~w   [resolvent of ~w and ~w]~n', [Id, Txt, A, B])
    ;   P == negated_goal -> format('~w: ~w   [negated goal]~n', [Id, Txt])
    ;   format('~w: ~w   [given]~n', [Id, Txt])
    ).

clause_text([], '[]  (empty clause)') :- !.
clause_text(C, Txt) :-
    maplist(lit_text, C, Ts),
    atomic_list_concat(Ts, ' | ', Txt).
lit_text(pos(A), T) :- format(atom(T), '~p', [A]).
lit_text(neg(A), T) :- format(atom(T), '~~~p', [A]).

% ---------------------------------------------------------------------
% Driver: prints every transformation stage, then runs the refutation
% ---------------------------------------------------------------------
section(T) :- nl, format('=== ~w ===~n', [T]).
print_rows(Pred) :- forall(call(Pred, N, F), format('  (~w) ~w~n', [N, F])).

main :-
    section('Step 1: Predicate logic representation'), print_rows(step1),
    section('Step 2: Negation of goal'),
        step2(goal, G), step2(negation, NG),
        format('  Goal: ~w~n  Negated goal added to KB: ~w~n', [G, NG]),
    section('Step 3: Implication removal'), print_rows(step3),
    section('Step 4: Negation movement'), print_rows(step4),
    section('Step 5: Standardization'), print_rows(step5),
    section('Step 6: Skolemization'), step6(S), format('  ~w~n', [S]),
    section('Step 7: CNF clauses'),
        forall(kb_clause(Id, C), show_given(Id, C)),
        neg_goal_clause(GId, GC), show_given(GId, GC),
    section('Step 8: Resolution refutation (set of support)'),
        init,
        (   refute -> true ; writeln('No proof found.') ).

show_given(Id, C) :-
    copy_term(C, C1), numbervars(C1, 0, _), clause_text(C1, T),
    format('  ~w: ~w~n', [Id, T]).
