var template = require('./template.hbs')

// Should export "Hello World!"
module.exports = template({input: 'World'})
