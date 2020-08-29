## oooooo

digital tape loops x 6.

![Image](https://user-images.githubusercontent.com/6550035/91628872-c47b8c80-e978-11ea-9d07-df79ef337a0f.gif)

i call this script *"oooooo"* because it is composed of six loops. they are like digital tape loops - you can level, pan, speed, slow, shorten, lengthen, dub, overdub any loop at any time.

i was inspired to make this after seeing tape loops circulating (pun sorta intended) all over the place. i like the idea of having multiple independent different loops, with different sizes, played on a different tape players with different eccentricities. i don't have any cassette tapes but i have norns so i wrote this script to try to make digital tape loops. 

future directions:

- add lfos for tape *warbling*
- fix all the 🐛🐛🐛

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

- the first time you hit shift+K3 to record it will "prime". when "primed", recording will automatically begin when incoming audio asserts itself. you can always force recording by hitting shift+K3 a second time.
- recording stops when it iterates over the whole loop (but can be stopped earlier use K2 or K3)


**special functions:**

if you change the loop to "A" using E2 there are several special functions available to affect all loops.

- K2/K3 stops/plays on *all* loops,
- pressing shift+K2 clears and resets *all* loops,
- if you select the parameter "save" and press K3 it will save the current state. this will overwrite the previous save, so make sure to backup the audio files yourself.
- if you select the parameter "load" and press K2 it will load the previous state.,
- if you select the parameter "tempo" you can modify a tempo that will be used to calculate loop lengths when clearing all loops.


## demo 

<p align="center"><a href="https://www.instagram.com/p/CEb2CDQBXaz/"><img src="https://user-images.githubusercontent.com/6550035/91628605-30102a80-e976-11ea-9d0e-249e6219c411.png" alt="Demo of playing" width=80%></a></p>


<p align="center"><a href="https://www.instagram.com/p/X/"><img src="https://user-images.githubusercontent.com/6550035/91628603-2be40d00-e976-11ea-93ee-6f58fc835142.png" alt="Demo of playing" width=80%></a></p>

## my other norns

- [barcode](https://github.com/schollz/barcode): replays a buffer six times, at different levels & pans & rates & positions, modulated by lfos on every parameter.
- [blndr](https://github.com/schollz/blndr): a quantized delay with time morphing
- [clcks](https://github.com/schollz/clcks): a tempo-locked repeater for monome norns

## license 

mit 