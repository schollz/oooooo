## oooooo

digital tape loops x 6.

![Image](https://user-images.githubusercontent.com/6550035/91628872-c47b8c80-e978-11ea-9d07-df79ef337a0f.gif)

i call this script *"oooooo"* because it is composed of six loops. they are like digital tape loops - you can level, pan, speed, slow, shorten, lengthen, dub, overdub any loop at any time.

i was inspired to make this after seeing tape loops circulating (pun sorta intended) all over the place. i like the idea of having multiple independent different loops, with different sizes, played on a different tape players with different eccentricities. i don't have any cassette tapes but i have norns so i wrote this script to try to make digital tape loops. 

future directions:

- midi cc support for modulating loops
- grid support (need help)
- arc support (need help)
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
- shift+K2 clears loop
- shift+K3 primes recording
- shift+K3 again forces recording
- E1 changes loops
- E2 selects parameters
- E3 adjusts parameters

**recording:**

- the first time you hit shift+K3 to record it will "prime". once "primed", recording will automatically begin when incoming audio rises above a threshold. the recording threshold can be set by global parameter "`rec thresh`". when "primed", you can force recording by hitting shift+K3 a second time.
- recording stops after traversing the whole loop. you can stop it earlier with K2 or K3 and that will shrink the loop to that point. you can set recording to continue to the next loop by setting the global parameter "`rec thru loops`" to `yes`.
- by default, volume in "pinched" when starting/stopping recording to avoid pops from discontinuous signals. you can lower/raise the pinching by adjusting the global parameter "`vol pinch`".

**playback:**

- you can adjust the rate in continuous or discrete (±25%, ±50%, etc.) by changing the global parameter "`continuous rate`" to `yes`.

**special functions in A loop:**

if you change the loop to "A" using E1 there are several special functions available to affect all loops.

- K2/K3 stops/plays on *all* loops,
- pressing shift+K2 clears and resets *all* loops,
- if you select the parameter "save"/"load" then shift+K3 will save/load the current state. this will overwrite the previous save, so make sure to backup the audio files yourself. you can change which save/load with E3.
- if you select `rand` and press shift+K3 it will randomize the loops


## demo 

<p align="center"><a href="https://www.instagram.com/p/CEb2CDQBXaz/"><img src="https://user-images.githubusercontent.com/6550035/91628605-30102a80-e976-11ea-9d0e-249e6219c411.png" alt="Demo of playing" width=80%></a></p>


<p align="center"><a href="https://www.instagram.com/p/CEeMRPDhCt_/"><img src="https://user-images.githubusercontent.com/6550035/91628603-2be40d00-e976-11ea-93ee-6f58fc835142.png" alt="Demo of playing" width=80%></a></p>

## my other norns

- [barcode](https://github.com/schollz/barcode): replays a buffer six times, at different levels & pans & rates & positions, modulated by lfos on every parameter.
- [blndr](https://github.com/schollz/blndr): a quantized delay with time morphing
- [clcks](https://github.com/schollz/clcks): a tempo-locked repeater for monome norns

## license 

mit 



### new in v0.4

- bug fix: play button can stop recording as well as stop button
- bug fix: sleep now uses clock instead of while-loop (less CPU)
- bug fix: recording should be more reponsive (shorter poll time)
- new feature: the initial loop sizes are quantized based on the global clock tempo
- new feature: multiple save/loading tapes
- new feature: randomizer mode on loop "A" (activate with shift+K3)
- new feature: if loop stopped during recording, the loop shrinks to that size
- new option: quantize rates (global parameter `continuous rates`)
- new option: record through all loops (global parameter `keep rec`)
- new option: set volume pinch at begining+end of loop when recording (global parameter `vol pinch`)

