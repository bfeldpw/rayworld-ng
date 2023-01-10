# rayworld-ng
Simple Raycaster to learn Zig

My first steps in Zig, importing native C with Glfw and OpenGL for learning purposes. Code might be hacky in some places, hopefully improving while learning. OpenGL fixed function pipeline is used purely out of lazyness and the fact, that a simple vertical line (maybe textured) is all that is needed for a raycasting algorithm in its most simplistic form. Might switch to core profile later, but that's secondary. Same applies for parameters and resources, for now, the map is hardcoded as are parameters (nevertheless there are parameters and not some magic numbers ;-)). Later, a map, its features, and configuration should be loaded from files, of course.

## News
2023-01-10: A first version of mirrors has been implemented. The underlying system based on ray segments allows for different scenarios, "spawning" ray segments is only limited to a maximum amount to avoid infinite reflections and high processing loads. Wall and mirror features are fixed in this early version. In the future, map features, such as mirrors and walls will have several attributes.

2023-01-09: Implemented a simple interpolation between two vertical lines so only half of the rays need to be calculated. Additionally, multithreading was added for they ray calculations. At the moment, it's statically set to 4 threads, to avoid too much overhead of spawning without a threadpool. The overhead might become noticable, since the ray casting itself is pretty fast (non-complex as of yet). Using both methods, there is a ~75% reduction of computing time on my system.

## Screenshots
A scene with mirror elements can be seen in Figure 1, the overview map is on the bottom left:

![scene](screenshots/mirrors.jpg?raw=true)

*Figure 1: Scene and map representation*

Figure 2 shows an enlarged version of a similar scene as seen in Figure 1 to demonstrate the ray propagation:

![map](screenshots/map.jpg?raw=true)

*Figure 2: Enlarged map view of the ray propagation*

## Installation and dependencies

Zig seems to be very handy when it comes to cross compiling. I only tried within Linux, GLFW3 and thus, OpenGL have to be installed.

<!-- ## Performance measurements -->

<!-- There is a tiny measurement tool build in. -->
<!-- Raycasting is done on CPU, which is an old 4790K underclocked (yes, underclocked :-) ) @3.8GHz. -->
<!-- The algorithm is single-threaded for now. My stats are as follows: -->
<!-- ### debug -->
<!-- Raycasting: ~2.8ms (@ ~3000 measurements, i.e. frames)\ -->
<!-- Rendering: ~0.96ms (@ ~3000 measurements, i.e. frames) -->

<!-- ### release-safe -->
<!-- Raycasting: ~1.22ms (@ ~2860 measurements, i.e. frames)\ -->
<!-- Rendering:  ~0.41ms (@ ~2860 measurements, i.e. frames)  -->

<!-- ### release-fast -->
<!-- Raycasting: ~0.97ms (@ ~4700 measurements, i.e. frames)\ -->
<!-- Rendering:  ~0.43ms (@ ~4700 measurements, i.e. frames) -->


