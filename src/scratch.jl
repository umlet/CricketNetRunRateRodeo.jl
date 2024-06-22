#!/usr/bin/env julia

#using GR
#gr()
#import PlotlyJS as Pjs
#plotlyjs()

using Plots

using .CricketNetRunRateRodeo

m1 = mt"ITA 142/7 13.2, IND 45/10 20"
m2 = mt"ITA 162/7 16.2, AUS 12/10 20"

#plot(m1)

SR = Series([m1,m2])

plot(SR)
