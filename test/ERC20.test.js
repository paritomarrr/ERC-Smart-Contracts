const { expect } = require("chai");
const hre = require("hardhat");

describe("ERC20 Workflow Test", function () {
  let owner, addr1, addr2;
  let ERC20Token;

  beforeEach(async function () {
    // get signers
    [owner, addr1, addr2] = await hre.ethers.getSigners();

    // deploy erc20 contract
    const ERC20 = await hre.ethers.getContractFactory("ERC20");
    ERC20Token = await ERC20.deploy("Paris Token", "PARIS", 18);
    await ERC20Token.waitForDeployment();
  });

  it("Should set the correct name and symbol", async function () {
    expect(await ERC20Token.name()).to.equal("Paris Token");
    expect(await ERC20Token.symbol()).to.equal("PARIS");
    expect(await ERC20Token.decimals()).to.equal(18);
  });

  it("Should mint tokens correctly", async function () {
    await ERC20Token.mint(owner.address, 1000);
    expect(await ERC20Token.balanceOf(owner.address)).to.equal(1000);
  });

  it("Should transfer token correctly", async function () {
    await ERC20Token.mint(owner.address, 1000);
    await ERC20Token.transfer(addr1.address, 200);

    expect(await ERC20Token.balanceOf(owner.address)).to.equal(800);
    expect(await ERC20Token.balanceOf(addr1.address)).to.equal(200);
  });

  it("Should approve and execute transferFrom", async function () {
    await ERC20Token.mint(owner.address, 1000);
    await ERC20Token.approve(addr1.address, 500);
    // use addr1 to execute transfer
    const ERC20WithAddr1 = await ERC20Token.connect(addr1);
    await ERC20WithAddr1.transferFrom(owner.address, addr2.address, 100);

    expect(await ERC20Token.balanceOf(addr2.address)).to.equal(100);
    expect(await ERC20Token.balanceOf(owner.address)).to.equal(900);
    expect(await ERC20Token.allowance(owner.address, addr1.address)).to.equal(
      400
    );
  });

  it("Should revert if the transfer amount is more than the balance", async function () {
    await ERC20Token.mint(owner.address, 100);

    await expect(
      ERC20Token.transfer(addr1.address, 200)
    ).to.be.revertedWithPanic(0x11); // panic code 0x11 -> underflow/overflow
  });
});
