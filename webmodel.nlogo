extensions [time]

globals [dt

  academic-buildings
  residential-buildings
  activities-buildings
  recreational-buildings
  dining-halls
  offcampus

  max-infected
  transmissibility
  infection-radius
  R0
  R0-avg
  length-of-infection
  mean-onset-time
  mean-recovery-time
]

breed [students student]

students-own[
  target
  infected?
  exposed?
  immune?
  recovered?

  dorm
  contacts-per-tick
  masked?
]

to setup
  clear-all
  import-drawing "map.png"
  ;; Load patches and map of newark of Newark, DE
  import-pcolors-rgb "campus_image.bmp"


  ;; Assigning patch names for buildings
  set academic-buildings patches with [pcolor = [255 170 0]]
  set residential-buildings patches with [pcolor = [38 115 0]]
  set activities-buildings patches with [pcolor = [168 0 132]]
  set recreational-buildings patches with [pcolor = [0 112 255]]
  set dining-halls patches with [pcolor = [230 230 0]]
  set offcampus patches with [pcolor = [136 0 21]]

  ;; Assign values for infection parameters
  set transmissibility 0.0015
  set infection-radius 10 / sqrt(200) * sqrt(num-students)
  set length-of-infection 336 ;; 2 ticks = 30 min :: 7 * 24 * 2
  set R0-avg 0
  set mean-onset-time 4
  set mean-recovery-time 14

  ;; Create student agents in the residential areas (green)
  populate-students

  ;; Create the start time
  ;; 1 tick = 15 min
  set dt time:anchor-to-ticks (time:create "2020/09/01 00:00") 15 "minutes"
  time:anchor-schedule time:create "2020/09/01 00:00" 15 "minutes"

  student-schedule
  setup-infected
  reset-ticks
end

to setup-infected
  ask n-of init-infected students [
    set infected? true set color [255 0 0]
    set exposed? true
    set recovered? false

    let infection-onset time:plus dt exp ( ln mean-onset-time + 1 * random-normal 0 1) "days"
    time:schedule-event self [ [] -> set infected? true set color [255 0 0]] infection-onset

    let recovery-time time:plus dt exp ( ln mean-recovery-time + 1 * random-normal 0 1) "days"
    time:schedule-event self [ [] -> set infected? false set color gray set exposed? false set recovered? true] recovery-time
  ]
end

to go
  ;;stop if everyone or noone is infected
  if (count students with [infected?] = 0)
  or (count students with [exposed?] = 0)
  or (count students with [infected?] = num-students)
  [stop]

  infect-susceptibles
  move-students

  ;; Print the clock
  clear-output
  output-print time:show dt "EEEE, MMMM d, yyyy  HH:mm:ss"

  calculate-max-infected

  calculate-R0
  ;; 1 time step
  time:go-until time:plus dt 15 "minutes"

  tick
end

to calculate-R0
  ask students with [infected?] [
    set contacts-per-tick (count other students with [not infected?] in-radius infection-radius)
  ]

  let avg-contacts-per-tick-masked 0
  let masked-infected-students (students with [infected? and masked?])
  if (count masked-infected-students) != 0 [
    set avg-contacts-per-tick-masked mean [contacts-per-tick] of students with [infected? and masked?]
  ]


  let avg-contacts-per-tick-no-masks 0
  let not-masked-infected-students (students with [infected? and not masked?])
  if (count not-masked-infected-students)!= 0 [
    set avg-contacts-per-tick-no-masks mean [contacts-per-tick] of students with [infected? and not masked?]
  ]

  set R0 ((count not-masked-infected-students) * avg-contacts-per-tick-no-masks * length-of-infection * transmissibility + (count masked-infected-students) * 0.2 * avg-contacts-per-tick-masked * length-of-infection * transmissibility) / (count students with [infected?])

  set R0-avg 0.015 * R0 + (1 - 0.015) * R0-avg

end

