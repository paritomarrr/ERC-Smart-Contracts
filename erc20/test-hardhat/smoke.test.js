// test/smoke.test.js
const hre = require("hardhat");
const { ethers } = hre;
const { expect } = require("chai");

describe("Smoke Test", function () {
  it("should load signers", async function () {
    const signers = await ethers.getSigners();
    expect(signers.length).to.be.greaterThan(0);
  });
});
