/**
* Pulls out browserify's builtins data and prepares it for the linker
*
* TODO: Make this smarter so that we aren't wasteful about what code is
* bundled with the final result
*/
var builtins = require('browserify/lib/builtins')
  , path = require('path')
  , moduleRoot = path.dirname(__dirname)
  , keys = Object.keys(builtins)
  , out = {}

for (var i=0, ii=keys.length; i<ii; ++i) {
  var key = keys[i]
    , mutatedKey = key

  if(key.charAt(0) == '_') {
    mutatedKey = key.substring(1).split('_').join('/')
  }

  // Store the relative paths from the root of the module, to the builtin
  out[mutatedKey] = path.relative(moduleRoot, builtins[key])
}

process.stdout.write(JSON.stringify(out))
