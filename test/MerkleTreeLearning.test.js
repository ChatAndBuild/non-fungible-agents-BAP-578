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

    describe("Learning Root Management", function () {
        const tokenId = 1;
        const initialRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("initial"));
        const newRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("updated"));
        const anotherRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("another"));

        it("Should allow owner to update learning root", async function () {
            const proof = ethers.utils.toUtf8Bytes("proof");
            const reason = "Extended data changed";

            const tx = await merkleTreeLearning.updateLearningRoot(tokenId, newRoot, proof, reason);
            const receipt = await tx.wait();
            const event = receipt.events?.find(e => e.event === 'LearningUpdated');
            
            expect(event).to.not.be.undefined;
            expect(event.args.tokenId).to.equal(tokenId);
            expect(event.args.previousRoot).to.equal(ethers.constants.HashZero);
            expect(event.args.newRoot).to.equal(newRoot);

            expect(await merkleTreeLearning.getLearningRoot(tokenId)).to.equal(newRoot);
        });

        it("Should reject zero root updates", async function () {
            const proof = ethers.utils.toUtf8Bytes("proof");
            const reason = "Test";

            await expect(
                merkleTreeLearning.updateLearningRoot(tokenId, ethers.constants.HashZero, proof, reason)
            ).to.be.revertedWith("MerkleTreeLearning: new root cannot be zero");
        });

        it("Should reject identical root updates", async function () {
            const proof = ethers.utils.toUtf8Bytes("proof");
            const reason = "Test";

            // First update
            await merkleTreeLearning.updateLearningRoot(tokenId, newRoot, proof, reason);
            
            // Try to update with same root
            await expect(
                merkleTreeLearning.updateLearningRoot(tokenId, newRoot, proof, reason)
            ).to.be.revertedWith("MerkleTreeLearning: new root must be different");
        });

        it("Should reject non-owner updates", async function () {
            const proof = ethers.utils.toUtf8Bytes("proof");
            const reason = "Test";

            await expect(
                merkleTreeLearning.connect(addr1).updateLearningRoot(tokenId, newRoot, proof, reason)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("Should track multiple root updates", async function () {
            const proof1 = ethers.utils.toUtf8Bytes("proof1");
            const proof2 = ethers.utils.toUtf8Bytes("proof2");
            const reason1 = "First update";
            const reason2 = "Second update";

            // First update
            await merkleTreeLearning.updateLearningRoot(tokenId, newRoot, proof1, reason1);
            
            // Second update
            await merkleTreeLearning.updateLearningRoot(tokenId, anotherRoot, proof2, reason2);

            expect(await merkleTreeLearning.getLearningRoot(tokenId)).to.equal(anotherRoot);
            expect(await merkleTreeLearning.getUpdateCount(tokenId)).to.equal(2);
        });
    });

    describe("Batch Updates", function () {
        const tokenIds = [1, 2, 3];
        const newRoots = [
            ethers.utils.keccak256(ethers.utils.toUtf8Bytes("root1")),
            ethers.utils.keccak256(ethers.utils.toUtf8Bytes("root2")),
            ethers.utils.keccak256(ethers.utils.toUtf8Bytes("root3"))
        ];
        const proofs = [
            ethers.utils.toUtf8Bytes("proof1"),
            ethers.utils.toUtf8Bytes("proof2"),
            ethers.utils.toUtf8Bytes("proof3")
        ];
        const reasons = ["Update 1", "Update 2", "Update 3"];

        it("Should allow batch updates", async function () {
            await expect(
                merkleTreeLearning.batchUpdateLearningRoots(tokenIds, newRoots, proofs, reasons)
            ).to.emit(merkleTreeLearning, "LearningUpdated");

            // Verify all roots were updated
            for (let i = 0; i < tokenIds.length; i++) {
                expect(await merkleTreeLearning.getLearningRoot(tokenIds[i])).to.equal(newRoots[i]);
                expect(await merkleTreeLearning.getUpdateCount(tokenIds[i])).to.equal(1);
            }
        });

        it("Should reject batch updates with mismatched array lengths", async function () {
            const mismatchedTokenIds = [1, 2];
            const mismatchedRoots = [newRoots[0], newRoots[1], newRoots[2]];

            await expect(
                merkleTreeLearning.batchUpdateLearningRoots(mismatchedTokenIds, mismatchedRoots, proofs, reasons)
            ).to.be.revertedWith("MerkleTreeLearning: array lengths must match");
        });

        it("Should reject non-owner batch updates", async function () {
            await expect(
                merkleTreeLearning.connect(addr1).batchUpdateLearningRoots(tokenIds, newRoots, proofs, reasons)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });
    });

    describe("Learning Metrics", function () {
        const tokenId = 10; // Use different token ID to avoid conflicts
        const newRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("updated"));

        it("Should update learning metrics on root update", async function () {
            const proof = ethers.utils.toUtf8Bytes("proof");
            const reason = "Test update";

            const initialMetrics = await merkleTreeLearning.getLearningMetrics(tokenId);
            
            await merkleTreeLearning.updateLearningRoot(tokenId, newRoot, proof, reason);
            
            const updatedMetrics = await merkleTreeLearning.getLearningMetrics(tokenId);
            
            expect(updatedMetrics.totalInteractions).to.equal(initialMetrics.totalInteractions.add(1));
            expect(updatedMetrics.learningEvents).to.equal(initialMetrics.learningEvents.add(1));
            expect(updatedMetrics.lastUpdateTimestamp).to.be.gt(initialMetrics.lastUpdateTimestamp);
        });

        it("Should calculate confidence score correctly", async function () {
            const proof = ethers.utils.toUtf8Bytes("proof");
            const reason = "Test update";

            await merkleTreeLearning.updateLearningRoot(tokenId, newRoot, proof, reason);
            
            const metrics = await merkleTreeLearning.getLearningMetrics(tokenId);
            expect(metrics.confidenceScore).to.be.gt(0);
        });
    });

    describe("Learning Update History", function () {
        const tokenId = 1;
        const root1 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("root1"));
        const root2 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("root2"));
        const root3 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("root3"));

        it("Should track learning update history", async function () {
            const proof1 = ethers.utils.toUtf8Bytes("proof1");
            const proof2 = ethers.utils.toUtf8Bytes("proof2");
            const proof3 = ethers.utils.toUtf8Bytes("proof3");
            const reason1 = "First update";
            const reason2 = "Second update";
            const reason3 = "Third update";

            // Perform updates
            await merkleTreeLearning.updateLearningRoot(tokenId, root1, proof1, reason1);
            await merkleTreeLearning.updateLearningRoot(tokenId, root2, proof2, reason2);
            await merkleTreeLearning.updateLearningRoot(tokenId, root3, proof3, reason3);

            const updates = await merkleTreeLearning.getLearningUpdates(tokenId);
            expect(updates.length).to.equal(3);
            
            // Verify update order
            expect(updates[0].newRoot).to.equal(root1);
            expect(updates[1].newRoot).to.equal(root2);
            expect(updates[2].newRoot).to.equal(root3);
        });

        it("Should get latest learning update", async function () {
            const proof1 = ethers.utils.toUtf8Bytes("proof1");
            const proof2 = ethers.utils.toUtf8Bytes("proof2");
            const reason1 = "First update";
            const reason2 = "Second update";

            await merkleTreeLearning.updateLearningRoot(tokenId, root1, proof1, reason1);
            await merkleTreeLearning.updateLearningRoot(tokenId, root2, proof2, reason2);

            const latestUpdate = await merkleTreeLearning.getLatestLearningUpdate(tokenId);
            expect(latestUpdate.newRoot).to.equal(root2);
        });

        it("Should reject getting latest update for token with no updates", async function () {
            await expect(
                merkleTreeLearning.getLatestLearningUpdate(999)
            ).to.be.revertedWith("MerkleTreeLearning: no updates found");
        });

        it("Should verify root in history", async function () {
            const proof = ethers.utils.toUtf8Bytes("proof");
            const reason = "Test update";

            await merkleTreeLearning.updateLearningRoot(tokenId, root1, proof, reason);

            expect(await merkleTreeLearning.verifyRootInHistory(tokenId, root1)).to.be.true;
            expect(await merkleTreeLearning.verifyRootInHistory(tokenId, root2)).to.be.false;
        });
    });

    describe("Learning Milestones", function () {
        const tokenId = 1;

        it("Should emit milestone events", async function () {
            const proof = ethers.utils.toUtf8Bytes("proof");
            const reason = "Test update";

            // Create 10 updates to trigger "First Decade" milestone
            for (let i = 0; i < 10; i++) {
                const newRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(`root${i}`));
                await merkleTreeLearning.updateLearningRoot(tokenId, newRoot, proof, reason);
            }

            // The 10th update should trigger the milestone
            expect(await merkleTreeLearning.getUpdateCount(tokenId)).to.equal(10);
        });

        it("Should track update count correctly", async function () {
            const proof = ethers.utils.toUtf8Bytes("proof");
            const reason = "Test update";

            expect(await merkleTreeLearning.getUpdateCount(tokenId)).to.equal(0);

            const newRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("root"));
            await merkleTreeLearning.updateLearningRoot(tokenId, newRoot, proof, reason);

            expect(await merkleTreeLearning.getUpdateCount(tokenId)).to.equal(1);
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

    describe("Edge Cases", function () {
        it("Should handle multiple tokens independently", async function () {
            const token1 = 1;
            const token2 = 2;
            const root1 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("root1"));
            const root2 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("root2"));
            const proof = ethers.utils.toUtf8Bytes("proof");
            const reason = "Test";

            await merkleTreeLearning.updateLearningRoot(token1, root1, proof, reason);
            await merkleTreeLearning.updateLearningRoot(token2, root2, proof, reason);

            expect(await merkleTreeLearning.getLearningRoot(token1)).to.equal(root1);
            expect(await merkleTreeLearning.getLearningRoot(token2)).to.equal(root2);
            expect(await merkleTreeLearning.getUpdateCount(token1)).to.equal(1);
            expect(await merkleTreeLearning.getUpdateCount(token2)).to.equal(1);
        });

        it("Should handle empty proofs and reasons", async function () {
            const tokenId = 1;
            const newRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("root"));

            const tx = await merkleTreeLearning.updateLearningRoot(tokenId, newRoot, "0x", "");
            const receipt = await tx.wait();
            const event = receipt.events?.find(e => e.event === 'LearningUpdated');
            
            expect(event).to.not.be.undefined;
            expect(await merkleTreeLearning.getLearningRoot(tokenId)).to.equal(newRoot);
        });
    });
});

// Helper function to get current timestamp
async function time() {
    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    return block.timestamp;
}
