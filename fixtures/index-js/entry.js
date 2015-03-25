var mylib = require('./mylib')
  , waldo = require('waldo')
  , flamingo = require('flamingo')

module.exports = [mylib, waldo, flamingo].join(' ')
