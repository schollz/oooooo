## oooooo

6 x digital tape loop.


i've been seeing tape loops circulating (pun sorta intended) all over the place. i like the idea of having multiple independent different loops, with different sizes, played on a different tape players with different eccentricities. i don't have any cassette tapes but i have norns so i wrote this script to try to make digital tape loops. i call it *"oooooo"*.

*oooooo* is inspired by musicians like [amulets](https://www.youtube.com/watch?v=hER3s1NPr_U), [hainbach](https://www.youtube.com/watch?v=cVy9ABT5-iY), [andrew black](https://www.instagram.com/andy_____black) and inspired by norns scripts like [reels](https://llllllll.co/t/reels), [cranes](https://llllllll.co/t/cranes), and my previous script [barcode](https://llllllll.co/t/barcode). 


future directions:

- allow parameter to reset loops to different tempos
- lean into the "tape loop" idea and add some lfos for tape *warbling*

### Requirements

- audio input
- norns

### Documentation

- K1 shifts
- K2 stops
- K2 again resets loop
- K3 plays
- shift+K2 clears
- shift+K3 records
- E1 changes loops
- E2 selects parameters
- E3 adjusts parameters

**recording:**

- the first time you hit shift+K3 to record it will "prime". when "primed" recording will start automatically with incoming audio. you can force recording by hitting shift+K3 a second time.
- recording stops when it iterates over the whole loop (but can be stopped earlier)


**special functions:**

if you change the loop to "A" using E2 there are several special functions available.

- K2/K3 stops/plays on *all* loops
- pressing shift+K2 clears *all* loops
- if you select the parameter "save" and press K3 it will save the current state. this will overwrite the previous save, so make sure to backup the audio files yourself.
- if you select the parameter "load" and press K2 it will load the previous state.
- if you select the parameter "tempo" you can modify a tempo that will be used to calculate loop lengths when clearing all loops.



## demo 

<p align="center"><a href="https://www.instagram.com/p/X/"><img src="X" alt="Demo of playing" width=80%></a></p>

## my other norns

- [barcode](https://github.com/schollz/barcode): replays a buffer six times, at different levels & pans & rates & positions, modulated by lfos on every parameter.
- [blndr](https://github.com/schollz/blndr): a quantized delay with time morphing
- [clcks](https://github.com/schollz/clcks): a tempo-locked repeater for monome norns

## license 

mit 