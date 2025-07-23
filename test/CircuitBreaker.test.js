const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("CircuitBreaker", function () {
    let CircuitBreaker;
    let circuitBreaker;
    let owner;
    let governance;
    let emergencyMultiSig;
    let addr1;
    let addr2;
    let addrs;

    beforeEach(async function () {
        [owner, governance, emergencyMultiSig, addr1, addr2, ...addrs] = await ethers.getSigners();
        
        CircuitBreaker = await ethers.getContractFactory("CircuitBreaker");
        circuitBreaker = await upgrades.deployProxy(
            CircuitBreaker,
            [governance.address, emergencyMultiSig.address],
            { initializer: "initialize" }
        );
        await circuitBreaker.deployed();
    });

    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            expect(await circuitBreaker.owner()).to.equal(owner.address);
        });

        it("Should set the right governance address", async function () {
            expect(await circuitBreaker.governance()).to.equal(governance.address);
        });

        it("Should set the right emergency multi-sig address", async function () {
            expect(await circuitBreaker.emergencyMultiSig()).to.equal(emergencyMultiSig.address);
        });

        it("Should initialize with global pause disabled", async function () {
            expect(await circuitBreaker.globalPause()).to.equal(false);
        });

        it("Should not allow zero address for governance during initialization", async function () {
            await expect(
                upgrades.deployProxy(
                    CircuitBreaker,
                    [ethers.constants.AddressZero, emergencyMultiSig.address],
                    { initializer: "initialize" }
                )
            ).to.be.revertedWith("CircuitBreaker: governance is zero address");
        });

        it("Should not allow zero address for emergency multi-sig during initialization", async function () {
            await expect(
                upgrades.deployProxy(
                    CircuitBreaker,
                    [governance.address, ethers.constants.AddressZero],
                    { initializer: "initialize" }
                )
            ).to.be.revertedWith("CircuitBreaker: multi-sig is zero address");
        });
    });

    describe("Global Pause Management", function () {
        it("Should allow governance to set global pause", async function () {
            await expect(circuitBreaker.connect(governance).setGlobalPause(true))
                .to.emit(circuitBreaker, "GlobalPauseUpdated")
                .withArgs(true);

            expect(await circuitBreaker.globalPause()).to.equal(true);
        });

        it("Should allow emergency multi-sig to set global pause", async function () {
            await expect(circuitBreaker.connect(emergencyMultiSig).setGlobalPause(true))
                .to.emit(circuitBreaker, "GlobalPauseUpdated")
                .withArgs(true);

            expect(await circuitBreaker.globalPause()).to.equal(true);
        });

        it("Should not allow unauthorized users to set global pause", async function () {
            await expect(
                circuitBreaker.connect(addr1).setGlobalPause(true)
            ).to.be.revertedWith("CircuitBreaker: caller not authorized");
        });

        it("Should not allow owner to set global pause if not governance or emergency multi-sig", async function () {
            await expect(
                circuitBreaker.connect(owner).setGlobalPause(true)
            ).to.be.revertedWith("CircuitBreaker: caller not authorized");
        });

        it("Should allow toggling global pause state", async function () {
            // Enable global pause
            await circuitBreaker.connect(governance).setGlobalPause(true);
            expect(await circuitBreaker.globalPause()).to.equal(true);

            // Disable global pause
            await circuitBreaker.connect(governance).setGlobalPause(false);
            expect(await circuitBreaker.globalPause()).to.equal(false);
        });
    });

    describe("Contract-Specific Pause Management", function () {
        const testContract = "0x1234567890123456789012345678901234567890";

        it("Should allow governance to set contract pause", async function () {
            await expect(circuitBreaker.connect(governance).setContractPause(testContract, true))
                .to.emit(circuitBreaker, "ContractPauseUpdated")
                .withArgs(testContract, true);

            expect(await circuitBreaker.contractPauses(testContract)).to.equal(true);
        });

        it("Should allow emergency multi-sig to set contract pause", async function () {
            await expect(circuitBreaker.connect(emergencyMultiSig).setContractPause(testContract, true))
                .to.emit(circuitBreaker, "ContractPauseUpdated")
                .withArgs(testContract, true);

            expect(await circuitBreaker.contractPauses(testContract)).to.equal(true);
        });

        it("Should not allow unauthorized users to set contract pause", async function () {
            await expect(
                circuitBreaker.connect(addr1).setContractPause(testContract, true)
            ).to.be.revertedWith("CircuitBreaker: caller not authorized");
        });

        it("Should not allow setting pause for zero address contract", async function () {
            await expect(
                circuitBreaker.connect(governance).setContractPause(ethers.constants.AddressZero, true)
            ).to.be.revertedWith("CircuitBreaker: contract is zero address");
        });

        it("Should allow toggling contract pause state", async function () {
            // Enable contract pause
            await circuitBreaker.connect(governance).setContractPause(testContract, true);
            expect(await circuitBreaker.contractPauses(testContract)).to.equal(true);

            // Disable contract pause
            await circuitBreaker.connect(governance).setContractPause(testContract, false);
            expect(await circuitBreaker.contractPauses(testContract)).to.equal(false);
        });
    });

    describe("Contract Pause Status Check", function () {
        const testContract1 = "0x1234567890123456789012345678901234567890";
        const testContract2 = "0x0987654321098765432109876543210987654321";

        it("Should return false for non-paused contract when global pause is disabled", async function () {
            expect(await circuitBreaker.isContractPaused(testContract1)).to.equal(false);
        });

        it("Should return true for specifically paused contract", async function () {
            await circuitBreaker.connect(governance).setContractPause(testContract1, true);
            expect(await circuitBreaker.isContractPaused(testContract1)).to.equal(true);
        });

        it("Should return true for any contract when global pause is enabled", async function () {
            await circuitBreaker.connect(governance).setGlobalPause(true);
            
            expect(await circuitBreaker.isContractPaused(testContract1)).to.equal(true);
            expect(await circuitBreaker.isContractPaused(testContract2)).to.equal(true);
        });

        it("Should return true when both global and contract-specific pause are enabled", async function () {
            await circuitBreaker.connect(governance).setGlobalPause(true);
            await circuitBreaker.connect(governance).setContractPause(testContract1, true);
            
            expect(await circuitBreaker.isContractPaused(testContract1)).to.equal(true);
        });

        it("Should return true when global pause is enabled even if contract-specific pause is disabled", async function () {
            await circuitBreaker.connect(governance).setGlobalPause(true);
            await circuitBreaker.connect(governance).setContractPause(testContract1, false);
            
            expect(await circuitBreaker.isContractPaused(testContract1)).to.equal(true);
        });
    });

    describe("Governance Address Management", function () {
        it("Should allow governance to update governance address", async function () {
            const newGovernance = addr1.address;
            
            await circuitBreaker.connect(governance).setGovernance(newGovernance);
            expect(await circuitBreaker.governance()).to.equal(newGovernance);
        });

        it("Should allow emergency multi-sig to update governance address", async function () {
            const newGovernance = addr1.address;
            
            await circuitBreaker.connect(emergencyMultiSig).setGovernance(newGovernance);
            expect(await circuitBreaker.governance()).to.equal(newGovernance);
        });

        it("Should not allow unauthorized users to update governance address", async function () {
            await expect(
                circuitBreaker.connect(addr1).setGovernance(addr2.address)
            ).to.be.revertedWith("CircuitBreaker: caller not authorized");
        });

        it("Should not allow setting governance to zero address", async function () {
            await expect(
                circuitBreaker.connect(governance).setGovernance(ethers.constants.AddressZero)
            ).to.be.revertedWith("CircuitBreaker: governance is zero address");
        });

        it("Should allow new governance to perform authorized actions", async function () {
            const newGovernance = addr1;
            
            // Update governance
            await circuitBreaker.connect(governance).setGovernance(newGovernance.address);
            
            // New governance should be able to set global pause
            await expect(circuitBreaker.connect(newGovernance).setGlobalPause(true))
                .to.emit(circuitBreaker, "GlobalPauseUpdated")
                .withArgs(true);
        });
    });

    describe("Emergency Multi-Sig Address Management", function () {
        it("Should allow governance to update emergency multi-sig address", async function () {
            const newMultiSig = addr1.address;
            
            await circuitBreaker.connect(governance).setEmergencyMultiSig(newMultiSig);
            expect(await circuitBreaker.emergencyMultiSig()).to.equal(newMultiSig);
        });

        it("Should allow emergency multi-sig to update emergency multi-sig address", async function () {
            const newMultiSig = addr1.address;
            
            await circuitBreaker.connect(emergencyMultiSig).setEmergencyMultiSig(newMultiSig);
            expect(await circuitBreaker.emergencyMultiSig()).to.equal(newMultiSig);
        });

        it("Should not allow unauthorized users to update emergency multi-sig address", async function () {
            await expect(
                circuitBreaker.connect(addr1).setEmergencyMultiSig(addr2.address)
            ).to.be.revertedWith("CircuitBreaker: caller not authorized");
        });

        it("Should not allow setting emergency multi-sig to zero address", async function () {
            await expect(
                circuitBreaker.connect(governance).setEmergencyMultiSig(ethers.constants.AddressZero)
            ).to.be.revertedWith("CircuitBreaker: multi-sig is zero address");
        });

        it("Should allow new emergency multi-sig to perform authorized actions", async function () {
            const newMultiSig = addr1;
            
            // Update emergency multi-sig
            await circuitBreaker.connect(emergencyMultiSig).setEmergencyMultiSig(newMultiSig.address);
            
            // New multi-sig should be able to set global pause
            await expect(circuitBreaker.connect(newMultiSig).setGlobalPause(true))
                .to.emit(circuitBreaker, "GlobalPauseUpdated")
                .withArgs(true);
        });
    });

    describe("Complex Scenarios", function () {
        const testContract1 = "0x1234567890123456789012345678901234567890";
        const testContract2 = "0x0987654321098765432109876543210987654321";

        it("Should handle multiple contract pauses correctly", async function () {
            // Pause contract1
            await circuitBreaker.connect(governance).setContractPause(testContract1, true);
            expect(await circuitBreaker.isContractPaused(testContract1)).to.equal(true);
            expect(await circuitBreaker.isContractPaused(testContract2)).to.equal(false);

            // Pause contract2
            await circuitBreaker.connect(governance).setContractPause(testContract2, true);
            expect(await circuitBreaker.isContractPaused(testContract1)).to.equal(true);
            expect(await circuitBreaker.isContractPaused(testContract2)).to.equal(true);

            // Unpause contract1
            await circuitBreaker.connect(governance).setContractPause(testContract1, false);
            expect(await circuitBreaker.isContractPaused(testContract1)).to.equal(false);
            expect(await circuitBreaker.isContractPaused(testContract2)).to.equal(true);
        });

        it("Should handle emergency scenario with multi-sig override", async function () {
            // Governance pauses a specific contract
            await circuitBreaker.connect(governance).setContractPause(testContract1, true);
            
            // Emergency multi-sig activates global pause
            await circuitBreaker.connect(emergencyMultiSig).setGlobalPause(true);
            
            // Both contracts should be paused
            expect(await circuitBreaker.isContractPaused(testContract1)).to.equal(true);
            expect(await circuitBreaker.isContractPaused(testContract2)).to.equal(true);
            
            // Even if governance tries to unpause the specific contract, global pause overrides
            await circuitBreaker.connect(governance).setContractPause(testContract1, false);
            expect(await circuitBreaker.isContractPaused(testContract1)).to.equal(true);
            
            // Only when global pause is disabled, the specific contract becomes unpaused
            await circuitBreaker.connect(emergencyMultiSig).setGlobalPause(false);
            expect(await circuitBreaker.isContractPaused(testContract1)).to.equal(false);
            expect(await circuitBreaker.isContractPaused(testContract2)).to.equal(false);
        });

        it("Should maintain state after governance transfer", async function () {
            const newGovernance = addr1;
            
            // Set some initial state
            await circuitBreaker.connect(governance).setContractPause(testContract1, true);
            await circuitBreaker.connect(governance).setGlobalPause(true);
            
            // Transfer governance
            await circuitBreaker.connect(governance).setGovernance(newGovernance.address);
            
            // State should be maintained
            expect(await circuitBreaker.isContractPaused(testContract1)).to.equal(true);
            expect(await circuitBreaker.globalPause()).to.equal(true);
            
            // New governance should be able to modify state
            await circuitBreaker.connect(newGovernance).setGlobalPause(false);
            expect(await circuitBreaker.globalPause()).to.equal(false);
        });
    });

    describe("Interface Compliance", function () {
        it("Should implement ICircuitBreaker interface correctly", async function () {
            // Test globalPause view function
            expect(await circuitBreaker.globalPause()).to.be.a('boolean');
            
            // Test isContractPaused view function
            const testContract = "0x1234567890123456789012345678901234567890";
            expect(await circuitBreaker.isContractPaused(testContract)).to.be.a('boolean');
        });
    });
});
