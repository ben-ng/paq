var mylib = require('./mylib')
  , waldo = require('waldo')
  , flamingo = require('flamingo')
  , flamingoEntry = require('flamingo/package').main
  , bottom = require('./deep/deeper/deepest/bottom')

module.exports = [mylib, waldo, flamingo, bottom, flamingoEntry].join(' ')
