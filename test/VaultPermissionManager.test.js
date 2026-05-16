const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');

describe('VaultPermissionManager Extension', function () {
    const VAULT_ID = 'default';
    const TOKEN_ID = 1;

    // PermissionLevel enum: NONE=0, READ=1, WRITE=2, ADMIN=3
    const NONE = 0;
    const READ = 1;
    const WRITE = 2;
    const ADMIN = 3;

    let owner, operator, admin, stranger;
    let bap578Mock, logic, vpm;

    beforeEach(async function () {
        [owner, operator, admin, stranger] = await ethers.getSigners();

        const Mock = await ethers.getContractFactory('MockBAP578ForVPM');
        bap578Mock = await Mock.deploy();
        await bap578Mock.deployed();

        const Logic = await ethers.getContractFactory('MockLogicModule');
        logic = await Logic.deploy();
        await logic.deployed();

        await bap578Mock.mint(TOKEN_ID, owner.address, logic.address);

        const VPM = await ethers.getContractFactory('VaultPermissionManagerReference');
        vpm = await upgrades.deployProxy(VPM, [bap578Mock.address], {
            initializer: 'initialize',
            kind: 'uups',
        });
        await vpm.deployed();
    });

    describe('createVault', function () {
        it('lets the NFT owner create a vault', async function () {
            await expect(vpm.connect(owner).createVault(TOKEN_ID, VAULT_ID, 'session memory'))
                .to.emit(vpm, 'VaultCreated');
            expect(await vpm.vaultExists(TOKEN_ID, VAULT_ID)).to.equal(true);
        });

        it('rejects non-owner creation', async function () {
            await expect(
                vpm.connect(stranger).createVault(TOKEN_ID, VAULT_ID, ''),
            ).to.be.revertedWith('VPM: only NFT owner');
        });

        it('rejects duplicate vault', async function () {
            await vpm.connect(owner).createVault(TOKEN_ID, VAULT_ID, '');
            await expect(
                vpm.connect(owner).createVault(TOKEN_ID, VAULT_ID, ''),
            ).to.be.revertedWith('VPM: vault exists');
        });
    });

    describe('grantPermission', function () {
        beforeEach(async function () {
            await vpm.connect(owner).createVault(TOKEN_ID, VAULT_ID, '');
        });

        it('lets the NFT owner grant WRITE to an operator', async function () {
            await expect(
                vpm.connect(owner).grantPermission(
                    TOKEN_ID, VAULT_ID, operator.address, WRITE, 0, 'trader bot',
                ),
            ).to.emit(vpm, 'PermissionGranted');

            const [ok] = await vpm.checkPermission(TOKEN_ID, VAULT_ID, operator.address, WRITE);
            expect(ok).to.equal(true);
            expect(await vpm.canForward(TOKEN_ID, VAULT_ID, operator.address)).to.equal(true);
        });

        it('lets an ADMIN grant further permissions', async function () {
            await vpm.connect(owner).grantPermission(
                TOKEN_ID, VAULT_ID, admin.address, ADMIN, 0, '',
            );
            await vpm.connect(admin).grantPermission(
                TOKEN_ID, VAULT_ID, operator.address, WRITE, 0, '',
            );
            expect(await vpm.canForward(TOKEN_ID, VAULT_ID, operator.address)).to.equal(true);
        });

        it('rejects a non-owner non-admin grantor', async function () {
            await expect(
                vpm.connect(stranger).grantPermission(
                    TOKEN_ID, VAULT_ID, operator.address, WRITE, 0, '',
                ),
            ).to.be.revertedWith('VPM: not owner or admin');
        });

        it('rejects NONE as a grant level', async function () {
            await expect(
                vpm.connect(owner).grantPermission(
                    TOKEN_ID, VAULT_ID, operator.address, NONE, 0, '',
                ),
            ).to.be.revertedWith('VPM: NONE; use revoke');
        });

        it('rejects an expiry in the past', async function () {
            const past = (await ethers.provider.getBlock('latest')).timestamp - 60;
            await expect(
                vpm.connect(owner).grantPermission(
                    TOKEN_ID, VAULT_ID, operator.address, WRITE, past, '',
                ),
            ).to.be.revertedWith('VPM: expiry in past');
        });
    });

    describe('revokePermission', function () {
        beforeEach(async function () {
            await vpm.connect(owner).createVault(TOKEN_ID, VAULT_ID, '');
            await vpm.connect(owner).grantPermission(
                TOKEN_ID, VAULT_ID, operator.address, WRITE, 0, '',
            );
        });

        it('lets the NFT owner revoke', async function () {
            await expect(
                vpm.connect(owner).revokePermission(TOKEN_ID, VAULT_ID, operator.address),
            ).to.emit(vpm, 'PermissionRevoked');
            expect(await vpm.canForward(TOKEN_ID, VAULT_ID, operator.address)).to.equal(false);
        });

        it('rejects revoking a grant that does not exist', async function () {
            await expect(
                vpm.connect(owner).revokePermission(TOKEN_ID, VAULT_ID, stranger.address),
            ).to.be.revertedWith('VPM: no such grant');
        });
    });

    describe('forwardHandleAction', function () {
        beforeEach(async function () {
            await vpm.connect(owner).createVault(TOKEN_ID, VAULT_ID, '');
        });

        it('forwards to the bound logic when caller has WRITE', async function () {
            await vpm.connect(owner).grantPermission(
                TOKEN_ID, VAULT_ID, operator.address, WRITE, 0, '',
            );
            const data = ethers.utils.defaultAbiCoder.encode(['uint256'], [42]);
            await expect(
                vpm.connect(operator).forwardHandleAction(TOKEN_ID, VAULT_ID, 'buy_token', data),
            ).to.emit(vpm, 'ActionForwarded');

            expect(await logic.lastTokenId()).to.equal(TOKEN_ID);
            expect(await logic.lastAction()).to.equal('buy_token');
            expect(await logic.lastCaller()).to.equal(vpm.address);
        });

        it('reverts when caller has no grant', async function () {
            await expect(
                vpm.connect(stranger).forwardHandleAction(TOKEN_ID, VAULT_ID, 'buy_token', '0x'),
            ).to.be.revertedWith('VPM: caller lacks WRITE');
        });

        it('reverts when caller has only READ', async function () {
            await vpm.connect(owner).grantPermission(
                TOKEN_ID, VAULT_ID, operator.address, READ, 0, '',
            );
            await expect(
                vpm.connect(operator).forwardHandleAction(TOKEN_ID, VAULT_ID, 'buy_token', '0x'),
            ).to.be.revertedWith('VPM: caller lacks WRITE');
        });

        it('reverts when the grant has expired', async function () {
            const expiry = (await ethers.provider.getBlock('latest')).timestamp + 30;
            await vpm.connect(owner).grantPermission(
                TOKEN_ID, VAULT_ID, operator.address, WRITE, expiry, '',
            );
            await ethers.provider.send('evm_increaseTime', [60]);
            await ethers.provider.send('evm_mine');
            await expect(
                vpm.connect(operator).forwardHandleAction(TOKEN_ID, VAULT_ID, 'buy_token', '0x'),
            ).to.be.revertedWith('VPM: caller lacks WRITE');
        });

        it('reverts when no logic is bound', async function () {
            await bap578Mock.setLogic(TOKEN_ID, ethers.constants.AddressZero);
            await vpm.connect(owner).grantPermission(
                TOKEN_ID, VAULT_ID, operator.address, WRITE, 0, '',
            );
            await expect(
                vpm.connect(operator).forwardHandleAction(TOKEN_ID, VAULT_ID, 'buy_token', '0x'),
            ).to.be.revertedWith('VPM: no logic bound');
        });

        it('bubbles up the logic module revert reason', async function () {
            await vpm.connect(owner).grantPermission(
                TOKEN_ID, VAULT_ID, operator.address, WRITE, 0, '',
            );
            await logic.setRevertNext(true, 'logic: insufficient balance');
            await expect(
                vpm.connect(operator).forwardHandleAction(TOKEN_ID, VAULT_ID, 'buy_token', '0x'),
            ).to.be.revertedWith('logic: insufficient balance');
        });
    });

    describe('isolation between grants', function () {
        beforeEach(async function () {
            await vpm.connect(owner).createVault(TOKEN_ID, VAULT_ID, '');
        });

        it('keeps two grantees independent on the same vault', async function () {
            await vpm.connect(owner).grantPermission(
                TOKEN_ID, VAULT_ID, operator.address, WRITE, 0, '',
            );
            await vpm.connect(owner).grantPermission(
                TOKEN_ID, VAULT_ID, admin.address, READ, 0, '',
            );
            expect(await vpm.canForward(TOKEN_ID, VAULT_ID, operator.address)).to.equal(true);
            expect(await vpm.canForward(TOKEN_ID, VAULT_ID, admin.address)).to.equal(false);

            await vpm.connect(owner).revokePermission(TOKEN_ID, VAULT_ID, operator.address);
            // Revoking operator should not touch admin's grant.
            const [adminOk] = await vpm.checkPermission(TOKEN_ID, VAULT_ID, admin.address, READ);
            expect(adminOk).to.equal(true);
        });

        it('isolates grants across vaults on the same token', async function () {
            const OTHER = 'social';
            await vpm.connect(owner).createVault(TOKEN_ID, OTHER, '');
            await vpm.connect(owner).grantPermission(
                TOKEN_ID, VAULT_ID, operator.address, WRITE, 0, '',
            );
            expect(await vpm.canForward(TOKEN_ID, VAULT_ID, operator.address)).to.equal(true);
            expect(await vpm.canForward(TOKEN_ID, OTHER, operator.address)).to.equal(false);
        });

        it('isolates grants across tokens', async function () {
            await bap578Mock.mint(2, owner.address, logic.address);
            await vpm.connect(owner).createVault(2, VAULT_ID, '');
            await vpm.connect(owner).grantPermission(
                TOKEN_ID, VAULT_ID, operator.address, WRITE, 0, '',
            );
            expect(await vpm.canForward(TOKEN_ID, VAULT_ID, operator.address)).to.equal(true);
            expect(await vpm.canForward(2, VAULT_ID, operator.address)).to.equal(false);
        });
    });

    describe('re-grant semantics', function () {
        beforeEach(async function () {
            await vpm.connect(owner).createVault(TOKEN_ID, VAULT_ID, '');
            await vpm.connect(owner).grantPermission(
                TOKEN_ID, VAULT_ID, operator.address, READ, 0, '',
            );
        });

        it('overwrites an existing grant with a new tier', async function () {
            // Bump from READ to ADMIN by re-granting.
            await vpm.connect(owner).grantPermission(
                TOKEN_ID, VAULT_ID, operator.address, ADMIN, 0, '',
            );
            const [ok] = await vpm.checkPermission(TOKEN_ID, VAULT_ID, operator.address, ADMIN);
            expect(ok).to.equal(true);
        });

        it('re-grants cleanly after the NFT changed hands', async function () {
            await bap578Mock.transfer(TOKEN_ID, stranger.address);
            // Old (auto-revoked) READ grant is replaced by a fresh WRITE under the new owner.
            await vpm.connect(stranger).grantPermission(
                TOKEN_ID, VAULT_ID, operator.address, WRITE, 0, '',
            );
            expect(await vpm.canForward(TOKEN_ID, VAULT_ID, operator.address)).to.equal(true);
        });
    });

    describe('input validation', function () {
        beforeEach(async function () {
            await vpm.connect(owner).createVault(TOKEN_ID, VAULT_ID, '');
        });

        it('rejects zero-address grantee', async function () {
            await expect(
                vpm.connect(owner).grantPermission(
                    TOKEN_ID, VAULT_ID, ethers.constants.AddressZero, WRITE, 0, '',
                ),
            ).to.be.revertedWith('VPM: grantee zero');
        });

        it('rejects grants on a non-existent vault', async function () {
            await expect(
                vpm.connect(owner).grantPermission(
                    TOKEN_ID, 'ghost', operator.address, WRITE, 0, '',
                ),
            ).to.be.revertedWith('VPM: no such vault');
        });

        it('rejects forwards on a non-existent vault', async function () {
            await expect(
                vpm.connect(operator).forwardHandleAction(TOKEN_ID, 'ghost', 'buy_token', '0x'),
            ).to.be.revertedWith('VPM: no such vault');
        });
    });

    describe('initialization + upgrade auth', function () {
        it('rejects a second initialize', async function () {
            await expect(vpm.initialize(bap578Mock.address)).to.be.reverted;
        });

        it('only the owner can authorize an upgrade', async function () {
            const VPM = await ethers.getContractFactory('VaultPermissionManagerReference');
            // Stranger attempting upgrade should revert.
            const newImpl = await VPM.deploy();
            await newImpl.deployed();
            // The OwnableUpgradeable owner is the deployer of the proxy (this test runner).
            // We simulate a non-owner upgrade attempt via the raw upgradeTo selector.
            const ifaceFragment = ['function upgradeTo(address)'];
            const proxyAsUUPS = new ethers.Contract(vpm.address, ifaceFragment, stranger);
            await expect(proxyAsUUPS.upgradeTo(newImpl.address)).to.be.reverted;
        });
    });

    describe('forwardHandleAction return value', function () {
        it('returns whatever bytes the logic module returns', async function () {
            await vpm.connect(owner).createVault(TOKEN_ID, VAULT_ID, '');
            await vpm.connect(owner).grantPermission(
                TOKEN_ID, VAULT_ID, operator.address, WRITE, 0, '',
            );
            // Static-call to read the return value (mock returns abi.encode(true)).
            const result = await vpm.connect(operator).callStatic.forwardHandleAction(
                TOKEN_ID, VAULT_ID, 'check_balance', '0x',
            );
            const [decoded] = ethers.utils.defaultAbiCoder.decode(['bool'], result);
            expect(decoded).to.equal(true);
        });
    });

    describe('auto-revoke on NFT transfer', function () {
        beforeEach(async function () {
            await vpm.connect(owner).createVault(TOKEN_ID, VAULT_ID, '');
            await vpm.connect(owner).grantPermission(
                TOKEN_ID, VAULT_ID, operator.address, WRITE, 0, '',
            );
        });

        it('invalidates the grant the moment the NFT changes hands', async function () {
            expect(await vpm.canForward(TOKEN_ID, VAULT_ID, operator.address)).to.equal(true);
            await bap578Mock.transfer(TOKEN_ID, stranger.address);
            expect(await vpm.canForward(TOKEN_ID, VAULT_ID, operator.address)).to.equal(false);

            const [ok] = await vpm.checkPermission(TOKEN_ID, VAULT_ID, operator.address, WRITE);
            expect(ok).to.equal(false);

            await expect(
                vpm.connect(operator).forwardHandleAction(TOKEN_ID, VAULT_ID, 'buy_token', '0x'),
            ).to.be.revertedWith('VPM: caller lacks WRITE');
        });

        it('lets the new owner issue their own grants on the existing vault', async function () {
            await bap578Mock.transfer(TOKEN_ID, stranger.address);
            // Old grant is invalid; new owner grants a fresh one.
            await vpm.connect(stranger).grantPermission(
                TOKEN_ID, VAULT_ID, admin.address, WRITE, 0, 'new owner bot',
            );
            expect(await vpm.canForward(TOKEN_ID, VAULT_ID, admin.address)).to.equal(true);
            // Old operator stays revoked.
            expect(await vpm.canForward(TOKEN_ID, VAULT_ID, operator.address)).to.equal(false);
        });

        // Documented edge case: if the NFT returns to the original owner and no
        // explicit revoke happened, the stale grant reactivates because its
        // ownerAtGrant field matches the current owner again. Owners who want
        // belt-and-braces protection should revoke explicitly before re-acquiring.
        it('reactivates a stale grant if the NFT returns to the original granter', async function () {
            await bap578Mock.transfer(TOKEN_ID, stranger.address);
            expect(await vpm.canForward(TOKEN_ID, VAULT_ID, operator.address)).to.equal(false);
            await bap578Mock.transfer(TOKEN_ID, owner.address);
            expect(await vpm.canForward(TOKEN_ID, VAULT_ID, operator.address)).to.equal(true);
        });
    });
});
