var mylib = require('./mylib')
  , waldo = require('waldo')
  , flamingo = require('flamingo')
  , bottom = require('./deep/deeper/deepest/bottom')

module.exports = [mylib, waldo, flamingo, bottom].join(' ')
