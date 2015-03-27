/**
* Pulls out browserify's builtins data and prepares it for the linker
*
* TODO: Make this smarter so that we aren't wasteful about what code is
* bundled with the final result
*/
var builtins = require('browserify/lib/builtins')
  , browserify = require('browserify')
  , async = require('async')

async.map(Object.keys(builtins)
, function (key, next) {

  var b = new browserify(builtins[key], {standalone: key})
    , mutatedKey

  if(key.charAt(0) == '_') {
    mutatedKey = key.substring(1).split('_').join('/')
  }

  b.bundle(function (err, buff) {
    next(err, err ? null : [key, buff.toString()])
  })

}, function (err, bundles) {
  if(err) {
    throw err
  }

  var dict = {}

  for (var i=0, ii=bundles.length; i<ii; ++i) {
    dict[bundles[i][0]] = bundles[i][1]
  }

  process.stdout.write(JSON.stringify(dict))
})
