Julia-Playground
================

A collection of various playthings and utilities for graphical explorations in Julia and beyond.

Currently contains:
  - A [Treap](http://en.wikipedia.org/wiki/Treap)
  - An image encoder for the [PPM](http://netpbm.sourceforge.net/doc/ppm.html) image format
  - A set of OpenGL tools for operations like creating shaders and checking for errors
  - A simple OpenGL example with minimal dependencies
  - An implementation of the ideas in [Timothy Chan](https://cs.uwaterloo.ca/~tmchan/)'s [paper](https://cs.uwaterloo.ca/~tmchan/sss.ps) for approximate nearest-neighbor search in fixed low dimensions
  - A basic Rgb color type with common operations defined, parameterizable by type and useful for creating e.g. densely packed arrays of byte-sized color data and passing it to OpenGL.
  - A very simple data structure that I call a bag, which is an unordered collection that supports efficient additions and deletions at an arbitrary index
All code is released under the MIT license.
