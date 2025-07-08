; ---------------------------------------------------------------
;  Pawns-&-Kings Chess – inšpriácia - Sebastian Lague, ccl.northwestern.edu/netlogo/models/community/Chess
;  Autor : Bc.Pavol Lukačka
;  Figúrky : iba pešiaci a kráľ na každej strane – bez promócie, bez en‑passant
; ---------------------------------------------------------------

extensions [table]                       ;; na hash‑tabuľky

globals [
  turn            ;; kto je na ťahu: "white" | "black"
  move-stack      ;; zásobník ťahov pre undo pri α‑β prooningu
  nodes-searched  ;; uzly prehľadané v aktuálnom ťahu
  total-nodes     ;; kumulatívny počet uzlov
  last-eval       ;; hodnota poslednej pozície
  pos-counts      ;; table <kľúč pozície → počet výskytov>
  repetition-limit;; koľko opakovaní znamená remízu (štandardne 3)
  shape-map       ;; mapovanie typu figúrky → tvar
  depth-limit     ;; hĺbka hľadania
]

breed [pieces piece]
pieces-own [ptype side]          ;; "pawn" | "king", "white" | "black"

; -----------------------------  SETUP  --------------------------

to setup
  clear-all
  resize-world 0 7 0 7           ;; 8 × 8 šachovnica
  set shape-map table:from-list [
    ["pawn" "chess pawn"]     ;; vstavané tvary
    ["king" "chess king"]    ;; prípadne "crown" / "circle"
  ]
  ask patches [                  ;; vytvor šachovnicový vzor
    set pcolor ifelse-value ((pxcor + pycor) mod 2 = 0) [113] [33]
  ]
  set move-stack []
  set total-nodes 0
  set last-eval evaluate
  ;; --- evidencia opakovaní ------------------------------------
  set pos-counts table:make
  set repetition-limit 3         ;; zmeň na 2 pre dvojité opakovanie
  record-position                ;; ulož začiatočnú pozíciu

  ;; --- príprava grafov ----------------------------------------
  set-current-plot "Evaluation"       clear-plot
  set-current-plot-pen "eval"
  set-current-plot "Nodes/ply"       clear-plot
  set-current-plot-pen "nodes"
  set-current-plot "Material diff"   clear-plot
  set-current-plot-pen "pawns"
  set-current-plot "King distance"   clear-plot
  set-current-plot-pen "distance"

  set turn "white"
  make-start-position
  reset-ticks
end


to make-start-position              ;; klasická úvodná zostava
  ;; pešiaci
  foreach range 8 [ i ->
    ask patch i 1 [ make-piece "pawn" "white" ]
    ask patch i 6 [ make-piece "pawn" "black" ]
  ]
  ;; králi
  ask patch 4 0 [ make-piece "king" "white" ]
  ask patch 4 7 [ make-piece "king" "black" ]
end


to make-piece [kind col]            ;; vytvor figúrku na aktuálnom patchi
  let shp table:get shape-map kind
  sprout-pieces 1 [
    set shape shp
    set size 1
    set ptype kind
    set side  col
    set color ifelse-value col = "white" [white] [black]
  ]
end

; ------------------------------  MAIN  --------------------------

to go
  ;; --- kontrola konca hry -------------------------------------
  if not any? pieces with [ptype = "king" and side = turn] [
    user-message (word turn "‑ov kráľ bol chytený – koniec hry.")
    stop
  ]

  set nodes-searched 0
  let best best-move turn depth-limit -999 999
  if empty? best [
    user-message (word "remíza – " turn " nemá ťah.")
    stop
  ]

  ;; --- vykonaj najlepší ťah -----------------------------------
  do-move best
  set last-eval evaluate
  set total-nodes total-nodes + nodes-searched

  ;; --- aktualizuj grafy ---------------------------------------
  set-current-plot "Evaluation"
  plotxy ticks last-eval
  set-current-plot "Nodes/ply"
  plotxy ticks nodes-searched
  set-current-plot "Material diff"
  plotxy ticks pawn-balance
  set-current-plot "King distance"
  plotxy ticks king-distance

  ;; --- odovzdaj ťah súperovi ----------------------------------
  set turn opposite turn
  record-position
  tick
end

; ----------  POMOCNÁ: bezpečný krok ---------------

