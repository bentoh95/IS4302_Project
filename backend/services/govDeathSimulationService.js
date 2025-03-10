// send death certificate if the security information is fulfilled (upload file, retrieve file, send file, check information provided)
// confirm if there is any death
// update death

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

module.exports = { getDeathCertURL };
