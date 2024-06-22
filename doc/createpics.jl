#----- #!/usr/bin/env julia -----

# run in VS Code!


# canonical examples in msgs:
# overs:            ov"13.2"
# runs/wickets:     142/7


using Plots


include("../src/CricketNetRunRateRodeo.jl")
using .CricketNetRunRateRodeo




function totitle(sc::Score)
    return "$(sc.runs)/$(sc.wickets) $(sc.overs)"
end
function totitle(mt::Match)
    return totitle(mt.sc1) * " v " * totitle(mt.sc2)
end






# simple score: not bowled-out; overs remaining => win by wickets
sc1 = sc"ITA 162/7 20"
p = plot(sc1;                   ymax=180, title=totitle(sc1))
savefig(p, "doc/pic/score1.png")


# bowled out
sc2 = sc"ITA 92/10 5.3"
p = plot(sc2;                   ymax=180, title=totitle(sc2))
savefig(p, "doc/pic/score2.png")


# same with run rate
sc3 = sc"ITA 142/7 13.2"
p = plot(sc3;                   ymax=180, title=totitle(sc3))
savefig(p, "doc/pic/score3.png")






# Match 1
mt1 = mt"ITA 162/7 20, AUS 99/10 6.3"
p = plot(mt1,                   ymax=180, title=totitle(mt1))
savefig(p, "doc/pic/match1.png")

# Match 2
mt2 = mt"ITA 142/7 10.2, IND 140/2 20"
p = plot(mt2,                   ymax=180, title=totitle(mt2))
savefig(p, "doc/pic/match2.png")

# ..and its series
SR = Series([mt1, mt2])
p = plot(SR)
savefig(p, "doc/pic/series1.png")






# SERIES ENG
mteng1 = mt"ENG 165/6 20, AUS 201/7 20"
mteng2 = mt"ENG 50/2 3.1, OMA 47 13.2"
SReng = Series([mteng1, mteng2])
p = plot(SReng)
savefig(p, "doc/pic/seriesEngA.png")


mteng2B = mt"ENG 200/2 20, OMA 47 13.2"
SRengB = Series([mteng1, mteng2B])
p = plot(SRengB)
savefig(p, "doc/pic/seriesEngB.png")



mteng2C = mt"ENG 220/2 20, OMA 47 13.2"
SRengC = Series([mteng1, mteng2C])
p = plot(SRengC)
savefig(p, "doc/pic/seriesEngC.png")





# TEST OF FULL GROUP STAGE

mteng3 = mt"ENG 125/5 10/10, NAM 84/3 10/10"
# ATTENTION: DLS said ENG had scored 125 instead of actual 122!!!

SReng_check = Series([mteng1, mteng2, mteng3])
p = plot(SReng_check)
# result = 3.611 === Google table (with DLS correction)



### alternative input:

SR = series"""
# first match against SCO was no result
ENG 165/6 20, AUS 201/7 20
ENG 50/2 3.1, OMA 47 13.2        # no OMA wickets => bowled out
ENG 125/5 10/10, NAM 84/3 10/10  # only 10 overs & DLS deemed 122 runs worth 125 (target 126)
"""
plot(SR)


