# paq

[![Build Status](https://travis-ci.org/ben-ng/paq.svg?branch=master)](https://travis-ci.org/ben-ng/paq) [![Coverage Status](https://coveralls.io/repos/ben-ng/paq/badge.svg)](https://coveralls.io/r/ben-ng/paq)

paq implements a subset of [Browserify](http://browserify.org)'s features with full multithreading support. For impatient people who have to deal with large codebases.

Get updates by following me on Twitter:
[![Follow @_benng](http://i.imgur.com/FImwJ9n.png)](https://twitter.com/_benng)

## What's Working

 * `require('./relative/path')`
 * `require('some-module')`
 * `require('node-core-module')`
 * `require(path.join(__dirname, 'some_module'))` (or any other statically resolvable expression, like `__dirname + '/path'`)
 * Exporting a standalone bundle
 * Converting transforms like `hbsfy` for use with `paq`

## What's Not Working
 * `paq` can't actually run transforms yet. Almost there!
 * Replacement of `process.env` with actual environment vars.

## Usage

```
USAGE: paq <entry files> [options]

Options:
  --parserTasks=<integer>          The maximum number of concurrent AST parsers
  --requireTasks=<integer>         The maximum number of concurrent require
                                   evaluations
  --standalone                     Returns a module that exports the entry
                                   file's export
  --convertBrowserifyTransform     Returns a module that wraps a browserify
                                   transform for use with paq
  --ignoreUnresolvableExpressions  Ignores expressions in require statements
                                   that cannot be statically evaluated
```

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
