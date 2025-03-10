const govDeathSimulationService = require("../services/govDeathSimulationService.js");
const express = require("express");
const fs = require("fs");
const path = require("path");

const getDeathCertURL = async (req, res) => {
  try {
    const { deceasedNRIC } = req.params;
    const pdfURL = await govDeathSimulationService.getDeathCertURL(
      deceasedNRIC
    );

    console.log(__dirname);
    const filePath = path.join(__dirname, "../data/" + pdfURL);

    if (fs.existsSync(filePath)) {
      res.setHeader("Content-Type", "application/pdf");
      res.setHeader(
        "Content-Disposition",
        'inline; filename="death_certificate.pdf"'
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

module.exports = { getDeathCertURL };
