## oooooo

digital tape loops x 6.

![Image](https://user-images.githubusercontent.com/6550035/91628872-c47b8c80-e978-11ea-9d07-df79ef337a0f.gif)

https://vimeo.com/590419704

i call this script *"oooooo"* because it is composed of six loops. they are like digital tape loops - you can level, pan, speed, slow, shorten, lengthen, dub, overdub, destroy any loop at any time.

i was inspired to make this after seeing tape loops circulating (pun sorta intended) all over the place. i like the idea of having multiple independent different loops, with different sizes, played on a different tape players with different eccentricities. i don't have any cassette tapes but i have norns so i wrote this script to try to make digital tape loops. 

future directions:

- grid support (need help)
- arc support (need help)
- crow support (need help)
- fix all the 🐛🐛🐛

### Requirements

- audio input
- norns

### Documentation

- E1 selects loops
- E2 changes mode/parameter

in tape mode:

- K2 stops
- K2 again resets
- K3 plays
- K1+K2 clears
- K1+K2 again resets
- K1+K3 primes recording
- K1+K3 again records

in other modes:

- K2 or K3 activates or lfos
- E3 adjusts parameter

all parameters are available via the global menu.



**playback/recording:**

- in tape mode, press K2 to stop/goto 0, and press K3 to start playing (once recorded).
- in tape mode, press K1+K3 to prime recording. when primed, recording will automatically begin when incoming audio rises above a threshold. the recording threshold can be set by global parameter "`recording -> rec thresh`". 
- in tape mode, you can force recording by hitting K1+K3 a second time.
- recording stops after traversing the whole loop. you can stop it earlier with K2 or K3 (in tape mode) and that will shrink the loop to that point. you can set recording to continue to the next loop by setting the global parameter "`recording -> rec thru loops`" to `yes`.
- by default, loops will be recorded with a crossfade for gapless playback. if you are recording something with initial transients (like drums), I recommend reducing the crossfade (`loop X -> crossfade`) to 1 ms.
- to record a loop over and over, infinitely, change `recording -> stop rec after` to its max value.

**quick menu:**

- E2 changes mode/parameter on the quick menu
- each parameter can be activated by K2 or K3 (activated lfo), and it can modified by E3
- you can adjust the rate in continuous or discrete (±25%, ±50%, etc.) by changing the global parameter "`continuous rate`"
- the "`warble`" mode allows you to temporarily pitch up/down the current loop using E3

**A loop:**

- the "A" loop is found by turning E1 all the way to the right.
- "A" loop can control all loops. the tape mode works as before, but affects all loops.
- the quick menu differs from loops but is also activated by K2 or K3, and modulated with E3

**settings:**

- the global menu has lots of settings. 
- in `startup` menu you can load loops on startup, play loops on startup, start loops with random lfos and change the length of the starting loops (in beats). _note:_ these settings persist next time you open `oooooo`!
- in `recording` menu you can change pre/rec levels, recording threshold for primed recordings, the volume pinchoff, whether to record through loops, and how many times to loop over before stopping recording. note:_ these settings persist next time you open `oooooo`!
- in `all loops` you can pause all lfos, set loop destruction (which slowly degrades loops), ramp volume up/down, randomize loops on reset, change the reset per loop
- in `loop X` menu you can modify all lfos, and several other parameters of each loop.

**oooooo ideas:**

- *audibly ambient:* record to each loop and then move them around the screen. [video example](https://www.instagram.com/p/CEzI3mqB_0k/)
- *lucid looper:* instead of overdubbing one loop, record six separate loops of the same size that have their own stereo field. change `startup -> start length` to `16` beats and `startup -> start lfos random` to `yes`. then change `recording -> rec thru loops` to `yes` and make sure `recording -> stop rec after` is `1`. then reload *oooooo*, and record. [video example](https://www.instagram.com/p/CFBjBxGhJXs/)
- *dangerous delay:* tape delay with six tapes, that shapeshift. in `recording` menu set `pre level` and `rec level` to 0.5. set `stop rec after` to max. go to `A` loop. turn E2 to `rand lfo` and activate with K2. turn E2 to tape and press K1+K3 to record on all loops forever, making a stereo-field delay. (make it crazier by changing `all loops -> randomize on reset` to `yes` and `all loops -> reset all every` to `X beats`). [video example](https://www.instagram.com/p/CFFHUNmhxIf/)

## demo 

<p align="center"><a href="https://www.instagram.com/p/CEb2CDQBXaz/"><img src="https://user-images.githubusercontent.com/6550035/91628605-30102a80-e976-11ea-9d0e-249e6219c411.png" alt="Demo of playing" width=80%></a></p>


<p align="center"><a href="https://www.instagram.com/p/CEeMRPDhCt_/"><img src="https://user-images.githubusercontent.com/6550035/91628603-2be40d00-e976-11ea-93ee-6f58fc835142.png" alt="Demo of playing" width=80%></a></p>


## license 

mit 



