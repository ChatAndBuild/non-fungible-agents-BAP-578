const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("MerkleTreeLearning", function () {
    let MerkleTreeLearning;
    let merkleTreeLearning;
    let owner;
    let addr1;
    let addr2;
    let addr3;

    beforeEach(async function () {
        [owner, addr1, addr2, addr3] = await ethers.getSigners();

        MerkleTreeLearning = await ethers.getContractFactory("MerkleTreeLearning");
        merkleTreeLearning = await upgrades.deployProxy(
            MerkleTreeLearning,
            [],
            { initializer: "initialize" }
        );
        await merkleTreeLearning.deployed();
    });

    describe("Deployment", function () {
        it("Should initialize correctly", async function () {
            expect(await merkleTreeLearning.owner()).to.equal(owner.address);
        });
    });











    describe("Emergency Functions", function () {
        const tokenId = 1;
        const newRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("emergency"));

        it("Should allow owner to emergency reset root", async function () {
            await expect(
                merkleTreeLearning.emergencyResetRoot(tokenId, newRoot)
            ).to.emit(merkleTreeLearning, "LearningUpdated");

            expect(await merkleTreeLearning.getLearningRoot(tokenId)).to.equal(newRoot);
            expect(await merkleTreeLearning.getUpdateCount(tokenId)).to.equal(1);
        });

        it("Should reject emergency reset with zero root", async function () {
            await expect(
                merkleTreeLearning.emergencyResetRoot(tokenId, ethers.constants.HashZero)
            ).to.be.revertedWith("MerkleTreeLearning: new root cannot be zero");
        });

        it("Should reject non-owner emergency reset", async function () {
            await expect(
                merkleTreeLearning.connect(addr1).emergencyResetRoot(tokenId, newRoot)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });
    });

    describe("Access Control", function () {
        it("Should allow public access to learning metrics", async function () {
            const metrics = await merkleTreeLearning.getLearningMetrics(1);
            expect(metrics.totalInteractions).to.equal(0);
        });

        it("Should allow public access to learning root", async function () {
            const root = await merkleTreeLearning.getLearningRoot(1);
            expect(root).to.equal(ethers.constants.HashZero);
        });
    });


});

// Helper function to get current timestamp
async function time() {
    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    return block.timestamp;
}
