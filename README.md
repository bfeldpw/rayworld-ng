# rayworld-ng
Simple Raycaster to learn Zig

My first steps in Zig, importing native C with Glfw and OpenGL for learning purposes. Code is quite hacky as I try to explore Zig step by step, improving code by topics (such as error handling etc.). OpenGL fixed function pipeline is used purely out of lazyness and the fact, that a simple vertical line (maybe textured, maybe even hardware-textured) is all that is needed for a raycasting algorithm. Might switch to core profile later, and then transfer the algorithm to shaders, but that's secondary.
A very early map representation can be seen in Figure 1:

![Very early map and player represenation](screenshots/map.jpg?raw=true)

*Figure 1: Very ealry map and player representation showing walls in white, floor in grey and player in green. The player can move using mouse and keyboard, collision with walls is tested.*
