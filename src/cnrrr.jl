


using Plots
import Printf: format, Format

struct EnduserError <: Exception
    msg::String
    exitcode::Int64
    EnduserError(msg::AbstractString, exitcode::Int64=99) = new(msg, exitcode)
end
erroruser(msg::AbstractString, exitcode::Int64=99) = throw(EnduserError(msg, exitcode))
# inner/core error message (after standard red "ERROR: "-prefix)
Base.showerror(io::IO, ex::EnduserError) = print(io, ex.msg) 
# this would usually add backtrace after a call to showerror(io,ex); we short-circuit
Base.showerror(io::IO, ex::EnduserError, _bt; backtrace=true) = showerror(io, ex)




toint(x) = parse(Int64, x)
tofloat(x) = parse(Float64, x)  # TODO remove its use below where possible..

tostr3(x::AbstractFloat) = format(Format("%.3f"), x)

function tointex(x, e::Union{<:AbstractString, Nothing}=nothing, f::Function=erroruser)::Int64
    e === nothing  &&  return toint(x)
    ret = tryparse(Int64, x)
    ret === nothing  &&  ( f(e);  @assert false#=f does not throw..=# )
    return ret
end

function splitex(S, s, n::Int64, e::Union{<:AbstractString, Nothing}=nothing, f::Function=erroruser)
    ss = split(S, s)
    length(ss) == n  &&  return ss
    # throw
    e === nothing  &&  error("splitex: number of string splits != $(n)")
    f(e);  @assert false
end




###############################################################################
# Overs

struct Overs  # negative/zero Overs allowed for math
    balls::Int64
    function Overs(s::AbstractString)
        if contains(s, ".")
            ss = splitex(s, ".", 2,         "Overs: invalid format in '$(s)'; must be like '13.2'")
            ofull,opart = tointex.(ss,      "Overs: invalid format in '$(s)'; must be like '13.2'")
            !(0 < opart < 6)  &&  erroruser("Overs: invalid format in '$(s)'; partial overs must be between '.1' and '.5'")
            return new(ofull * 6 + opart)
        end
        ofull = tointex(s,                  "Overs: invalid format in '$(s)'; must be like '13.2'")
        return new(ofull*6)
    end
    Overs(ov::Overs) = ov
    global _Oversfromballs(balls::Int64) = new(balls)
end

tofloat(x::Overs)::Float64 = x.balls / 6.0
tostr3(x::Overs)::String = tostr3(tofloat(x))

macro ov_str(s::AbstractString)  Overs(s)  end
macro overs_str(s::AbstractString)  Overs(s)  end

# - string() calls show()!
# - string interpolation too
function Base.show(io::IO, x::Overs)
    ofull::Int64 = div(x.balls, 6)
    opart::Int64 = mod(x.balls, 6)
    print(io, ofull)
    opart > 0  &&  print(io, ".", opart)
    nothing
end
function Base.show(io::IO, mime::MIME"text/plain", x::Overs)
    #compact = get(io, :compact, false)
    print(io, "$(x) overs ($(tostr3(tofloat(x))))")
end

# one operator defines rest
Base.:(<)(a::Overs, b::Overs) = a.balls < b.balls

#Base.:(<)(a::Overs, O::Int64) = a.balls < O * 6  # to allow nice '<0', '<20'

Base.:(+)(a::Overs, b::Overs)  = _Oversfromballs(a.balls + b.balls)
Base.:(-)(a::Overs, b::Overs)  = _Oversfromballs(a.balls - b.balls)

Base.:(/)(a::Overs, b) = tofloat(a) / b
Base.:(/)(a, b::Overs) = a / tofloat(b)




###############################################################################
# Score

_DEFAULT_OVERS = ov"20"


struct Score
    team::String
    runs::Int64
    wickets::Int64
    overs::Overs
    matchovers::Overs
    function Score(s::AbstractString)
        team,srw,sovers = splitex(s, " ", 3,                      "Score: invalid format in '$(s)'; must be like 'ITA 142[/7] 13[.2][/20]'")
        team == ""                                  &&  erroruser("Score: invalid format in '$(s)'; team name must not be empty")

        runs,wickets =  if !contains(srw, "/")
                            i = tointex(srw,                      "Score: invalid format in runs/wickets '$(srw)'; must be like '142[/7]'")
                            (i, 10)
                        else
                            ss = splitex(srw, "/", 2,             "Score: invalid format in runs/wickets '$(srw)'; must be like '142[/7]'")
                            i1, i2 = tointex.(ss,                 "Score: invalid format in runs/wickets '$(srw)'; must be like '142[/7]'")
                            (i1, i2)
                        end

        overs,matchovers =  if !contains(sovers, "/")
                                (Overs(sovers), _DEFAULT_OVERS)
                            else
                                ss = splitex(sovers, "/", 2,      "Score: invalid format in overs/matchovers '$(sovers)'; must be like '13.2[/20]'")
                                (Overs(ss[1]), Overs(ss[2]))
                            end

        runs < 0                                    &&  erroruser("Score: invalid runs '$(runs)'; must be >= 0 ")
        ( wickets < 0  ||  wickets > 10 )           &&  erroruser("Score: invalid wickets '$(wickets)'; must be between 0 and 10 (or none = 10 = blowled-out)")

        overs <= ov"0"                              &&  erroruser("Score: invalid overs '$(overs)'; must be > 0 ")
        matchovers <= ov"0"                         &&  erroruser("Score: invalid matchovers '$(matchovers)'; must be > 0 ")
        overs > matchovers                          &&  erroruser("Score: invalid overs '$(overs)'; must be <= matchovers=$(matchovers)")
        overs.balls < wickets                       &&  erroruser("Score: invalid wickets '$(wickets)'; must be <= balls from overs = $(overs.balls)")

        return new(team, runs, wickets, overs, matchovers)
    end
end

macro sc_str(s::AbstractString)  Score(s)  end
macro score_str(s::AbstractString)  Score(s)  end

function Base.show(io::IO, x::Score)
    print(io, """Score("$(x.team) $(x.runs)/$(x.wickets) $(x.overs)/$(x.matchovers)")""")
end
function Base.show(io::IO, mime::MIME"text/plain", x::Score)
    print(io,   "$(x.team): $(x.runs) ", 
                x.wickets<10 ? "for $(x.wickets), " : "(bowled out), ",
                "in $(x.overs) overs (of $(x.matchovers)); ",
                "rr = $(x.runs)/$(x.overs)ov = $(x.runs)/$(tostr3(x.overs)) = $(srr(x))"
                )
end

get_xtick(sc::Score)::Float64 = tofloat(sc.matchovers)
get_xmax(sc::Score)::Float64  = tofloat(sc.matchovers)
get_ymax(sc::Score)::Float64  = sc.runs * 1.1

exhausted(sc::Score)::Bool = sc.wickets == 10  ||  sc.overs == sc.matchovers

effovers(sc::Score)::Overs = sc.wickets < 10  ?  sc.overs  :  sc.matchovers

rr(sc::Score)::Float64 = sc.runs / effovers(sc)
srr(sc::Score)::String = tostr3(rr(sc))


function RR(scs::AbstractVector{Score})::Float64
    runs = sum( sc.runs for sc in scs )
    overs = sum( effovers(sc) for sc in scs )
    return runs/overs
end
sRR(scs) = tostr3(RR(scs))




###############################################################################
# Match

struct Match
    sc1::Score
    sc2::Score
    function Match(sc1::Score, sc2::Score)
        sc1.matchovers != sc2.matchovers  &&  error("Match: the scores' matchovers differ")

        if sc1.runs > sc2.runs
            !exhausted(sc2)  &&  error("Match: in a decisive game, the loser must have exhausted wickets or overs (or both)")
        elseif sc1.runs < sc2.runs
            !exhausted(sc1)  &&  error("Match: in a decisive game, the loser must have exhausted wickets or overs (or both)")
        else  # draw; both must be exhausted
            ( !exhausted(sc1)  ||  !exhausted(sc2) )  &&  error("Match: in a drawn game, both must have exhausted wickets or overs (or both)")
        end

        return new(sc1, sc2)
    end
    function Match(s::AbstractString)
        ss = splitex(s, ", ", 2,    "Match: invalid format in '$(s)'; must be like 'ITA 142[/7] 12[.5][/20], IND 141[/3] 19[.2][/20]'")
        return Match(Score(ss[1]), Score(ss[2]))
    end
    Match(mt::Match) = mt
end
matchovers(mt::Match) = mt.sc1.matchovers

macro mt_str(s::AbstractString)  return Match(s)  end
macro match_str(s::AbstractString)  return Match(s)  end

function Base.show(io::IO, mime::MIME"text/plain", x::Match)
    show(io, mime, x.sc1)
    print(io, " vs. ")
    show(io, mime, x.sc2)
end

get_xtick(mt::Match)::Float64 = tofloat(matchovers(mt))
get_xmax(mt::Match)::Float64  = tofloat(matchovers(mt))
get_ymax(mt::Match)::Float64  = max(mt.sc1.runs, mt.sc2.runs) * 1.1

function getownoppscores(mt::Match, ownteam::Union{<:AbstractString, Nothing})
    ownteam === nothing  &&  return (mt.sc1, mt.sc2)
    mt.sc1.team == ownteam  &&  return  (mt.sc1, mt.sc2)
    mt.sc2.team == ownteam  &&  return  (mt.sc2, mt.sc1)
    error("getownoppscores: invalid team lookup '$(ownteam)' in match '$(mt)'")
end




###############################################################################
# Series

# note: series can contain match with smaller matchovers (DLS) [I hope it works this way..]
struct Series
    ownteam::String
    mts::Vector{Match}
    function Series(itr)
        mts::Vector{Match} = collect(Match.(itr))
        length(mts) == 0  &&  error("Series: must not be empty")

        team1,team2 = mts[1].sc1.team, mts[1].sc2.team
        b1,b2=true,true
        for mt in mts
            !( team1 in (mt.sc1.team, mt.sc2.team) )  &&  ( b1 = false )
            !( team2 in (mt.sc1.team, mt.sc2.team) )  &&  ( b2 = false )
        end
        b1   &&  !b2  &&  return new(team1, mts)
        !b1  &&   b2  &&  return new(team2, mts)
        b1   &&   b2  &&  return new(team1, mts)
        erroruser("Series: an NRR series must have a team that takes part in each match")
    end
end
function Base.push!(SR::Series, mt::Match)
    SR.ownteam in (mt.sc1.team, mt.sc2.team)  ||  error("Series: own team '$(SR.ownteam)' must take part in match")
    push!(SR.mts, mt)
    return SR
end

get_xtick(SR::Series)::Float64 = maximum(get_xtick.(SR.mts))
get_xmax(SR::Series)::Float64  = tofloat(sum( matchovers(mt) for mt in SR.mts ))
get_ymax(SR::Series)::Float64  = sum( max(mt.sc1.runs, mt.sc2.runs) for mt in SR.mts ) * 1.1

macro series_str(s::AbstractString)
    mts = Match[]
    for line in eachsplit(s, "\n")
        line = split(line, "#") |> first
        line = strip(line)
        line == ""  &&  continue
        startswith(line, "#")  &&  continue
        push!(mts, Match(line))
    end
    return Series(mts)
end

function getownoppscores(SR::Series)
    OWN,OPP = Score[], Score[]
    for mt in SR.mts
        own,opp = getownoppscores(mt, SR.ownteam)
        push!(OWN, own); push!(OPP, opp)
    end
    return (OWN,OPP)
end

RR(SR::Series)      = RR(getownoppscores(SR)[1])
RRopp(SR::Series)   = RR(getownoppscores(SR)[2])
NRR(SR::Series)     = RR(SR) - RRopp(SR)

sRR(SR::Series)     = RR(SR)    |> tostr3
sRRopp(SR::Series)  = RRopp(SR) |> tostr3
sNRR(SR::Series)    = NRR(SR)   |> tostr3

function Base.show(io::IO, mime::MIME"text/plain", SR::Series)
    print(io,   "Series of $(length(SR.mts)) $(SR.ownteam) matches; ",
                "(own) RR = $(sRR(SR)); (opp) RR' = $(sRRopp(SR)); NRR = $(sNRR(SR))"
                )
end




###############################################################################
# PLOT NEW

_OWNCOLOR,_OPPCOLOR = Plots.palette(:default)[1], Plots.palette(:default)[2]
_dLW = Dict(1=>4, 0=>3, -1=>2)
_dSIZE = Dict(Score => (300,300), Match => (300,300), Series => (600,600))
getsize(x) = _dSIZE[typeof(x)]

function makecanvas(x::Union{Score, Match, Series}; title::AbstractString="", ymax=nothing)
    size = getsize(x)

    xmax,  ymax   = get_xmax(x),            (ymax===nothing ? get_ymax(x) : ymax)
    xlims, ylims  = (0, xmax),              (0, ymax)
    xticks,yticks = 0:get_xtick(x):xmax,    0:100:ymax

    xlabel,ylabel = "overs",                "runs"
    legend = false

    p = plot(; size=size, xlims=xlims, ylims=ylims, xticks=xticks, yticks=yticks, legend=legend, xlabel=xlabel, ylabel=ylabel, title=title)
    return p
end

struct ScoreCoor
    x_overs::Float64
    y_runs::Float64
end
Base.:(+)(c::ScoreCoor, sc::Score) = ScoreCoor(c.x_overs + tofloat(effovers(sc)), c.y_runs + sc.runs)

function toxsys(sc::Score, at::ScoreCoor)
    if sc.wickets < 10  ||  sc.overs == sc.matchovers
        return  (   [0.0, tofloat(sc.overs)]                                .+ at.x_overs, 
                    [0.0, sc.runs]                                          .+ at.y_runs   )
    end
    return      (   [0.0, tofloat(sc.overs),    tofloat(sc.matchovers)]     .+ at.x_overs,
                    [0.0, sc.runs,              sc.runs]                    .+ at.y_runs   )
end

function _plotscoreat!(p, sc::Score; at=ScoreCoor(0.0, 0.0), wincode=1, own=true, printrr=true, plotdiag=:auto)
    xs,ys = toxsys(sc, at)

    color = own  ?  _OWNCOLOR  :  _OPPCOLOR
    lw = _dLW[wincode]

    plot!(p, xs, ys;   color=color, linewidth=lw, arrow=true)
    if printrr
        x,y = xs[end], ys[end]
        s = "rr = " * srr(sc)
        annotate!(p, x, y, text(s, :right, :top))
    end
    if plotdiag === :auto
        if length(xs) > 2  # bended vector!
            plot!(p, [xs[1],xs[end]], [ys[1],ys[end]];   color=:green, linewidth=1, arrow=true)
        end
    end
    return p
end



function Plots.plot(sc::Score;   title="", ymax=nothing, printrr=true, plotdiag=:auto)
    p = makecanvas(sc;   title=title, ymax=ymax)
    _plotscoreat!(p, sc;   wincode=1, own=true, printrr=printrr, plotdiag=plotdiag)
    return p
end

function getwincodes(sc1::Score, sc2::Score)
    sc1.runs > sc2.runs  &&  return (1,-1)
    sc1.runs < sc2.runs  &&  return (-1,1)
    return (0,0)
end

function Plots.plot(mt::Match;   title="", ymax=nothing, printrr=false, plotdiag=false)
    p = makecanvas(mt;   title=title, ymax=ymax)

    scown,scopp = getownoppscores(mt, nothing)  # we do not know in a non-series
    wcown,wcopp = getwincodes(scown, scopp)

    _plotscoreat!(p, scown;   wincode=wcown, own=true,  printrr=printrr, plotdiag=plotdiag)
    _plotscoreat!(p, scopp;   wincode=wcopp, own=false, printrr=printrr, plotdiag=plotdiag)

    return p
end

function Plots.plot(SR::Series;   title="")
    p = makecanvas(SR;  title=title)

    scsown,scsopp = getownoppscores(SR)

    atown,atopp = ScoreCoor(0,0), ScoreCoor(0,0)
    for (scown,scopp) in zip(scsown,scsopp)
        wcown,wcopp = getwincodes(scown, scopp)

        _plotscoreat!(p, scown;   at=atown, wincode=wcown, own=true,  printrr=false, plotdiag=false)
        _plotscoreat!(p, scopp;   at=atopp, wincode=wcopp, own=false, printrr=false, plotdiag=false)
        atown += scown;  atopp += scopp
    end

    plot!(p, [0, atown.x_overs], [0, atown.y_runs]; color=:green, linewidth=1, arrow=true)
    plot!(p, [0, atopp.x_overs], [0, atopp.y_runs]; color=:green, linewidth=1, arrow=true)

    # RR
    x,y = atown.x_overs, atown.y_runs
    s = "RR = " * sRR(SR)
    annotate!(p, x, y, text(s, :right, :top))
    # RR'
    x,y = atopp.x_overs, atopp.y_runs
    s = "RR' = " * sRRopp(SR)
    annotate!(p, x, y, text(s, :right, :top))
    # NRR
    x,y = 3, atown.y_runs
    s = "NRR = " * sNRR(SR)
    annotate!(p, x, y, text(s, :left, :top))

    return p
end















