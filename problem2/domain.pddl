(define (domain mars-rover)
    (:requirements :strips :typing)
    (:types location rover rock drill bay - object)
    
    (:predicates 
        (at-rover ?r - rover ?l - location)
        (at-rock ?rk - rock ?l - location)
        (at-drill ?d - drill ?l - location)
        (connected ?l1 - location ?l2 - location)
        (equipped ?r - rover ?d - drill)
        (empty ?b - bay)
        (carrying ?r - rover ?rk - rock ?b - bay)
        (is-hard ?rk - rock)
        (is-soft ?rk - rock)
    )

    (:action move
        :parameters (?r - rover ?from - location ?to - location)
        :precondition (and (at-rover ?r ?from) (connected ?from ?to))
        :effect (and (not (at-rover ?r ?from)) (at-rover ?r ?to))
    )

    (:action pick_drill
        :parameters (?r - rover ?d - drill ?l - location)
        :precondition (and (at-rover ?r ?l) (at-drill ?d ?l))
        :effect (and (not (at-drill ?d ?l)) (equipped ?r ?d))
    )

    (:action collect_soft
        :parameters (?r - rover ?rk - rock ?l - location ?b - bay)
        :precondition (and (at-rover ?r ?l) (at-rock ?rk ?l) (empty ?b) (is-soft ?rk))
        :effect (and (not (at-rock ?rk ?l)) (not (empty ?b)) (carrying ?r ?rk ?b))
    )

    (:action collect_hard
        :parameters (?r - rover ?rk - rock ?l - location ?b - bay ?d - drill)
        :precondition (and (at-rover ?r ?l) (at-rock ?rk ?l) (empty ?b) (is-hard ?rk) (equipped ?r ?d))
        :effect (and (not (at-rock ?rk ?l)) (not (empty ?b)) (carrying ?r ?rk ?b))
    )

    (:action deposit
        :parameters (?r - rover ?rk - rock ?l - location ?b - bay)
        :precondition (and (at-rover ?r ?l) (carrying ?r ?rk ?b))
        :effect (and (not (carrying ?r ?rk ?b)) (empty ?b) (at-rock ?rk ?l))
    )
)