; kontext korytnačky – vráti cieľový patch alebo nobody mimo dosky

to-report patch-step [d-x d-y]
  let nx pxcor + d-x
  let ny pycor + d-y
  if (nx < 0) or (nx > 7) or (ny < 0) or (ny > 7) [ report nobody ]
  report patch nx ny
end

; ---------------  GENERÁCIA ŤAHOV ------------------------------

; vracia zoznam legálnych ťahov pre farbu col

to-report legal-moves [col]
  let mv []
  ask pieces with [side = col] [
    let local []
    ;; pešiak -----------------------------------------------
    if ptype = "pawn" [
      let dir ifelse-value side = "white" [1] [-1]
      let fwd patch-step 0 dir
      if (fwd != nobody) and not any? pieces-on fwd [
        set local lput (list self fwd) local
      ]
      foreach [-1 1] [d-x ->
        let tgt patch-step d-x dir
        if (tgt != nobody) and any? (pieces-on tgt) with
           [side != [side] of myself] [
          set local lput (list self tgt) local
        ]
      ]
    ]
    ;; kráľ ---------------------------------------------------
    if ptype = "king" [
      foreach [[1 0] [-1 0] [0 1] [0 -1]
               [1 1] [1 -1] [-1 1] [-1 -1]] [d ->
        let tgt patch-step (item 0 d) (item 1 d)
        if (tgt != nobody) and
           (not any? pieces-on tgt or
            [side] of one-of pieces-on tgt != side) [
          set local lput (list self tgt) local
        ]
      ]
    ]
    set mv sentence mv local
  ]
  report mv
end

; ------------------- MININIMAX chess algoritmus s α‑β prooningom-------------------------

 to-report best-move [col depth alpha beta]
  let best []
  let moves legal-moves col
  if empty? moves [ report best ]

  ifelse col = "white"
  [                                   ;; MAX hráč
    let value -999
    let i 0
    while [i < length moves and beta > alpha] [
      let m item i moves
      set i i + 1
      do-move m
      let s minimax (opposite col) (depth - 1) alpha beta
      undo-move
      if s > value [ set value s set best m ]
      set alpha max (list alpha value)
    ]
  ]
  [                                   ;; MIN hráč
    let value 999
    let i 0
    while [i < length moves and beta > alpha] [
      let m item i moves
      set i i + 1
      do-move m
      let s minimax (opposite col) (depth - 1) alpha beta
      undo-move
      if s < value [ set value s set best m ]
      set beta min (list beta value)
    ]
  ]
  report best
end

 to-report minimax [col depth alpha beta]
  set nodes-searched nodes-searched + 1
  if depth <= 0 [ report evaluate ]
  let moves legal-moves col
  if empty? moves [ report evaluate ]

  ifelse col = "white"
  [                                 ;; MAX
    let val -999
    let i 0
    while [i < length moves and beta > alpha] [
      let m item i moves
      set i i + 1
      do-move m
      let s minimax (opposite col) (depth - 1) alpha beta
      undo-move
      if s > val [ set val s ]
      set alpha max (list alpha val)
    ]
    report val
  ]
  [                                 ;; MIN
    let val 999
    let i 0
    while [i < length moves and beta > alpha] [
      let m item i moves
      set i i + 1
      do-move m
      let s minimax (opposite col) (depth - 1) alpha beta
      undo-move
      if s < val [ set val s ]
      set beta min (list beta val)
    ]
    report val
  ]
end

; -------------  ŤAH / UNDO (zásobník) --------------------------

to do-move [m]                  ;; m = [piece tgt]
  let mover first m
  let tgt   last  m
  let orig  [patch-here] of mover

  ;; branie?
  let cap-kind nobody
  let cap-side nobody
  if any? pieces-on tgt [
    let victim one-of pieces-on tgt
    set cap-kind [ptype] of victim
    set cap-side [side]  of victim
    ask victim [ die ]
  ]

  ask mover [ move-to tgt ]
  set move-stack fput (list mover orig tgt cap-kind cap-side) move-stack
end


to undo-move
  let rec first move-stack
  set move-stack but-first move-stack
  let mover     item 0 rec
  let orig      item 1 rec
  let tgt       item 2 rec
  let cap-kind  item 3 rec
  let cap-side  item 4 rec
  ask mover [ move-to orig ]
  if cap-kind != nobody [
    ask tgt [ make-piece cap-kind cap-side ]
  ]
