(define (problem collect-samples-extended)
    (:domain mars-rover)
    (:objects 
        Base SiteA SiteB SiteC SiteD SiteE SiteF - location
        Curiosity - rover
        Rock1 Rock2 Rock3 Rock4 Rock5 Rock6 Rock7 - rock
        Drill1 - drill
        Bay1 Bay2 - bay
    )
    (:init 
        (connected Base SiteA) (connected SiteA Base)
        ;; Base to SiteB route removed due to dust storm
        (connected SiteA SiteC) (connected SiteC SiteA)
        (connected SiteB SiteD) (connected SiteD SiteB)
        (connected SiteC SiteE) (connected SiteE SiteC)
        (connected SiteD SiteE) (connected SiteE SiteD)
        (connected SiteE SiteF) (connected SiteF SiteE)
        (connected SiteC SiteD) ; One-way slope
        
        (at-rover Curiosity Base)
        (at-drill Drill1 SiteE)
        (at-rock Rock1 SiteA)
        (at-rock Rock2 SiteB)
        (at-rock Rock3 SiteC)
        (at-rock Rock4 SiteD)
        (at-rock Rock5 SiteF)
        (at-rock Rock6 SiteE)
        (at-rock Rock7 SiteF)
        
        (is-soft Rock1)
        (is-soft Rock2)
        (is-hard Rock3)
        (is-soft Rock4)
        (is-hard Rock5)
        (is-soft Rock6)
        (is-hard Rock7)
        
        (empty Bay1)
        (empty Bay2)
    )
    (:goal (and 
        (at-rover Curiosity Base)
        (empty Bay1)
        (empty Bay2)
        (at-rock Rock1 Base)
        (at-rock Rock2 Base)
        (at-rock Rock3 Base)
        (at-rock Rock4 Base)
        (at-rock Rock5 Base)
        (at-rock Rock6 Base)
        (at-rock Rock7 Base)
    ))
)