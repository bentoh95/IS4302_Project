// send death certificate if the security information is fulfilled (upload file, retrieve file, send file, check information provided)
// confirm if there is any death

const db = require("../firebase/firebaseAdmin.js");

const getDeathCertURL = async (deceasedNRIC) => {
  try {
    const snapshot = await db
      .collection("death_certificate")
      .doc(deceasedNRIC)
      .get();
    if (snapshot.exists) {
      return snapshot.data().deathCertURL;
    } else {
      throw {
        message: "No such document",
      };
    }
  } catch (error) {
    throw {
      message: error.message || error,
    };
  }
};

const confirmDeath = async (NRIC) => {
  try {
    const snapshot = await db.collection("death_certificate").doc(NRIC).get();
    if (snapshot.exists) {
      return true;
    } else {
      throw {
        message: "No such document",
      };
    }
  } catch (error) {
    throw {
      message: error.message || error,
    };
  }
};

const getAllDeathToday = async () => {
  try {
    const now = new Date();
    const startOfDay = new Date(now.setHours(0, 0, 0, 0));
    const endOfDay = new Date(now.setHours(23, 59, 59, 999));
    const snapshot = await db
      .collection("death_certificate")
      .where("deathDate", ">=", startOfDay)
      .where("deathDate", "<=", endOfDay)
      .get();
    if (snapshot.empty) {
      throw {
        message: "No such document",
      };
    } else {
      const results = snapshot.docs.map((doc) => doc.data());
      return results;
    }
  } catch (error) {
    throw {
      message: error.message || error,
    };
  }
};

module.exports = { getDeathCertURL, confirmDeath, getAllDeathToday };
