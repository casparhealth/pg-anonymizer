// extensions.js
const { faker } = require('@faker-js/faker');
const bcrypt = require('bcrypt');

function randomString(length) {
  const chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!@#_-+*^%`~/>,?<';
  let result = '';
  for (let i = length; i > 0; --i) result += chars[Math.floor(Math.random() * chars.length)];
  return result;
}

function getPassword(userType, record) {
  console.log(`setting ${userType} credentials`)
  console.log('Account id:', record['id'], 'caspar_id:', record['caspar_id'], 'email:', record['email'])
  return process.env[`${userType}_password`]
}

module.exports = {
  randomCountryID: () => {
    return faker.datatype.number({ min: 1, max: 231 });
  },
  randomBuildingNumber: () => {
    return faker.address.buildingNumber();
  },
  replaceWithEmptyString: () => {
    return "";
  },
  replaceWithString: () => {
    return "Confidential";
  },
  replaceWithNull: () => {
    return null;
  },
  randomHeight: () => {
    return faker.datatype.number({ min: 150, max: 200 });
  },
  randomWeight: () => {
    return faker.datatype.number({ min: 45, max: 180, precision: 0.1 });
  },
  randomBirthDate: () => {
    const birthDate = new Date(faker.date.between('1910-01-01T00:00:00.000Z', '2003-31-12T00:00:00.000Z'));
    return birthDate.toISOString().split("T")[0];
  },
  randomGender: () => {
    return faker.name.gender(true);
  },
  randomPhoneNumber: () => {
    return faker.phone.phoneNumber('+48 111 ### ####');
  },
  randomPassword: (_, __, record) => {
    // record is a hash of { key => value } for this record
    let newPassword = randomString(10)
    let showHash = false

    if (!record) {
      return null;
    }

    if (record['user_type'] === 'Admin' && record['email'] === process.env['admin_email']) {
      newPassword = getPassword('admin', record)
      showHash= true
    }

    if (record['user_type'] === 'Clinic' && record['caspar_id'] === process.env['clinic_id']) {
      newPassword = getPassword('clinic', record)
      showHash= true
    }

    let salt = bcrypt.genSaltSync(13, 'a'); // move this to line #13 to gain performance improvement
    const hash = bcrypt.hashSync(newPassword, salt);
    if (showHash) {
      console.log('HASH:', hash)
    }

    return hash
  }
};
