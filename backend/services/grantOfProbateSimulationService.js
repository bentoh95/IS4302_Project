const db = require("../firebase/firebaseAdmin.js");

const getGrantOfProbateURL = async (deceasedNRIC) => {
  try {
    const snapshot = await db
      .collection("grants_of_probate")
      .doc(deceasedNRIC)
      .get();
    if (snapshot.exists) {
      return snapshot.data().documentURL;
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

const confirmGrantOfProbate = async (deceasedNRIC) => {
  try {
    const snapshot = await db.collection("grants_of_probate").doc(deceasedNRIC).get();
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

const getAllGrantOfProbateToday = async () => {
  try {
    const now = new Date();
    const startOfDay = new Date(now);
    startOfDay.setHours(0, 0, 0, 0);

    const endOfDay = new Date(now);
    endOfDay.setHours(23, 59, 59, 999);

    const snapshot = await db
      .collection("grants_of_probate")
      .where("grantDate", ">=", startOfDay)
      .where("grantDate", "<=", endOfDay)
      .get();

    if (snapshot.empty) {
      return []; // Return an empty array instead of throwing an error
    }

    return snapshot.docs.map((doc) => doc.data());
  } catch (error) {
    throw new Error(error.message || error);
  }
};

module.exports = { getGrantOfProbateURL , confirmGrantOfProbate, getAllGrantOfProbateToday };