to infect-susceptibles
  ask students [
    let infected-neighbors-no-masks (count other students with [infected? and not masked?] in-radius infection-radius)
    let infected-neighbors-masked (count other students with [infected? and masked?] in-radius infection-radius)
    ;;let infected-neighbors (count other students with [infected?] in-radius infection-radius)

    ;; Formula of transmissibility to avoid the probability exceeding 1
    if (random-float 1 <  (1 - ((1 - transmissibility) ^ (infected-neighbors-no-masks)) * ((1 - 0.2 * transmissibility) ^ (infected-neighbors-masked))) and not immune? and not exposed?)
    [
      infect
    ]
  ]
end

to infect ;; Procedure to infect the agents and change their color
  set color [225 175 0]
  set exposed? true
  set recovered? false

  let infection-onset time:plus dt exp ( ln mean-onset-time + 1 * random-normal 0 1) "days"
  time:schedule-event self [ [] -> set infected? true set color [255 0 0]] infection-onset

  let recovery-time time:plus dt exp ( ln mean-recovery-time + 1 * random-normal 0 1) "days"
  time:schedule-event self [ [] -> set infected? false set color gray set exposed? false set recovered? true set immune? true] recovery-time
end

to student-schedule ;; Procedure to setup schedule of students
  let fourth-of-students floor num-students / 4
  let half-of-students floor num-students / 2

  ;; Students take-off masks
  time:schedule-repeating-event-with-period
  students [
    [] -> set masked? false
  ] 0 1 "day"

  ;; Some students wear masks
  time:schedule-repeating-event-with-period
  n-of (floor %mask-compliance * num-students / 100) students [
    [] -> set masked? true
  ] 0 1 "day"

  ;; Classes at 8 AM
  time:schedule-repeating-event-with-period
  students with [infected? = false] [
    [] -> if stay-at-home? = false and (quarantine? = false or infected? = false) [move-to one-of academic-buildings]
  ] 32 1 "day"

  time:schedule-repeating-event-with-period
  students with [infected? = true][
    [] -> if stay-at-home? = false and quarantine? = false [move-to one-of academic-buildings]
  ] 32 1 "day"

  ;; Breakfast at 10 AM
  time:schedule-repeating-event-with-period
  n-of fourth-of-students students with [infected? = false] [
    [] -> if stay-at-home? = false and (quarantine? = false or infected? = false) [move-to one-of dining-halls]
  ] 42 1 "day"

  time:schedule-repeating-event-with-period
  students with [infected? = true] [
    [] -> if stay-at-home? = false and quarantine? = false [move-to one-of dining-halls]
  ] 42 1 "day"

  ;; Classes at 10:30 AM
  time:schedule-repeating-event-with-period
  students with [infected? = false] [
    [] -> if stay-at-home? = false and (quarantine? = false or infected? = false) [move-to one-of academic-buildings]
  ] 44 1 "day"

  time:schedule-repeating-event-with-period
  students with [infected? = true] [
    [] -> if stay-at-home? = false and quarantine? = false [move-to one-of academic-buildings]
  ] 44 1 "day"

  ;; Lunch at 1:30 PM
  time:schedule-repeating-event-with-period
  students with [infected? = false] [
    [] -> if stay-at-home? = false and (quarantine? = false or infected? = false) [move-to one-of dining-halls]
  ] 54 1 "day"

  time:schedule-repeating-event-with-period
  students with [infected? = true] [
    [] -> if stay-at-home? = false and quarantine? = false [move-to one-of dining-halls]
  ] 54 1 "day"

  ;; Gym at 2 PM
  time:schedule-repeating-event-with-period
  n-of half-of-students students with [infected? = false] [
    [] -> if stay-at-home? = false and (quarantine? = false or infected? = false) [move-to one-of recreational-buildings]
  ] 56 1 "day"

  time:schedule-repeating-event-with-period
  students with [infected? = true] [
    [] -> if stay-at-home? = false and quarantine? = false [move-to one-of recreational-buildings]
  ] 56 1 "day"

  ;; Student activities at 2 PM
  time:schedule-repeating-event-with-period
  n-of fourth-of-students students with [infected? = false] [
    [] -> if stay-at-home? = false and (quarantine? = false or infected? = false) [move-to one-of activities-buildings]
  ] 56 1 "day"

  time:schedule-repeating-event-with-period
  students with [infected? = true] [
    [] -> if stay-at-home? = false and quarantine? = false [move-to one-of activities-buildings]
  ] 56 1 "day"

  ;; Dorm at 2 PM
  time:schedule-repeating-event-with-period
  n-of fourth-of-students students with [infected? = false] [
    [] -> if stay-at-home? = false and (quarantine? = false or infected? = false) [move-to one-of residential-buildings]
  ] 56 1 "day"

  time:schedule-repeating-event-with-period
  students with [infected? = true] [
    [] -> if stay-at-home? = false and quarantine? = false and (quarantine? = false or infected? = false) [move-to one-of residential-buildings]
  ] 56 1 "day"

  ;; Dorm at 4 PM
  time:schedule-repeating-event-with-period
  students [
    [] -> move-to dorm
  ] 64 1 "day"

  ;; Dinner at 5 PM
  time:schedule-repeating-event-with-period
  students with [infected? = false] [
    [] -> if stay-at-home? = false and (quarantine? = false or infected? = false) [move-to one-of dining-halls]
  ] 68 1 "day"

  time:schedule-repeating-event-with-period
  students with [infected? = true] [
    [] -> if stay-at-home? = false and quarantine? = false [move-to one-of dining-halls]
  ] 68 1 "day"

  ;; Gym at 5:30 PM
  time:schedule-repeating-event-with-period
  n-of half-of-students students with [infected? = false] [
    [] -> if stay-at-home? = false and (quarantine? = false or infected? = false) [move-to one-of recreational-buildings]
  ] 58 1 "day"

  time:schedule-repeating-event-with-period
  students with [infected? = true] [
    [] -> if stay-at-home? = false and quarantine? = false [move-to one-of recreational-buildings]
  ] 58 1 "day"

  ;; Dorm at 8 PM
  time:schedule-repeating-event-with-period
  students [
    [] -> move-to dorm
  ] 80 1 "day"

  ;; Friday Party
  time:schedule-repeating-event-with-period
  n-of half-of-students students with [infected? = false] [
    [] -> if stay-at-home? = false and (quarantine? = false or infected? = false) [move-to one-of offcampus]
  ] 368 7 "day"

  time:schedule-repeating-event-with-period
  students with [infected? = true] [
    [] -> if stay-at-home? = false and quarantine? = false [move-to one-of offcampus]
  ] 368 7 "day"

  ;; Saturday Party
  time:schedule-repeating-event-with-period
  n-of half-of-students students with [infected? = false] [
    [] -> if stay-at-home? = false and (quarantine? = false or infected? = false) [move-to one-of offcampus]
  ] 464 7 "days"

  time:schedule-repeating-event-with-period
  students with [infected? = true] [
    [] -> if stay-at-home? = false and quarantine? = false [move-to one-of offcampus]
  ] 464 7 "days"


