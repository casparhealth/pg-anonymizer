// extensions.js
const { faker } = require('@faker-js/faker');

module.exports = {
  randomCountryID: () => {
    return Math.floor(Math.random() * (231 - 1 + 1) + 1);
   // return faker.datatype.number({ min: 1, max: 231 });
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
  //  return Math.floor(Math.random() * (200 - 150 + 1) + 150);
    return faker.datatype.number({ min: 150, max: 200 });
  },
  randomWeight: () => {
  //  return Math.random() * (180 - 45 + 1) + 45;
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
  }
//  randomBirthdate: () => {
//    const start = new Date(1910, 0, 1);
//    const end = new Date(2018, 11, 31);
//    const date = new Date(start.getTime() + Math.random() * (end.getTime() - start.getTime()));
//    return date.toISOString().replace(/T/, " ").replace(/\..+/, "");
//  }
};
