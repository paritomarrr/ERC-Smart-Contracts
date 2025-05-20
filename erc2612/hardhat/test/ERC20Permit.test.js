const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  loadFixture,
  time,
} = require("@nomicfoundation/hardhat-network-helpers");

async function deployFixture() {
  const [holder, owner, spender, other] = await ethers.getSigners();

  const name = "My Token";
  const symbol = "MTK";
  const initialSupply = 100n;
  const token = await ethers.deployContract("TestERC20Permit", [name, symbol]);

  await token.$_mint(holder, initialSupply);

  return {
    holder,
    spender,
    owner,
    other,
    token,
  };
}

async function getPermitSignature({ token, owner, spender, value, deadline }) {
  // Step 1: Get chain ID and domain separator data
  const name = await token.name();
  const verifyingContract = await token.getAddress();
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const nonce = await token.nonces(owner.address);

  // Step 2: Build the domain
  const domain = {
    name,
    version: "1",
    chainId,
    verifyingContract,
  };

  // Step 3: Define types (EIP-712 typed data schema)
  const types = {
    Permit: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
      { name: "value", type: "uint256" },
      { name: "nonce", type: "uint256" },
      { name: "deadline", type: "uint256" },
    ],
  };

  // Step 4: Build the message to sign
  const message = {
    owner: owner.address,
    spender: spender.address,
    value,
    nonce,
    deadline,
  };

  // Step 5: Sign using EIP-712
  const signature = await owner.signTypedData(domain, types, message);
  const { v, r, s } = ethers.Signature.from(signature);

  return { v, r, s, signature, domain, types, message };
}
/**
 * TESTING CORE FEATURES
 * - INITIAL NONCE SHOULD BE ZERO
 * - `DOMAIN_SEPARATOR` MATCHES EXPECTED EIP-712 VALUE
 * - `PERMIT()` SUCCESS WITH VALID SIGNATURE
 * - NONCE INCREMENTS AFTER `PERMIT()`
 * - FAILS ON
 * > EXPIRED SIGNATURE
 * > SIGNATURE FROM WRONG SIGNER
 * > REUSED SIGNATURE (NONCE MISMATCH)
 */
describe("ERC20 Permit Testing", function () {
  beforeEach(async function () {
    // load clean state from fixture
    Object.assign(this, await loadFixture(deployFixture));
  });
  it("the initial nonce should be 0", async function () {
    const expectedNonce = 0n;
    const actualNonce = await this.token.nonces(this.holder);
    expect(actualNonce).to.equal(expectedNonce);
  });

  it("domain separator matches manual EIP712 domain separator hash", async function () {
    // Step 1: get domain fields from contract
    // construct the domain struct manually
    const domain = {
      name: await this.token.name(),
      version: "1",
      chainId: (await ethers.provider.getNetwork()).chainId,
      verifyingContract: this.token.target,
    };
    // Step 2: Hash the domain struct
    const domainSeparator = ethers.TypedDataEncoder.hashDomain(domain);
    // Step 3: Compare against the contract output
    expect(await this.token.DOMAIN_SEPARATOR()).to.equal(domainSeparator);
  });

  it("should permit with a valid signature", async function () {
    const deadline = (await time.latest()) + 3600; // 1 hour from now
    const value = 100n;

    const { v, r, s } = await getPermitSignature({
      token: this.token,
      owner: this.owner,
      spender: this.spender,
      value,
      deadline,
    });

    await this.token.permit(
      this.owner.address,
      this.spender.address,
      value,
      deadline,
      v,
      r,
      s
    );

    expect(await this.token.allowance(this.owner, this.spender)).to.equal(
      value
    );
  });

  it("overwrites previous permit allowance and increments once", async function () {
    const deadline = (await time.latest()) + 3600;
    const value = 100n;

    let { v, r, s } = await getPermitSignature({
      token: this.token,
      owner: this.owner,
      spender: this.spender,
      value,
      deadline,
    });

    await this.token.permit(
      this.owner.address,
      this.spender.address,
      value,
      deadline,
      v,
      r,
      s
    );

    expect(await this.token.allowance(this.owner, this.spender)).to.equal(
      value
    );
    expect(await this.token.nonces(this.owner)).to.equal(1n);

    const updatedValue = 999n;

    ({v, r, s} = await getPermitSignature({
        token: this.token,
        owner: this.owner,
        spender: this.spender,
        value: updatedValue,
        deadline
    }));

    await this.token.permit(
        this.owner.address,
        this.spender.address,
        updatedValue,
        deadline,
        v,
        r,
        s
    );

    expect(await this.token.allowance(this.owner, this.spender)).to.equal(updatedValue);
    expect(await this.token.nonces(this.owner)).to.equal(2n);
  });
});
