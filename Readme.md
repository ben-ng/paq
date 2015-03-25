# paq

[![Build Status](https://travis-ci.org/ben-ng/paq.svg?branch=master)](https://travis-ci.org/ben-ng/paq)

paq implements a subset of [Browserify](http://browserify.org)'s features with full multithreading support. For impatient people who have to deal with large codebases.

Get updates by following me on Twitter:
[![Follow @_benng](http://i.imgur.com/FImwJ9n.png)](https://twitter.com/_benng)

## Under The Hood

 * Written in Objective-C++
 * Uses [a native port of](https://github.com/ben-ng/paq/blob/master/paq/resolve.mm) the `require.resolve` algorithm
 * Uses [GCD](https://developer.apple.com/library/prerelease/mac/documentation/Performance/Reference/GCD_libdispatch_Ref/index.html) for concurrency
 * No external dependencies; [escodegen](https://github.com/estools/escodegen) and [acorn](https://github.com/marijnh/acorn) are [embedded in the binary](http://www.objc.io/issue-6/mach-o-executables.html)
 * [Decent tests](https://github.com/ben-ng/paq/blob/master/paq-tests/main.mm)

## Caveats

 * Mac only for now. If you get it running elsewhere, send a PR.
 * Implements only the subset of Browserify that I need at work.
 * Browserify is a production ready, well maintained, and mature project. paq is none of those things, considering I wrote it in about 24 hours.

## Contributing

To work on paq, you'll need these tools:

- Xcode 6.2
- OS X 10.10.2
- xctool (Get [Homebrew](http://brew.sh) then `brew install xctool`)
- node
- npm

To run the tests (which require the things mentioned above) you can either run `npm test` from the command line, or run the `paq-test` target in Xcode.