end

; -----------------------  HODNOTENIE ----------------------------

to-report evaluate
  let score 0
  ask pieces [
    set score score +
      (ifelse-value ptype = "pawn" [1] [100]) *
      (ifelse-value side = "white" [1] [-1])
  ]
  report score
end


to-report opposite [col]
  report ifelse-value col = "white" ["black"] ["white"]
end

; -----------------------  ANALÝZA STAVU -------------------------

to-report pawn-balance
  report (count pieces with [ptype = "pawn" and side = "white"]) -
         (count pieces with [ptype = "pawn" and side = "black"])
end


to-report king-distance
  let k1 one-of pieces with [ptype = "king" and side = "white"]
  let k2 one-of pieces with [ptype = "king" and side = "black"]
  if (k1 = nobody) or (k2 = nobody) [ report 0 ]
  report max (list abs ([pxcor] of k1 - [pxcor] of k2)
                   abs ([pycor] of k1 - [pycor] of k2))
end

; -----------------------  ANALÝZA OPAKUJÚCICH STAVOV -------------------------

to-report position-key            ;; reťazec jednoznačne opisujúci pozíciu
  let lines []
  ask pieces [
    set lines lput (word ptype " " side " " pxcor " " pycor) lines
  ]
  set lines sort lines            ;; deterministický poriadok

  ;; spoj všetko do jedného kľúča
  let k turn                      ;; začni farbou na ťahu
  foreach lines [ l ->
    set k (word k "|" l)
  ]
  report k
end


