const { ethers } = require("hardhat");
const { expect } = require("chai");
const { time } = require('@nomicfoundation/hardhat-network-helpers');

// Used to reset test state
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
// Helpers to generate EIP712 domain + structured data
const { getDomain, domainSeparator, Permit } = require("./helper/eip712");
// Custom time manipulation utils
// const time = require("./helper/time");

// Constants used across the test suite
const name = "My Token";
const symbol = "MTKN";


// Duration helper (optional - or inline 7 * 24 * 60 * 60)
const ONE_WEEK_IN_SECS = 7 * 24 * 60 * 60;

// ========== FIXTURE =========== //
// Deploys the ERC20Permit contract + mints tokens to holder
async function fixture() {
  // Get test accounts
  const [holder, spender, owner, other] = await ethers.getSigners();

  // Deploys ERC20Permit token with name used for EIP712 domain separator
  const token = await ethers.deployContract("TestERC20Permit", [
    name,
    symbol,
  ]);

  // Mint initial tokens to `holder`
  await token.$_mint(holder, initialSupply);

  return {
    holder,
    spender,
    owner,
    other,
    token,
  };
}

// ========== TEST SUITE ========== //
describe("ERC20Permit", function () {
  beforeEach(async function () {
    // Load clean test state from fixture for each test
   i
  });

  it("initial nonce is 0", async function () {
    // nonce should start at 0 for every user
    expect(await this.token.nonces(this.holder)).to.equal(0n);
  });

  it("domain separator", async function () {
    // Domain separator matches manually computed version
    expect(await this.token.DOMAIN_SEPARATOR()).to.equal(
      // Recalculate expected separator
      await getDomain(this.token).then(domainSeparator)
    );
  });

  // ========== PERMIT-SPECIFIC TESTS ========== //
  describe("permit", function () {
    const value = 42n; // Amount to approve
    const nonce = 0n; // Always starts from 0
    const maxDeadline = ethers.MaxUint256; // Infinite deadline

    // helper to build the permit data
    beforeEach(function () {
      // Builds the full EIP-712 typed data struct for signing
      this.buildData = (contract, deadline = maxDeadline) =>
        getDomain(contract).then((domain) => ({
          domain,
          types: { Permit }, // import from helper
          message: {
            owner: this.owner.address,
            spender: this.spender.address,
            value,
            nonce,
            deadline,
          },
        }));
    });

    // valid signature updates allowance and increments nonce
    it("accepted owner signature", async function () {
      const { v, r, s } = await this.buildData(this.token)
        .then(
          ({ domain, types, message }) =>
            this.owner.signTypedData(domain, types, message) // Sign permit off-chain
        )
        .then(ethers.Signature.from); // decompose to (v, r, s)

      await this.token.permit(
        this.owner,
        this.spender,
        value,
        maxDeadline,
        v,
        r,
        s
      );

      // after permit(), nonce should increment
      expect(await this.token.nonces(this.owner)).to.equal(1n);
      // allowance should be updated
      expect(await this.token.allowance(this.owner, this.spender)).to.equal(
        value
      );
    });

    // Reused signature fails with invalidSigner error
    it("rejects reused signature", async function () {
      const { v, r, s, serialized } = await this.buildData(this.token)
        .then(({ domain, types, message }) =>
          this.owner.signTypedData(domain, types, message)
        )
        .then(ethers.Signature.from);

      // First usage is valid
      await this.token.permit(
        this.owner,
        this.spender,
        value,
        maxDeadline,
        v,
        r,
        s
      );

      // Now try to reuse the same signature with an incremented nonce
      const recovered = await this.buildData(this.token).then(
        ({ domain, types, message }) =>
          ethers.verifyTypedData(
            domain,
            types,
            { ...message, nonce: nonce + 1n, deadline: maxDeadline },
            serialized
          )
      );

      // Expect a revert due to invalid signer (nonce mismatch)
      await expect(
        this.token.permit(this.owner, this.spender, value, maxDeadline, v, r, s)
      )
        .to.be.revertedWithCustomError(this.token, "ERC2612InvalidSigner")
        .withArgs(recovered, this.owner);
    });

    // Signature from the wrong account (not owner) fails
    it("rejects other signature", async function () {
      const { v, r, s } = await this.buildData(this.token)
        .then(({ domain, types, message }) =>
          this.other.signTypedData(domain, types, message)
        )
        .then(ethers.Signature.from);

      await expect(
        this.token.permit(this.owner, this.spender, value, maxDeadline, v, r, s)
      )
        .to.be.revertedWithCustomError(this.token, "ERC2612InvalidSigner")
        .withArgs(this.other, this.owner);
    });

    // expired signature gets rejected
    it("rejects expired permit", async function () {
        const expiredDeadline = (await time.latest()) - ONE_WEEK_IN_SECS;
  
        const { domain, types, message } = await this.buildData(this.token, expiredDeadline);
        const sig = await this.owner.signTypedData(domain, types, message);
        const { v, r, s } = ethers.Signature.from(sig);
  
        await expect(
          this.token.permit(this.owner, this.spender, value, expiredDeadline, v, r, s)
        )
          .to.be.revertedWithCustomError(this.token, "ERC2612ExpiredSignature")
          .withArgs(expiredDeadline);
      });
  });
});
