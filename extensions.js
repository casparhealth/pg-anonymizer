// extensions.js
const { faker } = require('@faker-js/faker');
const bcrypt = require('bcrypt');

function randomString(length) {
  const chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!@#_-+*^%`~/>,?<';
  let result = '';
  for (let i = length; i > 0; --i) result += chars[Math.floor(Math.random() * chars.length)];
  return result;
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
  randomEmail: (record) => {
  	if (record === process.env['admin_email']) {
      console.log(record)
      return record
    }
    return faker.internet.email()
  },
  randomPassword: () => {
    return randomString(10);
  },
  randomPasswordHash: () => {
    const newPassword = randomString(10)
    const salt = bcrypt.genSaltSync(13, 'a');
    return bcrypt.hashSync(newPassword, salt);
  }
};
