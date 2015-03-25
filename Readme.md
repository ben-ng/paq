# paq

[![Build Status](https://travis-ci.org/ben-ng/paq.svg?branch=master)](https://travis-ci.org/ben-ng/paq)

Paq implements a subset of [Browserify](http://browserify.org)'s features with full multithreading support. For impatient people who have to deal with large codebases.

I post updates on Twitter:
[![Follow @_benng](https://twitter.com/_benng)](http://i.imgur.com/ytWUNob.jpg)

# Caveats

 * Mac only for now. If you get it running elsewhere, send a PR.
 * Implements only the subset of Browserify that I need at work.

# Contributing

To work on paq, you'll need these tools:

- Xcode 6.2
- OS X 10.10.2
- xctool (Get [Homebrew](http://brew.sh) then `brew install xctool`)
- node
- npm

To run the tests (which require the things mentioned above) you can either run `npm test` from the command line, or run the `paq-test` target in Xcode.
