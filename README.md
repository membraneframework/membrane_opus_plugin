# Membrane Element: Opus

Opus Codec for Membrane.


# Prerequisities

## Mac OS X

* Install XCode

## Linux

* Install build tools (`sudo apt-get install build-essential` on Debian/Ubuntu).

## Windows

* Install Visual Studio (can be common edition)
* Install Elixir for windows from http://www.elixir-lang.org
* Install git for Windows, clone the app
* Open `cmd` and enter the app directory
* Add Visual Studio tools to PATH: `"c:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\vcvarsall" amd64` (amd64 is valid for 64-bit Windows)


# External libraries

This element needs [libopus](http://opus-codec.com/downloads/) to work.
It was tested with libopus-1.1.3.

## Mac OS X

At the moment, build scripts rely on libopus installed via [brew](http://brew.sh).
Run `brew install opus` before trying to compile that package.

## Linux

Not supported at the moment. (TODO)

## Windows

`ext` subdirectory contains headers and precompiled libopus-1.1.3 for Windows.

However, at the moment build scripts always link 64-bit version (FIXME)


# License

[LGPLv3](https://www.gnu.org/licenses/lgpl-3.0.en.html)

Additionally, while using this element in your application you have to follow
requirements of Opus license which itself is a three-clause BSD license.
See http://opus-codec.com/license/.


# Authors

Marcin Lewandowski
