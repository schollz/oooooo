# oooooo

digital tape loops x 6.

![Image](https://user-images.githubusercontent.com/6550035/91628872-c47b8c80-e978-11ea-9d07-df79ef337a0f.gif)

https://vimeo.com/590419704

i call this script *"oooooo"* because it is composed of six loops. they are like digital tape loops - each loop can be can leveled, paned, slowed, sped up, shortened, lengthened, overdubed, destroyed, warbled.

## Requirements

- audio input
- norns
- grid (optional)
- crow (optional)

## Documentation

- E1 selects loops
- E2 selects parameter
- E3 modulates selected parameter

in tape mode - the first parameter (E2 full CCW, looks like sunglasses) - you can do the recording/playing/stopping:

- K1+K3 primes recording
- K1+K3 again records
- K2 stops
- K2 again resets
- K3 plays
- K1+K2 clears
- K1+K2 again resets

when a recording is "primed" it waits until a minimal threshold to start recording. you can change this threshold in `PARAMS > recording > rec thresh` if it's too sensitive or not sensitive enough. additionally each loop has a parameter to control the crossfading `PARAMS > loop X > crossfade` which you can change to control how many transients are present at the beginning of the loop.

if you change E1 all the way to the right you will encounter the "A" loop which has some quick menus that affect all the loops. select them with E2 and activate them with K3.

### parameters menu

there are many parameters available to tweak *oooooo* to your liking.

in `startup` menu you can load loops on startup, play loops on startup, start loops with random lfos and change the length of the starting loops (in beats). _note:_ these settings persist next time you open `oooooo`!

in `recording` menu you can change pre/rec levels, recording threshold for primed recordings, the volume pinchoff, whether to record through loops, and how many times to loop over before stopping recording. note:_ these settings persist next time you open `oooooo`!

in `save/load` you can save/load the entire current state - including all recordings and parameters.

in `all loops` you can pause all lfos, set loop destruction (which slowly degrades loops), ramp volume up/down, randomize loops on reset, change the reset per loop

in `loop X` menus you can modify all lfos, and several other parameters of each loop, including mapping to triggers. all these parameters are mappable.

### grid

the grid lets you manipulate loops quickly with a key press and presents an alternative tactile way to interact with looping. (*thank you @tyleretters for [this absolutely amazingly useful grid doc tool](https://tyleretters.github.io/GridStation/)!*)

![oooooo_grid-03|690x407](https://user-images.githubusercontent.com/6550035/132006771-4fdd4e9e-3a02-48e9-b94a-7f6454d60399.png) 

![oooooo_grid-01|690x407](https://user-images.githubusercontent.com/6550035/132006768-4a9554b8-dbe8-432c-a76d-a84b8e1c8ba1.png) 

![oooooo_grid-02|690x407](https://user-images.githubusercontent.com/6550035/132006765-3fc245e9-f234-4b7a-a926-05ca6398a849.png) 

https://vimeo.com/512237665

### chord layering

"chord layering" is a little method I like to use with *oooooo* and now its hard-coded into the `PARAMS` menu. basically, it is a sequencer that sends out one note at a time from four chords to use the loops to record the entire chord phrase. it's described in more detail [here](https://llllllll.co/t/latest-tracks-videos/25738/3016) and is the basis of [an entire album I recorded](https://infinitedigits.bandcamp.com/album/at-the-place).

https://vimeo.com/659711193

to get started, first plug in a midi synth or crow into norns (before starting *oooooo*). if you are using crow, out1 is pitch and out2 is gate. direct the sound from the synth into the input of *oooooo* and then do `PARAMS > activate` under `chord layering`.

this sequencer will find the minimal inversions from the first chord and then rearrange the columns of each row so that there are minimal changes between chords. then it will go up/down in octaves each line to make sure the chord is padded out (and sometimes gives melodic things). this is a random process (there isn’t one best answer for each chord progression) so each time you run the script it is a little different. after the chords are layered, it plays random notes at random intervals and sounds melodic. its fun to add lots of texture in each layer (modulating filters, volume, etc).

the `solo probability` will trigger note gates randomly *after loops are recorded* using random notes from the chords. the number of loops to be recorded is set at `PARAMS > loops to record`. 

if you have a TE pocket operator + crow, the sequencer can trigger the start on the pocket operator at a specific loop using `PARAMS > po clock start` (run crow out3 to the pocket operator in `SY4` mode).

### ideas

there are a great many adjustments you can make to the loops to do things you'd like. I made some of these adjustments into "presets" which can be selected with `PARAMS > choose mode` and activated with `PARAMS > activate mode`. and here are some other ideas:

- *audibly ambient:* record to each loop and then move them around the screen. [video example](https://www.instagram.com/p/CEzI3mqB_0k/)
- *lucid looper:* instead of overdubbing one loop, record six separate loops of the same size that have their own stereo field. change `startup -> start length` to `16` beats and `startup -> start lfos random` to `yes`. then change `recording -> rec thru loops` to `yes` and make sure `recording -> stop rec after` is `1`. then reload *oooooo*, and record. [video example](https://www.instagram.com/p/CFBjBxGhJXs/)
- *dangerous delay:* tape delay with six tapes, that shapeshift. in `recording` menu set `pre level` and `rec level` to 0.5. set `stop rec after` to max. go to `A` loop. turn E2 to `rand lfo` and activate with K2. turn E2 to tape and press K1+K3 to record on all loops forever, making a stereo-field delay. (make it crazier by changing `all loops -> randomize on reset` to `yes` and `all loops -> reset all every` to `X beats`). [video example](https://www.instagram.com/p/CFFHUNmhxIf/)


## license 

mit 



