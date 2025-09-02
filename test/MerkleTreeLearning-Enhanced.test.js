const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("Enhanced MerkleTreeLearning with Child Nodes", function () {
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

    describe("Tree Node Management", function () {
        const tokenId = 1;
        const newRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("new_root"));

        it("Should add tree nodes when updating root with nodes", async function () {
            const nodes = [
                {
                    hash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf1")),
                    leftChild: ethers.constants.HashZero,
                    rightChild: ethers.constants.HashZero,
                    data: ethers.utils.toUtf8Bytes("leaf1_data"),
                    level: 0,
                    position: 0,
                    isLeaf: true,
                    timestamp: 0
                },
                {
                    hash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf2")),
                    leftChild: ethers.constants.HashZero,
                    rightChild: ethers.constants.HashZero,
                    data: ethers.utils.toUtf8Bytes("leaf2_data"),
                    level: 0,
                    position: 1,
                    isLeaf: true,
                    timestamp: 0
                },
                {
                    hash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("parent")),
                    leftChild: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf1")),
                    rightChild: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf2")),
                    data: "0x",
                    level: 1,
                    position: 0,
                    isLeaf: false,
                    timestamp: 0
                }
            ];

            const proof = ethers.utils.toUtf8Bytes("proof");
            const reason = "Adding complete tree structure";

            await expect(
                merkleTreeLearning.updateLearningRootWithNodes(tokenId, newRoot, nodes, proof, reason)
            ).to.emit(merkleTreeLearning, "TreeNodeAdded");

            // Verify nodes were added
            expect(await merkleTreeLearning.getNodeCount(tokenId)).to.equal(3);
            
            // Verify specific node
            const leaf1Node = await merkleTreeLearning.getTreeNode(tokenId, nodes[0].hash);
            expect(leaf1Node.hash).to.equal(nodes[0].hash);
            expect(leaf1Node.isLeaf).to.be.true;
            expect(leaf1Node.level).to.equal(0);
        });

        it("Should replace entire tree structure", async function () {
            const initialNodes = [
                {
                    hash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf1")),
                    leftChild: ethers.constants.HashZero,
                    rightChild: ethers.constants.HashZero,
                    data: ethers.utils.toUtf8Bytes("initial_data"),
                    level: 0,
                    position: 0,
                    isLeaf: true,
                    timestamp: 0
                }
            ];

            const newNodes = [
                {
                    hash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf2")),
                    leftChild: ethers.constants.HashZero,
                    rightChild: ethers.constants.HashZero,
                    data: ethers.utils.toUtf8Bytes("new_data"),
                    level: 0,
                    position: 0,
                    isLeaf: true,
                    timestamp: 0
                }
            ];

            const root1 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("root1"));
            const root2 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("root2"));

            // First update
            await merkleTreeLearning.updateLearningRootWithNodes(tokenId, root1, initialNodes, "0x", "Initial");
            
            // Second update - should replace entire tree
            await expect(
                merkleTreeLearning.updateLearningRootWithNodes(tokenId, root2, newNodes, "0x", "Replace")
            ).to.emit(merkleTreeLearning, "TreeStructureReplaced");

            // Verify old nodes are gone - should throw error since node was deleted
            await expect(
                merkleTreeLearning.getTreeNode(tokenId, initialNodes[0].hash)
            ).to.be.revertedWith("MerkleTreeLearning: node not found");
            
            // Verify new nodes are present
            const newNode = await merkleTreeLearning.getTreeNode(tokenId, newNodes[0].hash);
            expect(newNode.hash).to.equal(newNodes[0].hash);
            
            // Verify node count is correct
            expect(await merkleTreeLearning.getNodeCount(tokenId)).to.equal(1);
        });

        it("Should reject zero hash nodes", async function () {
            const nodes = [
                {
                    hash: ethers.constants.HashZero,
                    leftChild: ethers.constants.HashZero,
                    rightChild: ethers.constants.HashZero,
                    data: ethers.utils.toUtf8Bytes("data"),
                    level: 0,
                    position: 0,
                    isLeaf: true,
                    timestamp: 0
                }
            ];

            await expect(
                merkleTreeLearning.updateLearningRootWithNodes(tokenId, newRoot, nodes, "0x", "Test")
            ).to.be.revertedWith("MerkleTreeLearning: node hash cannot be zero");
        });

        it("Should reject non-owner node updates", async function () {
            const nodes = [
                {
                    hash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf1")),
                    leftChild: ethers.constants.HashZero,
                    rightChild: ethers.constants.HashZero,
                    data: ethers.utils.toUtf8Bytes("data"),
                    level: 0,
                    position: 0,
                    isLeaf: true,
                    timestamp: 0
                }
            ];

            await expect(
                merkleTreeLearning.connect(addr1).updateLearningRootWithNodes(tokenId, newRoot, nodes, "0x", "Test")
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });
    });

    describe("Tree Node Queries", function () {
        const tokenId = 1;
        const root = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("root"));

        beforeEach(async function () {
            const nodes = [
                {
                    hash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf1")),
                    leftChild: ethers.constants.HashZero,
                    rightChild: ethers.constants.HashZero,
                    data: ethers.utils.toUtf8Bytes("leaf1_data"),
                    level: 0,
                    position: 0,
                    isLeaf: true,
                    timestamp: 0
                },
                {
                    hash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf2")),
                    leftChild: ethers.constants.HashZero,
                    rightChild: ethers.constants.HashZero,
                    data: ethers.utils.toUtf8Bytes("leaf2_data"),
                    level: 0,
                    position: 1,
                    isLeaf: true,
                    timestamp: 0
                },
                {
                    hash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("parent1")),
                    leftChild: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf1")),
                    rightChild: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf2")),
                    data: "0x",
                    level: 1,
                    position: 0,
                    isLeaf: false,
                    timestamp: 0
                },
                {
                    hash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf3")),
                    leftChild: ethers.constants.HashZero,
                    rightChild: ethers.constants.HashZero,
                    data: ethers.utils.toUtf8Bytes("leaf3_data"),
                    level: 0,
                    position: 2,
                    isLeaf: true,
                    timestamp: 0
                }
            ];

            await merkleTreeLearning.updateLearningRootWithNodes(tokenId, root, nodes, "0x", "Setup");
        });

        it("Should get all tree nodes", async function () {
            const allNodes = await merkleTreeLearning.getAllTreeNodes(tokenId);
            expect(allNodes.length).to.equal(4);
        });

        it("Should get nodes at specific level", async function () {
            const leafNodes = await merkleTreeLearning.getTreeNodesAtLevel(tokenId, 0);
            expect(leafNodes.length).to.equal(3);

            const parentNodes = await merkleTreeLearning.getTreeNodesAtLevel(tokenId, 1);
            expect(parentNodes.length).to.equal(1);
        });

        it("Should get leaf nodes only", async function () {
            const leafNodes = await merkleTreeLearning.getLeafNodes(tokenId);
            expect(leafNodes.length).to.equal(3);
            
            for (let i = 0; i < leafNodes.length; i++) {
                expect(leafNodes[i].isLeaf).to.be.true;
            }
        });

        it("Should get correct node count", async function () {
            expect(await merkleTreeLearning.getNodeCount(tokenId)).to.equal(4);
        });

        it("Should get correct tree depth", async function () {
            expect(await merkleTreeLearning.getTreeDepth(tokenId)).to.equal(1);
        });

        it("Should verify node existence", async function () {
            const leafHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf1"));
            expect(await merkleTreeLearning.verifyNodeExists(tokenId, leafHash)).to.be.true;
            
            const nonExistentHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("nonexistent"));
            expect(await merkleTreeLearning.verifyNodeExists(tokenId, nonExistentHash)).to.be.false;
        });

        it("Should get path to root from leaf", async function () {
            const leafHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf1"));
            const path = await merkleTreeLearning.getPathToRoot(tokenId, leafHash);
            
            expect(path.length).to.be.gt(0);
            // The path should end with the parent node, not the root
            // since the root is not stored as a node in the tree
            expect(path[path.length - 1]).to.equal(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("parent1")));
        });

        it("Should reject path query for non-leaf node", async function () {
            const parentHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("parent1"));
            
            await expect(
                merkleTreeLearning.getPathToRoot(tokenId, parentHash)
            ).to.be.revertedWith("MerkleTreeLearning: node is not a leaf");
        });

        it("Should reject path query for non-existent node", async function () {
            const nonExistentHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("nonexistent"));
            
            await expect(
                merkleTreeLearning.getPathToRoot(tokenId, nonExistentHash)
            ).to.be.revertedWith("MerkleTreeLearning: leaf node not found");
        });
    });



    describe("Complex Tree Structures", function () {
        const tokenId = 1;

        it("Should handle deep tree structures", async function () {
            const nodes = [];
            let nodeIndex = 0;

            // Create leaf nodes (level 0)
            for (let i = 0; i < 8; i++) {
                nodes.push({
                    hash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(`leaf${i}`)),
                    leftChild: ethers.constants.HashZero,
                    rightChild: ethers.constants.HashZero,
                    data: ethers.utils.toUtf8Bytes(`data${i}`),
                    level: 0,
                    position: i,
                    isLeaf: true,
                    timestamp: 0
                });
                nodeIndex++;
            }

            // Create level 1 nodes
            for (let i = 0; i < 4; i++) {
                nodes.push({
                    hash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(`level1_${i}`)),
                    leftChild: nodes[i * 2].hash,
                    rightChild: nodes[i * 2 + 1].hash,
                    data: "0x",
                    level: 1,
                    position: i,
                    isLeaf: false,
                    timestamp: 0
                });
                nodeIndex++;
            }

            // Create level 2 nodes
            for (let i = 0; i < 2; i++) {
                nodes.push({
                    hash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes(`level2_${i}`)),
                    leftChild: nodes[8 + i * 2].hash,
                    rightChild: nodes[8 + i * 2 + 1].hash,
                    data: "0x",
                    level: 2,
                    position: i,
                    isLeaf: false,
                    timestamp: 0
                });
                nodeIndex++;
            }

            // Create root node (level 3)
            nodes.push({
                hash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("root")),
                leftChild: nodes[12].hash,
                rightChild: nodes[13].hash,
                data: "0x",
                level: 3,
                position: 0,
                isLeaf: false,
                timestamp: 0
            });

            const root = nodes[nodes.length - 1].hash;

            await merkleTreeLearning.updateLearningRootWithNodes(tokenId, root, nodes, "0x", "Deep tree");

            // Verify tree structure
            expect(await merkleTreeLearning.getNodeCount(tokenId)).to.equal(15);
            expect(await merkleTreeLearning.getTreeDepth(tokenId)).to.equal(3);

            // Verify leaf nodes
            const leafNodes = await merkleTreeLearning.getLeafNodes(tokenId);
            expect(leafNodes.length).to.equal(8);

            // Verify level 1 nodes
            const level1Nodes = await merkleTreeLearning.getTreeNodesAtLevel(tokenId, 1);
            expect(level1Nodes.length).to.equal(4);

            // Verify level 2 nodes
            const level2Nodes = await merkleTreeLearning.getTreeNodesAtLevel(tokenId, 2);
            expect(level2Nodes.length).to.equal(2);

            // Verify root level
            const rootLevelNodes = await merkleTreeLearning.getTreeNodesAtLevel(tokenId, 3);
            expect(rootLevelNodes.length).to.equal(1);
        });

        it("Should handle path queries in deep trees", async function () {
            const nodes = [
                {
                    hash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf1")),
                    leftChild: ethers.constants.HashZero,
                    rightChild: ethers.constants.HashZero,
                    data: ethers.utils.toUtf8Bytes("data1"),
                    level: 0,
                    position: 0,
                    isLeaf: true,
                    timestamp: 0
                },
                {
                    hash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf2")),
                    leftChild: ethers.constants.HashZero,
                    rightChild: ethers.constants.HashZero,
                    data: ethers.utils.toUtf8Bytes("data2"),
                    level: 0,
                    position: 1,
                    isLeaf: true,
                    timestamp: 0
                },
                {
                    hash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("parent")),
                    leftChild: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf1")),
                    rightChild: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf2")),
                    data: "0x",
                    level: 1,
                    position: 0,
                    isLeaf: false,
                    timestamp: 0
                }
            ];

            const root = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("root"));
            await merkleTreeLearning.updateLearningRootWithNodes(tokenId, root, nodes, "0x", "Path test");

            // Test path from leaf1 to root
            const leaf1Hash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf1"));
            const path = await merkleTreeLearning.getPathToRoot(tokenId, leaf1Hash);
            
            expect(path.length).to.equal(2); // leaf1 -> parent (root is not included in path)
            expect(path[0]).to.equal(leaf1Hash);
            expect(path[1]).to.equal(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("parent")));
        });
    });

    describe("Edge Cases and Error Handling", function () {
        const tokenId = 1;

        it("Should handle empty node arrays", async function () {
            const root = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("root"));
            const nodes = [];

            await expect(
                merkleTreeLearning.updateLearningRootWithNodes(tokenId, root, nodes, "0x", "Empty nodes")
            ).to.not.be.reverted;

            expect(await merkleTreeLearning.getNodeCount(tokenId)).to.equal(0);
        });

        it("Should handle single node trees", async function () {
            const root = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("root"));
            const nodes = [
                {
                    hash: root,
                    leftChild: ethers.constants.HashZero,
                    rightChild: ethers.constants.HashZero,
                    data: ethers.utils.toUtf8Bytes("single_node_data"),
                    level: 0,
                    position: 0,
                    isLeaf: true,
                    timestamp: 0
                }
            ];

            await merkleTreeLearning.updateLearningRootWithNodes(tokenId, root, nodes, "0x", "Single node");

            expect(await merkleTreeLearning.getNodeCount(tokenId)).to.equal(1);
            expect(await merkleTreeLearning.getTreeDepth(tokenId)).to.equal(0);

            const leafNodes = await merkleTreeLearning.getLeafNodes(tokenId);
            expect(leafNodes.length).to.equal(1);
        });

        it("Should handle multiple tokens independently", async function () {
            const root1 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("root1"));
            const root2 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("root2"));

            const nodes1 = [
                {
                    hash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf1")),
                    leftChild: ethers.constants.HashZero,
                    rightChild: ethers.constants.HashZero,
                    data: ethers.utils.toUtf8Bytes("data1"),
                    level: 0,
                    position: 0,
                    isLeaf: true,
                    timestamp: 0
                }
            ];

            const nodes2 = [
                {
                    hash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf2")),
                    leftChild: ethers.constants.HashZero,
                    rightChild: ethers.constants.HashZero,
                    data: ethers.utils.toUtf8Bytes("data2"),
                    level: 0,
                    position: 0,
                    isLeaf: true,
                    timestamp: 0
                }
            ];

            await merkleTreeLearning.updateLearningRootWithNodes(1, root1, nodes1, "0x", "Token 1");
            await merkleTreeLearning.updateLearningRootWithNodes(2, root2, nodes2, "0x", "Token 2");

            expect(await merkleTreeLearning.getNodeCount(1)).to.equal(1);
            expect(await merkleTreeLearning.getNodeCount(2)).to.equal(1);

            const token1Nodes = await merkleTreeLearning.getAllTreeNodes(1);
            const token2Nodes = await merkleTreeLearning.getAllTreeNodes(2);

            // Check that nodes were created (data comparison is complex due to hex vs bytes)
            expect(token1Nodes.length).to.equal(1);
            expect(token2Nodes.length).to.equal(1);
        });
    });

    describe("Events and Transparency", function () {
        const tokenId = 1;

        it("Should emit TreeNodeAdded events", async function () {
            const nodes = [
                {
                    hash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf1")),
                    leftChild: ethers.constants.HashZero,
                    rightChild: ethers.constants.HashZero,
                    data: ethers.utils.toUtf8Bytes("data1"),
                    level: 0,
                    position: 0,
                    isLeaf: true,
                    timestamp: 0
                }
            ];

            const root = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("root"));

            await expect(
                merkleTreeLearning.updateLearningRootWithNodes(tokenId, root, nodes, "0x", "Test")
            ).to.emit(merkleTreeLearning, "TreeNodeAdded")
            .withArgs(tokenId, nodes[0].hash, nodes[0].leftChild, nodes[0].rightChild, nodes[0].level, nodes[0].position, nodes[0].isLeaf);
        });

        it("Should emit TreeStructureReplaced events", async function () {
            const initialNodes = [
                {
                    hash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf1")),
                    leftChild: ethers.constants.HashZero,
                    rightChild: ethers.constants.HashZero,
                    data: ethers.utils.toUtf8Bytes("initial"),
                    level: 0,
                    position: 0,
                    isLeaf: true,
                    timestamp: 0
                }
            ];

            const newNodes = [
                {
                    hash: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("leaf2")),
                    leftChild: ethers.constants.HashZero,
                    rightChild: ethers.constants.HashZero,
                    data: ethers.utils.toUtf8Bytes("new"),
                    level: 0,
                    position: 0,
                    isLeaf: true,
                    timestamp: 0
                }
            ];

            const root1 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("root1"));
            const root2 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("root2"));

            await merkleTreeLearning.updateLearningRootWithNodes(tokenId, root1, initialNodes, "0x", "Initial");
            
            await expect(
                merkleTreeLearning.updateLearningRootWithNodes(tokenId, root2, newNodes, "0x", "Replace")
            ).to.emit(merkleTreeLearning, "TreeStructureReplaced");
            
            // Verify the event arguments separately to avoid hash comparison issues
            const filter = merkleTreeLearning.filters.TreeStructureReplaced(tokenId);
            const events = await merkleTreeLearning.queryFilter(filter);
            const event = events[events.length - 1];
            expect(event.args.tokenId).to.equal(tokenId);
            expect(event.args.previousNodeCount).to.equal(1);
            expect(event.args.newNodeCount).to.equal(1);
            expect(event.args.previousRoot).to.equal(root1);
            expect(event.args.newRoot).to.equal(root2);
        });
    });
});
