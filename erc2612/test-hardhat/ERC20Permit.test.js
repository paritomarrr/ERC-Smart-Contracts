const {ethers} = require('hardhat');
const {expect} = require('chai');
const {loadFixture} = require('@nomicfoundation/hardhat-network-helpers');

const {getDomain, domainSeparator, Permit} = require('./helper/eip712');
const time = require('./helper/time');

const name = 'My Token';
const symbol = 'MTKN';
const initialSupply = 100n;

async function fixture() {
    const [holder, spender, owner, other] = await ethers.getSigners();

    const token = await ethers.deployContract('ERC20Permit', [name, symbol, name]);
    await token.$_mint(holder, initialSupply);

    return {
        holder,
        spender,
        owner,
        other,
        token,
    };
}

describe('ERC20Permit', function () {
    beforeEach(async function () {
        Object.assign(this, await loadFixture(fixture));
    });

    it('initial nonce is 0', async function () {
        expect(await this.token.nonces(this.holder)).to.equal(0n);
    });

    it('domain separator', async function () {
        expect(await this.token.DOMAIN_SEPARATOR()).to.equal(await getDomain(this.token).then(domainSeparator));
    });

    describe('permit', function () {
        const value = 42n;
        const nonce = 0n;
        const maxDeadline = ethers.MaxUint256;

        beforeEach(function () {
            this.buildData = (contract, deadline = maxDeadline) => 
                getDomain(contract).then(domain => ({
                    domain,
                    types: {Permit},
                    message: {
                        owner: this.owner.address,
                        spender: this.spender.address,
                        value,
                        nonce, 
                        deadline,
                    },
                }));
        });

        it('accepted owner signature', async function () {
            const {v, r, s} = await this.buildData(this.token)
            .then(({domain, types, message}) => 
            this.owner.signTypedData(domain, types, message)
            ).then(ethers.Signature.from);

            await this.token.permit(this.owner, this.spender, value, maxDeadline, v, r, s);

            expect(await this.token.nonces(this.owner)).to.equal(1n);
            expect(await this.token.allowance(this.owner, this.spender)).to.equal(value);
        });

    })
})