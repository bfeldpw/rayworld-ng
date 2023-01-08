# rayworld-ng
Simple Raycaster to learn Zig

My first steps in Zig, importing native C with Glfw and OpenGL for learning purposes. Code is quite hacky as I try to explore Zig step by step, improving code by topics (such as error handling etc.). OpenGL fixed function pipeline is used purely out of lazyness and the fact, that a simple vertical line (maybe textured, maybe even hardware-textured) is all that is needed for a raycasting algorithm. Might switch to core profile later, and then transfer the algorithm to shaders, but that's secondary.

A very early first version can be seen in Figure 1:

![Very early map and player represenation](screenshots/map.jpg?raw=true)

*Figure 1: Very early scene and map representation.*

## Installation and dependencies

Zig seems to be very handy when it comes to cross compiling. I only tried within Linux, GLFW3 and thus, OpenGL have to be installed.

## Performance measurements

There is a tiny measurement tool build in.
Raycasting is done on CPU, which is an old 4790K underclocked (yes, underclocked :-) ) @3.8GHz.
The algorithm is single-threaded for now. My stats are as follows:
### debug
Raycasting: ~2.8ms (@ ~3000 measurements, i.e. frames)

Rendering: ~0.96ms (@ ~3000 measurements, i.e. frames)

### release-safe
Raycasting: ~1.22ms (@ ~2860 measurements, i.e. frames)

Rendering:  ~0.41ms (@ ~2860 measurements, i.e. frames) 

### release-fast
Raycasting: ~0.97ms (@ ~4700 measurements, i.e. frames)

Rendering:  ~0.43ms (@ ~4700 measurements, i.e. frames)