end

to move-students ;; Global procedure to move students
  ;; Procedue to make the students perform random walk
  ask students [
    if quarantine? = false or infected? = false [
      let color-here [pcolor] of patch-here
      set target one-of patches in-cone 3 180 with [ pcolor = color-here]
      motion
      if pcolor != color-here [motion]]
  ]
end

to motion ;; Turtle procedure to perform random walk
  rt random 30 - 15
  if target != nobody [
    face target
    move-to target
  ]
  fd random 0.05
end

to populate-students ;; Procedure to create agents for students
  ask n-of num-students residential-buildings [ sprout-students 1]
  ask students [
    set size 5
    set shape "circle"
    set color green
    set dorm patch-here
    set infected? false
    set immune? false
    set exposed? false
    set contacts-per-tick 0
    set masked? false
    set recovered? false
  ]
end

to calculate-max-infected ;; Report monitor variable
  let x (count students with [infected?])
  if x > max-infected
  [set max-infected x]
end
@#$#@#$#@
GRAPHICS-WINDOW
202
94
1203
1095
-1
-1
1.125
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
882
0
881
0
0
1
ticks
30.0

SLIDER
14
107
186
140
num-students
num-students
0
200
200.0
1
1
NIL
HORIZONTAL

BUTTON
122
63
186
97
NIL
go
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
14
62
80
96
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

OUTPUT
880
107
1189
140
11

SLIDER
15
150
187
183
init-infected
init-infected
0
100
11.0
1
1
NIL
HORIZONTAL

