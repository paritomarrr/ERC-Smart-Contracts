const {ethers} = require('hardhat')
const { expect } = require('chai');
const {loadFixture } = require('@nomicfoundation/hardhat-network-helpers')
const {PANIC_CODES} = require('@nomicfoundation/hardhat-chai-matchers/panic')

const TOKENS = [{Token: '$ERC20'}, {Token: '$ERC20ApprovalMock', forcedApproval: true}];

const name = 'My Token';
const symbol = 'MTKN';
const initialSupply = 100n;

describe('ERC20', function () {
  for (const {Token, forcedApproval} of TOKENS) {
    describe(Token, function () {
      const fixture = async () => {
        const accounts = await ethers.getSigners();
        const [holder, recipient] = accounts;

        const token = await ethers.deployContract(Token, [name, symbol]);
        await token.$_mint(holder, initialSupply);

        return {accounts, holder, recipient, token};
      };

      this.beforeEach(async function () {
        Object.assign(this, await loadFixture(fixture));
      });

      shouldBehaveLikeERC20(initialSupply, {forcedApproval})
    })
  }
})