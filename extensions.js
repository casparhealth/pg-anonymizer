// extensions.js
const { faker } = require('@faker-js/faker');
const bcrypt = require('bcrypt');
const crypto = require('crypto');

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
  // pg_dump COPY text format: \N is SQL NULL. A JS null would be joined as "" instead.
  replaceWithNull: () => {
    return "\\N";
  },
  // Unique random value for NOT NULL UNIQUE token columns.
  randomToken: () => {
    return crypto.randomBytes(24).toString('hex');
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
    // example.com/.net/.org only, so stage can never mail a real inbox.
    return faker.internet.exampleEmail()
  },
  randomPassword: () => {
    return randomString(10);
  },
  randomPasswordHash: () => {
    const newPassword = randomString(10)
    const salt = bcrypt.genSaltSync(13, 'a');
    return bcrypt.hashSync(newPassword, salt);
  },
  randomClinicName: () => {
    return `Clinic ${faker.datatype.number({ min: 1, max: 9999 })}`;
  },

  // The helpers below keep NULLs as NULL (\N) and only replace real values.
  nullOrName: (v) => (isNull(v) ? v : faker.name.findName()),
  nullOrConfidential: (v) => (isNull(v) ? v : "Confidential"),
  nullOrPlanTitle: (v) => (isNull(v) ? v : "Therapy plan"),
  nullOrFilename: (v) => (isNull(v) ? v : "document.pdf"),
  nullOrUserAgent: (v) => (isNull(v) ? v : "Mozilla/5.0 (anonymised)"),
  // Unique per clinic (index_patients_on_clinic_id_and_pkey), so it must stay unique.
  nullOrRandomKey: (v) => (isNull(v) ? v : crypto.randomBytes(8).toString("hex")),
  // NOT NULL columns that held names or prod links.
  eventName: () => "Therapy session",
  exampleUrl: () => "https://example.com/anonymised",
  anonymisedS3Key: () => `anonymised/${crypto.randomBytes(12).toString("hex")}`,
  // Chat integration metadata: keep only structural keys, drop name/email/conversation.
  partnerMetadata: (v) => {
    if (isNull(v)) return v;
    try {
      const src = JSON.parse(fromCopy(v));
      const keep = {};
      for (const k of ["id", "clinic_id", "primary_group", "role"]) {
        if (k in src) keep[k] = src[k];
      }
      return toCopy(JSON.stringify(keep));
    } catch (e) {
      return "{}";
    }
  }
};

function isNull(v) {
  return v === "\\N";
}

// pg_dump COPY text format escapes backslash, tab, newline and carriage return.
function fromCopy(v) {
  return v.replace(/\\(.)/g, (_m, c) => ({ t: "\t", n: "\n", r: "\r", b: "\b", f: "\f", v: "\v" }[c] ?? c));
}

function toCopy(s) {
  return s.replace(/\\/g, "\\\\").replace(/\t/g, "\\t").replace(/\n/g, "\\n").replace(/\r/g, "\\r");
}