to record-position                ;; aktualizuj tabuľku opakovaní
  let k position-key
  let n 1
  if table:has-key? pos-counts k [
    set n table:get pos-counts k + 1
  ]
  table:put pos-counts k n
  if n >= repetition-limit [
    user-message (word "Remíza – pozícia sa opakovala " n "×.")
    stop
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
55
34
712
692
-1
-1
81.13
1
10
1
1
1
0
1
1
1
0
7
0
7
0
0
1
ticks
30.0

BUTTON
765
88
951
121
Run whole game
go\n
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
765
38
951
71
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
767
139
953
172
Step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
864
222
1337
507
Evaluation
ticks
last-eval
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"eval" 1.0 0 -8330359 true "" ""

MONITOR
1208
35
1357
80
king-distance
king-distance
17
1
11

MONITOR
1207
92
1358
137
White pawns
count pieces with [ptype = \"pawn\" and side = \"white\"]
17
1
11

MONITOR
1207
144
1358
189
Black pawns
count pieces with [ptype = \"pawn\" and side = \"black\"]
17
1
11

MONITOR
1408
86
1556
131
Nodes this ply
nodes-searched
17
1
11

MONITOR
1406
142
1558
187
Total nodes
total-nodes
17
1
11

MONITOR
1407
32
1557
77
Eval (white +)
last-eval
17
1
11

MONITOR
1017
91
1157
136
Side to move
turn
17
1
11

MONITOR
1017
37
1157
82
Move #
ticks
17
1
11

PLOT
860
525
1340
786
Nodes/ply
ticks
nodes-searched
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"nodes" 1.0 0 -16777216 true "" ""

PLOT
1440
223
1951
504
Material diff
	ticks
pawn-balance
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"pawns" 1.0 0 -14454117 true "" ""

PLOT
1442
521
1947
788
King distance
ticks
king-distance
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"distance" 1.0 0 -5298144 true "" ""

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

chess bishop
false
0
Circle -7500403 true true 135 35 30
Circle -16777216 false false 135 35 30
Rectangle -7500403 true true 90 255 210 300
Line -16777216 false 75 255 225 255
Rectangle -16777216 false false 90 255 210 300
Polygon -7500403 true true 105 255 120 165 180 165 195 255
Polygon -16777216 false false 105 255 120 165 180 165 195 255
Rectangle -7500403 true true 105 165 195 150
Rectangle -16777216 false false 105 150 195 165
Line -16777216 false 137 59 162 59
Polygon -7500403 true true 135 60 120 75 120 105 120 120 105 120 105 90 90 105 90 120 90 135 105 150 195 150 210 135 210 120 210 105 195 90 165 60
Polygon -16777216 false false 135 60 120 75 120 120 105 120 105 90 90 105 90 135 105 150 195 150 210 135 210 105 165 60

chess king
false
0
Polygon -7500403 true true 105 255 120 90 180 90 195 255
Polygon -16777216 false false 105 255 120 90 180 90 195 255
Polygon -7500403 true true 120 85 105 40 195 40 180 85
Polygon -16777216 false false 119 85 104 40 194 40 179 85
Rectangle -7500403 true true 105 105 195 75
Rectangle -16777216 false false 105 75 195 105
Rectangle -7500403 true true 90 255 210 300
Line -16777216 false 75 255 225 255
Rectangle -16777216 false false 90 255 210 300
Rectangle -7500403 true true 165 23 134 13
Rectangle -7500403 true true 144 0 154 44
Polygon -16777216 false false 153 0 144 0 144 13 133 13 133 22 144 22 144 41 154 41 154 22 165 22 165 12 153 12

chess knight
false
0
Line -16777216 false 75 255 225 255
Polygon -7500403 true true 90 255 60 255 60 225 75 180 75 165 60 135 45 90 60 75 60 45 90 30 120 30 135 45 240 60 255 75 255 90 255 105 240 120 225 105 180 120 210 150 225 195 225 210 210 255
Polygon -16777216 false false 210 255 60 255 60 225 75 180 75 165 60 135 45 90 60 75 60 45 90 30 120 30 135 45 240 60 255 75 255 90 255 105 240 120 225 105 180 120 210 150 225 195 225 210
Line -16777216 false 255 90 240 90
Circle -16777216 true false 134 63 24
Line -16777216 false 103 34 108 45
Line -16777216 false 80 41 88 49
Line -16777216 false 61 53 70 58
Line -16777216 false 64 75 79 75
Line -16777216 false 53 100 67 98
Line -16777216 false 63 126 69 123
Line -16777216 false 71 148 77 145
Rectangle -7500403 true true 90 255 210 300
Rectangle -16777216 false false 90 255 210 300

chess pawn
false
0
Circle -7500403 true true 105 65 90
Circle -16777216 false false 105 65 90
Rectangle -7500403 true true 90 255 210 300
Line -16777216 false 75 255 225 255
Rectangle -16777216 false false 90 255 210 300
Polygon -7500403 true true 105 255 120 165 180 165 195 255
Polygon -16777216 false false 105 255 120 165 180 165 195 255
Rectangle -7500403 true true 105 165 195 150
Rectangle -16777216 false false 105 150 195 165

chess queen
false
0
Circle -7500403 true true 140 11 20
Circle -16777216 false false 139 11 20
Circle -7500403 true true 120 22 60
Circle -16777216 false false 119 20 60
Rectangle -7500403 true true 90 255 210 300
Line -16777216 false 75 255 225 255
Rectangle -16777216 false false 90 255 210 300
Polygon -7500403 true true 105 255 120 90 180 90 195 255
Polygon -16777216 false false 105 255 120 90 180 90 195 255
Rectangle -7500403 true true 105 105 195 75
Rectangle -16777216 false false 105 75 195 105
Polygon -7500403 true true 120 75 105 45 195 45 180 75
Polygon -16777216 false false 120 75 105 45 195 45 180 75
Circle -7500403 true true 180 35 20
Circle -16777216 false false 180 35 20
Circle -7500403 true true 140 35 20
Circle -16777216 false false 140 35 20
Circle -7500403 true true 100 35 20
Circle -16777216 false false 99 35 20
Line -16777216 false 105 90 195 90

chess rook
false
0
Rectangle -7500403 true true 90 255 210 300
Line -16777216 false 75 255 225 255
Rectangle -16777216 false false 90 255 210 300
Polygon -7500403 true true 90 255 105 105 195 105 210 255
Polygon -16777216 false false 90 255 105 105 195 105 210 255
Rectangle -7500403 true true 75 90 120 60
Rectangle -7500403 true true 75 84 225 105
Rectangle -7500403 true true 135 90 165 60
Rectangle -7500403 true true 180 90 225 60
Polygon -16777216 false false 90 105 75 105 75 60 120 60 120 84 135 84 135 60 165 60 165 84 179 84 180 60 225 60 225 105

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
