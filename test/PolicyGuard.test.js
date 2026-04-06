const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('PolicyGuard Extension', function () {
    let owner, operator, attacker;
    let policyGuard, spendingLimit;

    beforeEach(async function () {
        [owner, operator, attacker] = await ethers.getSigners();

        // Deploy SpendingLimitExample
        const SpendingLimit = await ethers.getContractFactory('SpendingLimitExample');
        spendingLimit = await SpendingLimit.deploy();
        await spendingLimit.deployed();

        // Deploy PolicyGuardExample
        const PolicyGuard = await ethers.getContractFactory('PolicyGuardExample');
        policyGuard = await PolicyGuard.deploy();
        await policyGuard.deployed();
    });

    // ============================================
    //              IPolicy Interface Tests
    // ============================================

    describe('IPolicy: SpendingLimitExample', function () {
        it('should return correct policyType', async function () {
            const policyType = await spendingLimit.policyType();
            const expected = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes('spending_limit'),
            );
            expect(policyType).to.equal(expected);
        });

        it('should return renterConfigurable as false', async function () {
            expect(await spendingLimit.renterConfigurable()).to.equal(false);
        });

        it('should allow actions within spending limit', async function () {
            const tokenId = 1;
            const limit = ethers.utils.parseEther('0.1'); // 0.1 BNB
            await spendingLimit.setLimit(tokenId, limit);

            const value = ethers.utils.parseEther('0.05'); // 0.05 BNB — under limit
            const [ok, reason] = await spendingLimit.check(
                tokenId,
                operator.address,
                ethers.constants.AddressZero,
                '0x00000000',
                '0x',
                value,
            );

            expect(ok).to.equal(true);
            expect(reason).to.equal('');
        });

        it('should block actions exceeding spending limit', async function () {
            const tokenId = 1;
            const limit = ethers.utils.parseEther('0.1'); // 0.1 BNB
            await spendingLimit.setLimit(tokenId, limit);

            const value = ethers.utils.parseEther('1.0'); // 1.0 BNB — exceeds limit
            const [ok, reason] = await spendingLimit.check(
                tokenId,
                operator.address,
                ethers.constants.AddressZero,
                '0x00000000',
                '0x',
                value,
            );

            expect(ok).to.equal(false);
            expect(reason).to.equal('SpendingLimit: exceeds per-action limit');
        });

        it('should block valued actions when no limit is configured (fail-close)', async function () {
            const tokenId = 99; // No limit configured
            const value = ethers.utils.parseEther('0.01'); // Any value > 0

            const [ok, reason] = await spendingLimit.check(
                tokenId,
                operator.address,
                ethers.constants.AddressZero,
                '0x00000000',
                '0x',
                value,
            );

            expect(ok).to.equal(false);
            expect(reason).to.equal('SpendingLimit: no limit configured');
        });

        it('should allow zero-value actions even without a limit', async function () {
            const tokenId = 99; // No limit configured
            const value = 0;

            const [ok, reason] = await spendingLimit.check(
                tokenId,
                operator.address,
                ethers.constants.AddressZero,
                '0x00000000',
                '0x',
                value,
            );

            expect(ok).to.equal(true);
        });

        it('should only allow owner to set limits', async function () {
            await expect(
                spendingLimit.connect(attacker).setLimit(1, ethers.utils.parseEther('1.0')),
            ).to.be.revertedWith('SpendingLimit: not owner');
        });
    });

    // ============================================
    //            IPolicyGuard Interface Tests
    // ============================================

    describe('IPolicyGuard: PolicyGuardExample', function () {
        describe('Policy Registry', function () {
            it('should register a policy', async function () {
                await policyGuard.registerPolicy(spendingLimit.address);
                expect(await policyGuard.isRegistered(spendingLimit.address)).to.equal(true);

                const policies = await policyGuard.getRegisteredPolicies();
                expect(policies.length).to.equal(1);
                expect(policies[0]).to.equal(spendingLimit.address);
            });

            it('should prevent duplicate registration', async function () {
                await policyGuard.registerPolicy(spendingLimit.address);
                await expect(
                    policyGuard.registerPolicy(spendingLimit.address),
                ).to.be.revertedWith('PolicyGuard: already registered');
            });

            it('should prevent zero-address registration', async function () {
                await expect(
                    policyGuard.registerPolicy(ethers.constants.AddressZero),
                ).to.be.revertedWith('PolicyGuard: zero address');
            });

            it('should remove a policy', async function () {
                await policyGuard.registerPolicy(spendingLimit.address);
                await policyGuard.removePolicy(spendingLimit.address);

                expect(await policyGuard.isRegistered(spendingLimit.address)).to.equal(false);
                const policies = await policyGuard.getRegisteredPolicies();
                expect(policies.length).to.equal(0);
            });

            it('should only allow owner to register/remove policies', async function () {
                await expect(
                    policyGuard.connect(attacker).registerPolicy(spendingLimit.address),
                ).to.be.revertedWith('PolicyGuard: not owner');
            });
        });

        describe('Policy Binding', function () {
            beforeEach(async function () {
                await policyGuard.registerPolicy(spendingLimit.address);
            });

            it('should bind policies to an agent', async function () {
                await policyGuard.bindPolicies(1, [spendingLimit.address]);

                const bound = await policyGuard.getBoundPolicies(1);
                expect(bound.length).to.equal(1);
                expect(bound[0]).to.equal(spendingLimit.address);
            });

            it('should reject binding unregistered policies', async function () {
                await expect(
                    policyGuard.bindPolicies(1, [attacker.address]),
                ).to.be.revertedWith('PolicyGuard: policy not registered');
            });

            it('should only allow owner to bind policies', async function () {
                await expect(
                    policyGuard.connect(attacker).bindPolicies(1, [spendingLimit.address]),
                ).to.be.revertedWith('PolicyGuard: not owner');
            });
        });

        describe('Validation — Fail-Close Logic', function () {
            const tokenId = 1;

            it('should block actions when no policies are bound (fail-close)', async function () {
                // tokenId=99 has no policies bound
                const [ok, reason] = await policyGuard.validate(
                    ethers.constants.AddressZero,
                    99,
                    ethers.constants.AddressZero,
                    operator.address,
                    ethers.constants.AddressZero,
                    0,
                    '0x',
                );

                expect(ok).to.equal(false);
                expect(reason).to.equal('PolicyGuard: no policies bound');
            });

            it('should allow actions that pass all policies', async function () {
                // Setup: register, bind, configure
                await policyGuard.registerPolicy(spendingLimit.address);
                await policyGuard.bindPolicies(tokenId, [spendingLimit.address]);
                await spendingLimit.setLimit(tokenId, ethers.utils.parseEther('1.0'));

                const [ok, reason] = await policyGuard.validate(
                    ethers.constants.AddressZero,
                    tokenId,
                    ethers.constants.AddressZero,
                    operator.address,
                    ethers.constants.AddressZero,
                    ethers.utils.parseEther('0.5'), // Under limit
                    '0x',
                );

                expect(ok).to.equal(true);
                expect(reason).to.equal('');
            });

            it('should block actions that fail any policy', async function () {
                // Setup: register, bind, configure
                await policyGuard.registerPolicy(spendingLimit.address);
                await policyGuard.bindPolicies(tokenId, [spendingLimit.address]);
                await spendingLimit.setLimit(tokenId, ethers.utils.parseEther('0.1'));

                const [ok, reason] = await policyGuard.validate(
                    ethers.constants.AddressZero,
                    tokenId,
                    ethers.constants.AddressZero,
                    operator.address,
                    ethers.constants.AddressZero,
                    ethers.utils.parseEther('5.0'), // Exceeds limit
                    '0x',
                );

                expect(ok).to.equal(false);
                expect(reason).to.equal('SpendingLimit: exceeds per-action limit');
            });
        });

        describe('Commit', function () {
            it('should emit ActionCommitted event', async function () {
                const tokenId = 1;
                const target = operator.address;

                await expect(policyGuard.commit(tokenId, target, 0, '0x'))
                    .to.emit(policyGuard, 'ActionCommitted')
                    .withArgs(tokenId, target);
            });
        });
    });
});
