(define (problem collect-samples)
    (:domain mars-rover)
    (:objects 
        Base SiteA SiteB SiteC SiteD SiteE SiteF - location
        Curiosity - rover
        Rock1 Rock2 Rock3 Rock4 Rock5 - rock
        Drill1 - drill
        Bay1 Bay2 - bay
    )
    (:init 
        (connected Base SiteA) (connected SiteA Base)
        (connected Base SiteB) (connected SiteB Base)
        (connected SiteA SiteC) (connected SiteC SiteA)
        (connected SiteB SiteD) (connected SiteD SiteB)
        (connected SiteC SiteE) (connected SiteE SiteC)
        (connected SiteD SiteE) (connected SiteE SiteD)
        (connected SiteE SiteF) (connected SiteF SiteE)
        (connected SiteC SiteD) ; One-way slope down to D
        
        (at-rover Curiosity Base)
        (at-drill Drill1 SiteE)
        (at-rock Rock1 SiteA)
        (at-rock Rock2 SiteB)
        (at-rock Rock3 SiteC)
        (at-rock Rock4 SiteD)
        (at-rock Rock5 SiteF)
        
        (is-soft Rock1)
        (is-soft Rock2)
        (is-hard Rock3)
        (is-soft Rock4)
        (is-hard Rock5)
        
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
    ))
)