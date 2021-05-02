# ProjectDarien-WebModel
## WHAT IS IT?

An illustrative simulation of spread of COVID-19 in the University of Delaware campus in Newark, Delaware area. The simulation uses agent based approach where each agent on the UD map is a coarse grained representation of the student members of UD community.

The model takes into account typical schedule students might have on a given day, which includes attending classes, participating in various recreational and student activities (weekends are modeled to be the same as weekdays in this implementation with additional off campus activities/parties).

## HOW IT WORKS

The agents have an assigned home spot in the residential/dormitories when they are generated, to which they return after each work day. An infected agent is able to infect others in the near vicinity. The agents perform a random walk when inside a bulding area.

An infected student can infect other students in their proximity, however, the probability of infection reduces by 80% if the infected student is wearing a mask.

The reproductive number <img src="https://render.githubusercontent.com/render/math?math="R_0"> is calculated based on the formula:

<img src="https://render.githubusercontent.com/render/math?math="R_0 = S\cdot L\cdot \beta">

Here, S is the number of susceptible individuals encountered by an infected individual, beta is the trasmissibility, L is the length of infection. 

The length of infection is assumed to be 7 days, with the transmissibility value depending on whether the infected are wearing masks. The probability of infection is modeled using the following formula

<img src="https://render.githubusercontent.com/render/math?math="1 - (1 - 0.2 \beta) ^ {N_1} * (1 - \beta) ^ {N_2}"> N1, N2 are the number of mask wearers and non wearers, respectively.

Using the stay at home and quarantine policy options changes the weekday schedule as well as mobility of the agents. The infected agents stay put in case of quarantine.

## HOW TO USE IT

Clicking setup generates an on-campus population of students. The current implementation includes two policies:

1. Stay-at-home: Students don't go to classes and recreational facilities and stay in their respective dormitories.

2. Quarantine: The infected students are asked to isolate themselves in their dorm areas and remain stationary.

3. Mask compliance: The mask wearing resets at 00:00 hrs and only the selected percentage of students, chosen randomly, wear masks.


## THINGS TO NOTICE

The effect of having quarantine and stay at home and their effect on the evolution of virus spread.
