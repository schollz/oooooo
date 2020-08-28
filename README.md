## oooooo

6 x digital tape loop.


i've been seeing tape loops circulating (pun sorta intended) all over the place. i like the idea of having multiple independent different loops, with different sizes, played on a different tape players with different eccentricities. i don't have any tapes but i have norns so i wrote this script to try to make digital tape loops. i call it *"oooooo"*.

*oooooo* is inspired by musicians like [amulets](https://www.youtube.com/watch?v=hER3s1NPr_U), [hainbach](https://www.youtube.com/watch?v=cVy9ABT5-iY), [andrew black](https://www.instagram.com/andy_____black) and inspired by norns scripts like [reels](https://llllllll.co/t/reels), [cranes](https://llllllll.co/t/cranes), and my previous script [barcode](https://llllllll.co/t/barcode).

future directions:

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

*oooooo* eccentricities:

- allow *arming* record which to start recording on audio input
- recording defaults to one loop (can be stopped earlier)
- you can adjust loop *length* instead of loop *endpoint*

the ui is also minimal but attempts to show the main information at a glance - the tape loop size, speed, pan, volume are all encoded in the ui.

## demo 

<p align="center"><a href="https://www.instagram.com/p/X/"><img src="X" alt="Demo of playing" width=80%></a></p>

## my other norns

- [barcode](https://github.com/schollz/barcode): replays a buffer six times, at different levels & pans & rates & positions, modulated by lfos on every parameter.
- [blndr](https://github.com/schollz/blndr): a quantized delay with time morphing
- [clcks](https://github.com/schollz/clcks): a tempo-locked repeater for monome norns

## license 

mit 