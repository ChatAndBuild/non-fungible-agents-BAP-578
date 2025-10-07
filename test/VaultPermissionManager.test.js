const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("VaultPermissionManager", function () {
    let vaultPermissionManager;
    let circuitBreaker;
    let owner, addr1, addr2, addr3, agent1;

    beforeEach(async function () {
        [owner, addr1, addr2, addr3, agent1] = await ethers.getSigners();

        // Deploy CircuitBreaker
        const CircuitBreaker = await ethers.getContractFactory("CircuitBreaker");
        circuitBreaker = await upgrades.deployProxy(
            CircuitBreaker,
            [owner.address, owner.address], // governance and emergencyMultiSig
            { initializer: 'initialize' }
        );
        await circuitBreaker.deployed();

        // Deploy VaultPermissionManager
        const VaultPermissionManager = await ethers.getContractFactory("VaultPermissionManager");
        vaultPermissionManager = await upgrades.deployProxy(
            VaultPermissionManager,
            [circuitBreaker.address, owner.address],
            { initializer: 'initialize' }
        );
        await vaultPermissionManager.deployed();
    });

    describe("Deployment", function () {
        it("Should initialize with correct parameters", async function () {
            expect(await vaultPermissionManager.circuitBreaker()).to.equal(circuitBreaker.address);
            expect(await vaultPermissionManager.owner()).to.equal(owner.address);
        });

        it("Should have zero initial stats", async function () {
            const stats = await vaultPermissionManager.getStats();
            expect(stats.totalPermissionsCount).to.equal(0);
            expect(stats.totalVaultsCount).to.equal(0);
            expect(stats.activePermissionsCount).to.equal(0);
        });
    });

    describe("Vault Management", function () {
        it("Should create a vault successfully", async function () {
            const vaultId = "test-vault-1";
            const description = "Test vault for unit testing";

            await vaultPermissionManager.connect(addr1).createVault(vaultId, description);

            const vaultInfo = await vaultPermissionManager.getVaultInfo(addr1.address, vaultId);
            expect(vaultInfo.owner).to.equal(addr1.address);
            expect(vaultInfo.vaultId).to.equal(vaultId);
            expect(vaultInfo.description).to.equal(description);
            expect(vaultInfo.isActive).to.be.true;
            expect(vaultInfo.createdAt).to.be.gt(0);

            const stats = await vaultPermissionManager.getStats();
            expect(stats.totalVaultsCount).to.equal(1);
        });

        it("Should reject creating vault with empty ID", async function () {
            await expect(
                vaultPermissionManager.connect(addr1).createVault("", "description")
            ).to.be.revertedWith("VaultPermissionManager: vault ID cannot be empty");
        });

        it("Should reject creating duplicate vault", async function () {
            const vaultId = "duplicate-vault";
            
            await vaultPermissionManager.connect(addr1).createVault(vaultId, "First vault");
            
            await expect(
                vaultPermissionManager.connect(addr1).createVault(vaultId, "Second vault")
            ).to.be.revertedWith("VaultPermissionManager: vault already exists");
        });

        it("Should allow different users to create vaults with same ID", async function () {
            const vaultId = "shared-vault-id";
            
            await vaultPermissionManager.connect(addr1).createVault(vaultId, "Addr1 vault");
            await vaultPermissionManager.connect(addr2).createVault(vaultId, "Addr2 vault");

            const vault1Info = await vaultPermissionManager.getVaultInfo(addr1.address, vaultId);
            const vault2Info = await vaultPermissionManager.getVaultInfo(addr2.address, vaultId);

            expect(vault1Info.owner).to.equal(addr1.address);
            expect(vault2Info.owner).to.equal(addr2.address);
        });

        it("Should deactivate vault successfully", async function () {
            const vaultId = "deactivate-test";
            
            await vaultPermissionManager.connect(addr1).createVault(vaultId, "Test vault");
            
            let vaultInfo = await vaultPermissionManager.getVaultInfo(addr1.address, vaultId);
            expect(vaultInfo.isActive).to.be.true;

            await vaultPermissionManager.connect(addr1).deactivateVault(vaultId);

            vaultInfo = await vaultPermissionManager.getVaultInfo(addr1.address, vaultId);
            expect(vaultInfo.isActive).to.be.false;
        });

        it("Should reject deactivating vault by non-owner", async function () {
            const vaultId = "unauthorized-deactivate";
            
            await vaultPermissionManager.connect(addr1).createVault(vaultId, "Test vault");
            
            await expect(
                vaultPermissionManager.connect(addr2).deactivateVault(vaultId)
            ).to.be.revertedWith("VaultPermissionManager: vault not found or not owner");
        });
    });

    describe("Permission Management", function () {
        beforeEach(async function () {
            // Create a test vault
            await vaultPermissionManager.connect(addr1).createVault("test-vault", "Test vault");
        });

        it("Should grant permission successfully", async function () {
            const vaultId = "test-vault";
            const duration = 3600; // 1 hour
            const metadata = "Test permission";

            const tx = await vaultPermissionManager.connect(addr1).grantPermission(
                addr2.address,
                vaultId,
                1, // READ permission
                duration,
                metadata
            );

            const receipt = await tx.wait();
            const permissionGrantedEvent = receipt.events.find(e => e.event === 'PermissionGranted');
            
            expect(permissionGrantedEvent).to.not.be.undefined;
            expect(permissionGrantedEvent.args.vaultOwner).to.equal(addr1.address);
            expect(permissionGrantedEvent.args.delegate).to.equal(addr2.address);
            expect(permissionGrantedEvent.args.vaultId).to.equal(vaultId);

            const stats = await vaultPermissionManager.getStats();
            expect(stats.totalPermissionsCount).to.equal(1);
            expect(stats.activePermissionsCount).to.equal(1);
        });

        it("Should reject granting permission to zero address", async function () {
            await expect(
                vaultPermissionManager.connect(addr1).grantPermission(
                    ethers.constants.AddressZero,
                    "test-vault",
                    1, // READ permission
                    3600,
                    "metadata"
                )
            ).to.be.revertedWith("VaultPermissionManager: delegate is zero address");
        });

        it("Should reject granting permission to self", async function () {
            await expect(
                vaultPermissionManager.connect(addr1).grantPermission(
                    addr1.address,
                    "test-vault",
                    1, // READ permission
                    3600,
                    "metadata"
                )
            ).to.be.revertedWith("VaultPermissionManager: cannot grant permission to self");
        });

        it("Should reject granting NONE permission", async function () {
            await expect(
                vaultPermissionManager.connect(addr1).grantPermission(
                    addr2.address,
                    "test-vault",
                    0, // NONE permission
                    3600,
                    "metadata"
                )
            ).to.be.revertedWith("VaultPermissionManager: cannot grant NONE permission");
        });

        it("Should reject granting permission with zero duration", async function () {
            await expect(
                vaultPermissionManager.connect(addr1).grantPermission(
                    addr2.address,
                    "test-vault",
                    1, // READ permission
                    0,
                    "metadata"
                )
            ).to.be.revertedWith("VaultPermissionManager: duration must be greater than 0");
        });

        it("Should revoke permission successfully", async function () {
            const vaultId = "test-vault";
            
            // Grant permission
            const tx = await vaultPermissionManager.connect(addr1).grantPermission(
                addr2.address,
                vaultId,
                1, // READ permission
                3600,
                "metadata"
            );

            const receipt = await tx.wait();
            const permissionGrantedEvent = receipt.events.find(e => e.event === 'PermissionGranted');
            const permissionId = permissionGrantedEvent.args.permissionId;

            // Revoke permission
            await vaultPermissionManager.connect(addr1).revokePermission(permissionId);

            const permission = await vaultPermissionManager.permissions(permissionId);
            expect(permission.isActive).to.be.false;

            const stats = await vaultPermissionManager.getStats();
            expect(stats.activePermissionsCount).to.equal(0);
        });

        it("Should reject revoking permission by non-owner", async function () {
            const vaultId = "test-vault";
            
            // Grant permission
            const tx = await vaultPermissionManager.connect(addr1).grantPermission(
                addr2.address,
                vaultId,
                1, // READ permission
                3600,
                "metadata"
            );

            const receipt = await tx.wait();
            const permissionGrantedEvent = receipt.events.find(e => e.event === 'PermissionGranted');
            const permissionId = permissionGrantedEvent.args.permissionId;

            // Try to revoke by non-owner
            await expect(
                vaultPermissionManager.connect(addr2).revokePermission(permissionId)
            ).to.be.revertedWith("VaultPermissionManager: not permission owner");
        });
    });

    describe("Permission Checking", function () {
        beforeEach(async function () {
            // Create a test vault
            await vaultPermissionManager.connect(addr1).createVault("test-vault", "Test vault");
        });

        it("Should return true for vault owner access", async function () {
            const [hasPermission, level] = await vaultPermissionManager.checkPermission(
                addr1.address,
                "test-vault",
                addr1.address,
                3 // ADMIN level
            );

            expect(hasPermission).to.be.true;
            expect(level).to.equal(3); // ADMIN
        });

        it("Should return true for valid delegate permission", async function () {
            // Grant READ permission
            await vaultPermissionManager.connect(addr1).grantPermission(
                addr2.address,
                "test-vault",
                1, // READ permission
                3600,
                "metadata"
            );

            const [hasPermission, level] = await vaultPermissionManager.checkPermission(
                addr1.address,
                "test-vault",
                addr2.address,
                1 // READ level
            );

            expect(hasPermission).to.be.true;
            expect(level).to.equal(1); // READ
        });

        it("Should return false for insufficient permission level", async function () {
            // Grant READ permission
            await vaultPermissionManager.connect(addr1).grantPermission(
                addr2.address,
                "test-vault",
                1, // READ permission
                3600,
                "metadata"
            );

            const [hasPermission, level] = await vaultPermissionManager.connect(addr1).checkPermission(
                addr1.address,
                "test-vault",
                addr2.address,
                2 // WRITE level (higher than READ)
            );

            expect(hasPermission).to.be.false;
            expect(level).to.equal(1); // READ
        });

        it("Should return false for non-existent permission", async function () {
            const [hasPermission, level] = await vaultPermissionManager.checkPermission(
                addr1.address,
                "test-vault",
                addr3.address,
                1 // READ level
            );

            expect(hasPermission).to.be.false;
            expect(level).to.equal(0); // NONE
        });

        it("Should return false for expired permission", async function () {
            // Grant permission with very short duration
            await vaultPermissionManager.connect(addr1).grantPermission(
                addr2.address,
                "test-vault",
                1, // READ permission
                1, // 1 second
                "metadata"
            );

            // Wait for permission to expire
            await ethers.provider.send("evm_increaseTime", [2]);
            await ethers.provider.send("evm_mine");

            const [hasPermission, level] = await vaultPermissionManager.checkPermission(
                addr1.address,
                "test-vault",
                addr2.address,
                1 // READ level
            );

            expect(hasPermission).to.be.false;
            expect(level).to.equal(0); // NONE
        });
    });

    describe("Agent Authorization", function () {
        it("Should authorize agent successfully", async function () {
            await vaultPermissionManager.connect(owner).setAgentAuthorization(agent1.address, true);
            
            expect(await vaultPermissionManager.authorizedAgents(agent1.address)).to.be.true;
        });

        it("Should deauthorize agent successfully", async function () {
            await vaultPermissionManager.connect(owner).setAgentAuthorization(agent1.address, true);
            await vaultPermissionManager.connect(owner).setAgentAuthorization(agent1.address, false);
            
            expect(await vaultPermissionManager.authorizedAgents(agent1.address)).to.be.false;
        });

        it("Should reject agent authorization by non-owner", async function () {
            await expect(
                vaultPermissionManager.connect(addr1).setAgentAuthorization(agent1.address, true)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });
    });

    describe("Vault Access Recording", function () {
        beforeEach(async function () {
            // Create a test vault and authorize agent
            await vaultPermissionManager.connect(addr1).createVault("test-vault", "Test vault");
            await vaultPermissionManager.connect(owner).setAgentAuthorization(agent1.address, true);
        });

        it("Should record vault access by vault owner", async function () {
            const tx = await vaultPermissionManager.connect(addr1).recordVaultAccess(
                addr1.address,
                "test-vault",
                addr1.address,
                3 // ADMIN level
            );

            const receipt = await tx.wait();
            const vaultAccessedEvent = receipt.events.find(e => e.event === 'VaultAccessed');
            
            expect(vaultAccessedEvent).to.not.be.undefined;
            expect(vaultAccessedEvent.args[0]).to.equal(addr1.address); // vaultOwner
            expect(vaultAccessedEvent.args[1].hash).to.equal(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test-vault"))); // vaultId hash
            expect(vaultAccessedEvent.args[2]).to.equal(addr1.address); // accessor
        });

        it("Should record vault access by authorized agent", async function () {
            const tx = await vaultPermissionManager.connect(agent1).recordVaultAccess(
                addr1.address,
                "test-vault",
                addr2.address,
                1 // READ level
            );

            const receipt = await tx.wait();
            const vaultAccessedEvent = receipt.events.find(e => e.event === 'VaultAccessed');
            
            expect(vaultAccessedEvent).to.not.be.undefined;
        });

        it("Should reject vault access recording by unauthorized address", async function () {
            await expect(
                vaultPermissionManager.connect(addr2).recordVaultAccess(
                    addr1.address,
                    "test-vault",
                    addr2.address,
                    1 // READ level
                )
            ).to.be.revertedWith("VaultPermissionManager: not authorized to record access");
        });
    });

    describe("Permission Cleanup", function () {
        beforeEach(async function () {
            // Create a test vault
            await vaultPermissionManager.connect(addr1).createVault("test-vault", "Test vault");
        });

        it("Should cleanup expired permissions with pagination", async function () {
            // Grant permission with very short duration
            await vaultPermissionManager.connect(addr1).grantPermission(
                addr2.address,
                "test-vault",
                1, // READ permission
                1, // 1 second
                "metadata"
            );

            let stats = await vaultPermissionManager.getStats();
            expect(stats.activePermissionsCount).to.equal(1);

            // Wait for permission to expire
            await ethers.provider.send("evm_increaseTime", [2]);
            await ethers.provider.send("evm_mine");

            // Cleanup expired permissions with pagination
            await vaultPermissionManager.cleanupExpiredPermissions(1, 100);

            stats = await vaultPermissionManager.getStats();
            expect(stats.activePermissionsCount).to.equal(0);
        });

        it("Should handle partial cleanup with pagination", async function () {
            // Create multiple permissions
            for (let i = 0; i < 5; i++) {
                await vaultPermissionManager.connect(addr1).grantPermission(
                    addr2.address,
                    "test-vault",
                    1, // READ permission
                    1, // 1 second
                    `metadata-${i}`
                );
            }

            let stats = await vaultPermissionManager.getStats();
            expect(stats.activePermissionsCount).to.equal(5);

            // Wait for permissions to expire
            await ethers.provider.send("evm_increaseTime", [2]);
            await ethers.provider.send("evm_mine");

            // Cleanup first 3 permissions
            await vaultPermissionManager.cleanupExpiredPermissions(1, 3);

            stats = await vaultPermissionManager.getStats();
            expect(stats.activePermissionsCount).to.equal(2);

            // Cleanup remaining permissions
            await vaultPermissionManager.cleanupExpiredPermissions(4, 10);

            stats = await vaultPermissionManager.getStats();
            expect(stats.activePermissionsCount).to.equal(0);
        });

        it("Should cleanup expired vault permissions", async function () {
            // Grant multiple permissions for the vault
            await vaultPermissionManager.connect(addr1).grantPermission(
                addr2.address,
                "test-vault",
                1, // READ permission
                1, // 1 second
                "metadata1"
            );

            await vaultPermissionManager.connect(addr1).grantPermission(
                addr3.address,
                "test-vault",
                1, // READ permission
                1, // 1 second
                "metadata2"
            );

            let stats = await vaultPermissionManager.getStats();
            expect(stats.activePermissionsCount).to.equal(2);

            // Wait for permissions to expire
            await ethers.provider.send("evm_increaseTime", [2]);
            await ethers.provider.send("evm_mine");

            // Cleanup expired vault permissions
            await vaultPermissionManager.connect(addr1).cleanupExpiredVaultPermissions(addr1.address, "test-vault", 10);

            stats = await vaultPermissionManager.getStats();
            expect(stats.activePermissionsCount).to.equal(0);
        });

        it("Should cleanup expired user permissions", async function () {
            // Create another vault and grant permissions
            await vaultPermissionManager.connect(addr2).createVault("test-vault-2", "Test vault 2");
            
            await vaultPermissionManager.connect(addr1).grantPermission(
                addr3.address,
                "test-vault",
                1, // READ permission
                1, // 1 second
                "metadata1"
            );

            await vaultPermissionManager.connect(addr2).grantPermission(
                addr3.address,
                "test-vault-2",
                1, // READ permission
                1, // 1 second
                "metadata2"
            );

            let stats = await vaultPermissionManager.getStats();
            expect(stats.activePermissionsCount).to.equal(2);

            // Wait for permissions to expire
            await ethers.provider.send("evm_increaseTime", [2]);
            await ethers.provider.send("evm_mine");

            // Cleanup expired user permissions
            await vaultPermissionManager.connect(addr3).cleanupExpiredUserPermissions(addr3.address, 10);

            stats = await vaultPermissionManager.getStats();
            expect(stats.activePermissionsCount).to.equal(0);
        });

        it("Should get next cleanup index", async function () {
            // Create multiple permissions
            for (let i = 0; i < 3; i++) {
                await vaultPermissionManager.connect(addr1).grantPermission(
                    addr2.address,
                    "test-vault",
                    1, // READ permission
                    1, // 1 second
                    `metadata-${i}`
                );
            }

            // Wait for permissions to expire
            await ethers.provider.send("evm_increaseTime", [2]);
            await ethers.provider.send("evm_mine");

            // Check next cleanup index
            const [nextIndex, expiredCount] = await vaultPermissionManager.getNextCleanupIndex(1, 2);
            expect(expiredCount).to.equal(2);
            expect(nextIndex).to.equal(3); // Continue from index 3

            // Check remaining cleanup
            const [nextIndex2, expiredCount2] = await vaultPermissionManager.getNextCleanupIndex(3, 10);
            expect(expiredCount2).to.equal(1);
            expect(nextIndex2).to.equal(0); // Complete
        });

        it("Should reject cleanup with invalid parameters", async function () {
            await expect(
                vaultPermissionManager.cleanupExpiredPermissions(1, 0)
            ).to.be.revertedWith("VaultPermissionManager: maxIterations must be greater than 0");

            await expect(
                vaultPermissionManager.cleanupExpiredPermissions(1, 1001)
            ).to.be.revertedWith("VaultPermissionManager: maxIterations too high");
        });

        it("Should cleanup expired permissions (simple version)", async function () {
            // Grant permission with very short duration
            await vaultPermissionManager.connect(addr1).grantPermission(
                addr2.address,
                "test-vault",
                1, // READ permission
                1, // 1 second
                "metadata"
            );

            let stats = await vaultPermissionManager.getStats();
            expect(stats.activePermissionsCount).to.equal(1);

            // Wait for permission to expire
            await ethers.provider.send("evm_increaseTime", [2]);
            await ethers.provider.send("evm_mine");

            // Cleanup expired permissions (simple version)
            await vaultPermissionManager.cleanupAllExpiredPermissions();

            stats = await vaultPermissionManager.getStats();
            expect(stats.activePermissionsCount).to.equal(0);
        });
    });

    describe("Circuit Breaker Integration", function () {
        it("Should pause operations when circuit breaker is active", async function () {
            await circuitBreaker.setGlobalPause(true);

            await expect(
                vaultPermissionManager.connect(addr1).createVault("test-vault", "description")
            ).to.be.revertedWith("VaultPermissionManager: system is paused");
        });
    });

    describe("Vault Viewing", function () {
        beforeEach(async function () {
            // Create a test vault
            await vaultPermissionManager.connect(addr1).createVault("test-vault", "Test vault description");
        });

        it("Should allow vault owner to view vault contents", async function () {
            const [vaultInfo, hasAccess] = await vaultPermissionManager.connect(addr1).viewVaultContents(
                addr1.address,
                "test-vault"
            );

            expect(hasAccess).to.be.true;
            expect(vaultInfo.owner).to.equal(addr1.address);
            expect(vaultInfo.vaultId).to.equal("test-vault");
            expect(vaultInfo.description).to.equal("Test vault description");
            expect(vaultInfo.isActive).to.be.true;
        });

        it("Should allow user with READ permission to view vault contents", async function () {
            // Grant READ permission
            await vaultPermissionManager.connect(addr1).grantPermission(
                addr2.address,
                "test-vault",
                1, // READ permission
                3600,
                "metadata"
            );

            const [vaultInfo, hasAccess] = await vaultPermissionManager.connect(addr2).viewVaultContents(
                addr1.address,
                "test-vault"
            );

            expect(hasAccess).to.be.true;
            expect(vaultInfo.owner).to.equal(addr1.address);
            expect(vaultInfo.vaultId).to.equal("test-vault");
            expect(vaultInfo.description).to.equal("Test vault description");
        });

        it("Should allow user with WRITE permission to view vault contents", async function () {
            // Grant WRITE permission
            await vaultPermissionManager.connect(addr1).grantPermission(
                addr2.address,
                "test-vault",
                2, // WRITE permission
                3600,
                "metadata"
            );

            const [vaultInfo, hasAccess] = await vaultPermissionManager.connect(addr2).viewVaultContents(
                addr1.address,
                "test-vault"
            );

            expect(hasAccess).to.be.true;
            expect(vaultInfo.owner).to.equal(addr1.address);
            expect(vaultInfo.vaultId).to.equal("test-vault");
        });

        it("Should allow user with ADMIN permission to view vault contents", async function () {
            // Grant ADMIN permission
            await vaultPermissionManager.connect(addr1).grantPermission(
                addr2.address,
                "test-vault",
                3, // ADMIN permission
                3600,
                "metadata"
            );

            const [vaultInfo, hasAccess] = await vaultPermissionManager.connect(addr2).viewVaultContents(
                addr1.address,
                "test-vault"
            );

            expect(hasAccess).to.be.true;
            expect(vaultInfo.owner).to.equal(addr1.address);
            expect(vaultInfo.vaultId).to.equal("test-vault");
        });

        it("Should reject viewing vault contents without permission", async function () {
            await expect(
                vaultPermissionManager.connect(addr2).viewVaultContents(
                    addr1.address,
                    "test-vault"
                )
            ).to.be.revertedWith("VaultPermissionManager: insufficient permissions to view vault");
        });

        it("Should reject viewing non-existent vault", async function () {
            await expect(
                vaultPermissionManager.connect(addr1).viewVaultContents(
                    addr1.address,
                    "non-existent-vault"
                )
            ).to.be.revertedWith("VaultPermissionManager: vault not found");
        });

        it("Should reject viewing vault with expired permission", async function () {
            // Grant permission with very short duration
            await vaultPermissionManager.connect(addr1).grantPermission(
                addr2.address,
                "test-vault",
                1, // READ permission
                1, // 1 second
                "metadata"
            );

            // Wait for permission to expire
            await ethers.provider.send("evm_increaseTime", [2]);
            await ethers.provider.send("evm_mine");

            await expect(
                vaultPermissionManager.connect(addr2).viewVaultContents(
                    addr1.address,
                    "test-vault"
                )
            ).to.be.revertedWith("VaultPermissionManager: insufficient permissions to view vault");
        });

        it("Should reject viewing vault with revoked permission", async function () {
            // Grant permission
            await vaultPermissionManager.connect(addr1).grantPermission(
                addr2.address,
                "test-vault",
                1, // READ permission
                3600,
                "metadata"
            );

            // Revoke permission
            await vaultPermissionManager.connect(addr1).revokePermission(1);

            await expect(
                vaultPermissionManager.connect(addr2).viewVaultContents(
                    addr1.address,
                    "test-vault"
                )
            ).to.be.revertedWith("VaultPermissionManager: insufficient permissions to view vault");
        });

        it("Should reject viewing deactivated vault", async function () {
            // Deactivate vault
            await vaultPermissionManager.connect(addr1).deactivateVault("test-vault");

            // Even vault owner should not be able to view deactivated vault
            await expect(
                vaultPermissionManager.connect(addr1).viewVaultContents(
                    addr1.address,
                    "test-vault"
                )
            ).to.be.revertedWith("VaultPermissionManager: vault is not active");
        });
    });

    describe("Statistics and Queries", function () {
        beforeEach(async function () {
            // Create test vaults and permissions
            await vaultPermissionManager.connect(addr1).createVault("vault1", "Vault 1");
            await vaultPermissionManager.connect(addr2).createVault("vault2", "Vault 2");
            
            await vaultPermissionManager.connect(addr1).grantPermission(
                addr2.address,
                "vault1",
                1, // READ permission
                3600,
                "metadata"
            );
        });

        it("Should return correct user permissions", async function () {
            const userPermissions = await vaultPermissionManager.getUserPermissions(addr2.address);
            expect(userPermissions.length).to.equal(1);
            expect(userPermissions[0]).to.equal(1);
        });

        it("Should return correct vault permissions", async function () {
            const vaultPermissions = await vaultPermissionManager.getVaultPermissions(addr1.address, "vault1");
            expect(vaultPermissions.length).to.equal(1);
            expect(vaultPermissions[0]).to.equal(1);
        });

        it("Should return correct stats", async function () {
            const stats = await vaultPermissionManager.getStats();
            expect(stats.totalVaultsCount).to.equal(2);
            expect(stats.totalPermissionsCount).to.equal(1);
            expect(stats.activePermissionsCount).to.equal(1);
        });
    });
});
