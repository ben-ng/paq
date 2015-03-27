var t = require('./hbsfy')

t('file.hbs', '{{name}}', function (err, data) {
  console.log(data)
})
