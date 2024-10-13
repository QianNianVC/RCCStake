const {expect} = require("chai")
const {ethers} = require("hardhat")

describe("RCCStake", function() {
    let rccStake, RCCStakeFactory, ERCAAAMock, ercAAA, owner, addr1, addr2;
    const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
    
    beforeEach(async function() {
        [owner, addr1, addr2]= await ethers.getSigners()
        RCCStakeFactory = await ethers.getContractFactory("RCCStake")
        rccStake = await RCCStakeFactory.deploy()
        ERCAAAMock = await ethers.getContractFactory("ERCAAAMock")
        ercAAA = await ERCAAAMock.deploy("Mock IERC20 token names ERC20AAA", "ercAAA", 200)

        await rccStake.initialize(ercAAA, 0, 100, 10);
        await rccStake.addPool(ZERO_ADDRESS, 100, 1, 20, false);
        await rccStake.addPool(await ercAAA.getAddress(), 100, 1, 20, false);
    })

    it('should initialize with correct parameters', async () => {
        const token = await rccStake.RCC();
        const startBlock = await rccStake.startBlock();
        const endBlock = await rccStake.endBlock();
        const RCCPerBlock = await rccStake.RCCPerBlock();

        expect(token).to.eq(ercAAA)
        expect(startBlock).to.eq(0)
        expect(endBlock).to.eq(100)
        expect(RCCPerBlock).to.eq(10)
    });

    it('should allow admin to set RCC token', async () => {
        await rccStake.setRCC(addr1)
        const token = await rccStake.RCC()
        expect(token).to.eq(addr1)
    });

    it('should pause and unpause withdraw', async () => {
        await rccStake.pauseWithdraw();
        let withdrawPaused = await rccStake.withdrawPaused();
        expect(withdrawPaused).to.eq(true);

        await rccStake.unpauseWithdraw();
        withdrawPaused = await rccStake.withdrawPaused();
        expect(withdrawPaused).to.eq(false);
    });

    it('should pause and unpause claim', async function() {
        await rccStake.pauseClaim();
        let claimPaused = await rccStake.claimPaused();
        expect(claimPaused).to.be.true;

        await rccStake.unpauseClaim();
        claimPaused = await rccStake.claimPaused();
        expect(claimPaused).to.be.false;
    });

    it('should allow adin to st start block', async function() {
        await rccStake.setStartBlock(10);
        const startBlock = await rccStake.startBlock();
        expect(startBlock).to.eq(10);
    });

    it('should allow adin to st end block', async function() {
        // await expect(rccStake.connect(addr1).setStartBlock(10)).to.be.revertedWith("AccessControl")
        await expect(rccStake.connect(addr1).setStartBlock(10)).to.be.reverted;
    })

    /*----------addPool-----------*/
    it('should allow admin to add a pool', async function() {
        await rccStake.addPool(await ercAAA.getAddress(), 100, 1, 10, false)
        const poolLength = await rccStake.poolLength();
        expect(poolLength).to.eq(3);

        const pool = await rccStake.pool(2);
        expect(pool.stTokenAddress).to.eq(await ercAAA.getAddress())
        expect(pool.poolWeight).to.eq(100)
        expect(pool.minDepositAmount).to.eq(1)
        expect(pool.unstakeLockedBlocks).to.eq(10)
    });

    it('should revert if staking token address is invalid', async () => {
        await expect(rccStake.addPool(ZERO_ADDRESS, 100, 1, 10, false))
            .to.be.revertedWith("invalid staking token address")
    });

    it('should revert if non-admin tries to add a pool', async () => {
        await expect(rccStake.connect(addr1).addPool(await ercAAA.getAddress(), 100, 1, 10, false)).to.be.reverted;
    });

    it('should revert if unstake locked blocks is zero', async function() {
        await expect(rccStake.addPool(await ercAAA.getAddress(), 100, 1, 0, false)).to.be.revertedWith("invalid withdraw locked blocks");
    });

    it('should revert if current block is greater than end block', async function() {
        await rccStake.setEndBlock(0); // Set endBlock to a past block
        await expect(rccStake.addPool(await ercAAA.getAddress(), 100, 1, 10, false)).to.be.revertedWith("Already ended");
    });

    it('should emit AddPool event', async () => {
        const currentBlockNumber = await ethers.provider.getBlockNumber();
        await expect(rccStake.addPool(await ercAAA.getAddress(), 100, 1, 10, false))
            .to.emit(rccStake, 'AddPool')
            .withArgs(await ercAAA.getAddress(), 100, currentBlockNumber + 1, 1, 10)
    });

})