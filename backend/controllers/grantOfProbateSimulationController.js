const grantOfProbateSimulationService = require("../services/grantOfProbateSimulationService.js");
const express = require("express");
const fs = require("fs");
const path = require("path");

const getGrantOfProbateURL = async (req, res) => {
  try {
    const { deceasedNRIC } = req.params;
    const pdfURL = await grantOfProbateSimulationService.getGrantOfProbateURL(
      deceasedNRIC
    );

    console.log(__dirname);
    const filePath = path.join(__dirname, "../data/" + pdfURL);

    if (fs.existsSync(filePath)) {
      res.setHeader("Content-Type", "application/pdf");
      res.setHeader(
        "Content-Disposition",
        'inline; filename="grant_of_probate.pdf"'
      );
      fs.createReadStream(filePath).pipe(res); // Stream the PDF file to the response
    } else {
      return res.status(404).json({ message: "File not found on server" });
    }
  } catch (error) {
    console.log(error.message);
    return res.status(400).json({ error: error.message });
  }
};

const confirmGrantOfProbate = async (req, res) => {
  try {
    const { deceasedNRIC } = req.params;
    if (await grantOfProbateSimulationService.confirmGrantOfProbate(deceasedNRIC)) {
      return res.status(200).json({
        result:
          "Here is a confirmation that the grant of probate with NRIC number " +
          deceasedNRIC +
          " has been issued",
      });
    }
  } catch (error) {
    console.log(error.message);
    return res.status(400).json({ error: error.message });
  }
};

const getGrantOfProbateToday = async (req, res) => {
  try {
    const result = await grantOfProbateSimulationService.getAllGrantOfProbateToday();
    if (result) {
      return res.status(200).json({ result: result });
    }
  } catch (error) {
    console.log(error.message);
    return res.status(400).json({ error: error.message });
  }
};

module.exports = { getGrantOfProbateURL, confirmGrantOfProbate, getGrantOfProbateToday };