PLOT
1227
98
1709
465
Evolution of infection
Days
Number of students
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Infected" 0.02083333333 0 -5298144 true "" "plot (count students with [infected? = true])"
"Susceptible" 0.02083333333 0 -15637942 true "" "plot (count students with [infected? = false and immune? = false])"
"Exposed" 0.02083333333 0 -4079321 true "" "plot (count students with [exposed? = true])"
"Recovered" 0.02083333333 0 -7500403 true "" "plot (count students with [recovered? = true])"

SWITCH
15
232
188
265
stay-at-home?
stay-at-home?
1
1
-1000

SWITCH
15
272
189
305
quarantine?
quarantine?
1
1
-1000

TEXTBOX
203
57
939
85
Simulation of the spread of COVID-19 in University of Delaware Campus
20
0.0
1

TEXTBOX
22
320
186
712
Clicking setup generates an on-campus population of students. The current implementation includes two policies:\n\n1. Stay-at-home: Students don't go to classes and recreational facilities and stay in their respective dormitories.\n\n2. Quarantine: The infected students are asked to isolate themselves in their dorm areas and remain stationary.\n\nThe simulation takes into account class schedules and student activities/recreation on campus.\n\n3. Mask compliance: The mask wearing resets at 00:00 hrs and only the selected percentage of students, chosen randomly, wear masks.\n\n(The purpose of this simulation is illustrative)\n
11
22.0
1

TEXTBOX
1237
539
1522
589
Recreational building/gym
20
105.0
1

TEXTBOX
1236
568
1432
618
Academic building
20
26.0
1

TEXTBOX
1236
599
1558
649
Residential building/dormitories
20
62.0
1

TEXTBOX
1236
628
1491
678
Student activity building
20
125.0
1

TEXTBOX
1237
658
1387
683
Dining halls
20
43.0
1

MONITOR
1228
478
1314
523
NIL
max-infected
2
1
11

TEXTBOX
1238
688
1539
763
Off-campus activities (parties)
20
13.0
1

MONITOR
1324
478
1434
523
instantaneous R0
R0
2
1
11

MONITOR
1443
478
1631
523
Exponential moving average R0
R0-avg
2
1
11

SLIDER
14
191
186
224
%mask-compliance
%mask-compliance
0
100
0.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

An illustrative simulation of spread of COVID-19 in the University of Delaware campus in Newark, Delaware area. The simulation uses agent based approach where each agent on the UD map is a coarse grained representation of the student members of UD community.

The model takes into account typical schedule students might have on a given day, which includes attending classes, participating in various recreational and student activities (weekends are modeled to be the same as weekdays in this implementation with additional off campus activities/parties).

## HOW IT WORKS

The agents have an assigned home spot in the residential/dormitories when they are generated, to which they return after each work day. An infected agent is able to infect others in the near vicinity. The agents perform a random walk when inside a bulding area.

An infected student can infect other students in their proximity, however, the probability of infection reduces by 80% if the infected student is wearing a mask.

The reproductive number R_0 is calculated based on the formula:

R0 = S * L * beta

Here, S is the number of susceptible individuals encountered by an infected individual, beta is the trasmissibility, L is the length of infection. 

The length of infection is assumed to be 7 days, with the transmissibility value depending on whether the infected are wearing masks. The probability of infection is modeled using the following formula

1 - (1 - 0.2 * beta) ^ N1 * (1 - beta) ^ (N2)

N1, N2 are the number of mask wearers and non wearers, respectively.

Using the stay at home and quarantine policy options changes the weekday schedule as well as mobility of the agents. The infected agents stay put in case of quarantine.

## HOW TO USE IT

Clicking setup generates an on-campus population of students. The current implementation includes two policies:

1. Stay-at-home: Students don't go to classes and recreational facilities and stay in their respective dormitories.

2. Quarantine: The infected students are asked to isolate themselves in their dorm areas and remain stationary.

3. Mask compliance: The mask wearing resets at 00:00 hrs and only the selected percentage of students, chosen randomly, wear masks.


## THINGS TO NOTICE

The effect of having quarantine and stay at home and their effect on the evolution of virus spread.
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

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

circle-2
true
0
Circle -16777216 true false 2 2 297
Circle -7500403 true true 45 45 210

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
NetLogo 6.1.1
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
