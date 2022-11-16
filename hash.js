const bcrypt = require('bcrypt')

let newPassword = 'RaNdomStr1ng';
let salt = bcrypt.genSaltSync(13, 'a');
console.log(bcrypt.hashSync(newPassword, salt));
