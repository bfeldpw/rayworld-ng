# rayworld-ng
Simple Raycaster to learn Zig 

![build](https://github.com/bfeldpw/rayworld-ng/actions/workflows/ci.yml/badge.svg?branch=master)
 
![teaser](screenshots/teaser.jpg?raw=true)

*Teaser, further screenshots see below*

## Introduction
My first steps in Zig, importing native C with Glfw and OpenGL for learning purposes. Code might be hacky in some places, hopefully improving while learning. OpenGL fixed function pipeline is used purely out of lazyness and the fact, that a simple vertical line (maybe textured) is all that is needed for a raycasting algorithm in its most simplistic form. Might switch to core profile later, but that's secondary. Same applies for parameters and resources, for now, the map is hardcoded as are parameters (nevertheless there are parameters and not some magic numbers ;-)). Later, a map, its features, and configuration should be loaded from files, of course.

## News
**2023-01-29** A lot of new features found there way into the build this week. Most interesting is glass. First, refraction based on material index has been implemented. Some scenerios looked a little weird, because of the lack of total inner reflection, which was implemented next. Secondly, round pillars can now be placed. While their radius is still a fixed parameter, it will be a variable parameter in the map attributes soon. Lastly, a bit of testing has been done to scatter ray segments reflected by walls to simulate diffuse reflections.

**2023-01-20** Texture mapping has been implemented. Since, as mentioned above, I was using the immediate mode ("fixed function pipeline"), this became quite taxing due to calls to OpenGL. Since I am aware of people using the integrated Intel GPU with its linux drivers, that are somewhat buggy in my experience when it comes to core profile, I tried to stay withing OpenGL <= 2.0. This lead to DrawArrays. A memory structure has been set up to store all information of primitives to be drawn for different depth layers (reflections/mirrors). A first test for "manual" mip mapping has been done as well.

Getting back to the core of ray casting, all wall elements have been made slightly reflective, too. There is a maximum amount of ray bounces much lower than that of mirrors, though.

**2023-01-12:** Floor and ceiling are now represented by a very simple colour grading. This will be improved, when those cells are drawn during tracing, which also allows for ground textures. Additionally, some light vertical ambient occlusion is rendered, which is a very hacky specific function blending vertical colour-graded line segments.

**2023-01-11:** The basic structure to store more map attributes has been implemented. As a first test, RGBA colours are set for every cell.

**2023-01-10:** A first version of mirrors has been implemented. The underlying system based on ray segments allows for different scenarios, "spawning" ray segments is only limited to a maximum amount to avoid infinite reflections and high processing loads. Wall and mirror features are fixed in this early version. In the future, map features, such as mirrors and walls will have several attributes.

**2023-01-09:** Implemented a simple interpolation between two vertical lines so only half of the rays need to be calculated. Additionally, multithreading was added for they ray calculations. At the moment, it's statically set to 4 threads, to avoid too much overhead of spawning without a threadpool. The overhead might become noticable, since the ray casting itself is pretty fast (non-complex as of yet). Using both methods, there is a ~75% reduction of computing time on my system.

## Screenshots

### Glass
coming soon...

### "All walls shiny"
coming soon...

### Texture Mapping
coming soon...

### Early implementation

A scene with mirror elements, different colors and a little ambient occlusion can be seen in Figure 1,
the overview map is on the bottom left:

![scene](screenshots/scene_01.jpg?raw=true)

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


