const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('CLAWNFA / NFA', function () {
  let owner;
  let addr1;
  let addr2;
  let token;
  let nfa;

  const minBalance = ethers.utils.parseUnits('10000', 18);

  async function signMintRequest(contract, signer, wallet, nonce, expiry) {
    const network = await ethers.provider.getNetwork();
    const domain = {
      name: 'Non-Fungible Agent',
      version: '1',
      chainId: network.chainId,
      verifyingContract: contract.address,
    };
    const types = {
      MintRequest: [
        { name: 'wallet', type: 'address' },
        { name: 'nonce', type: 'uint256' },
        { name: 'expiry', type: 'uint256' },
      ],
    };
    const value = { wallet, nonce, expiry };
    return signer._signTypedData(domain, types, value);
  }

  async function mintAs(user) {
    const nonce = await nfa.nonces(user.address);
    const block = await ethers.provider.getBlock('latest');
    const req = {
      wallet: user.address,
      nonce: nonce.toNumber(),
      expiry: block.timestamp + 3600,
    };
    const signature = await signMintRequest(nfa, owner, req.wallet, req.nonce, req.expiry);
    await nfa.connect(user).mint(req, signature);
    return req;
  }

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    const MockERC20 = await ethers.getContractFactory('MockERC20Balance');
    token = await MockERC20.deploy();
    await token.deployed();

    const NFA = await ethers.getContractFactory('NFA');
    nfa = await NFA.deploy(token.address);
    await nfa.deployed();

    await token.setBalance(addr1.address, minBalance);
    await token.setBalance(addr2.address, minBalance);
  });

  it('mints with valid EIP-712 signature and increments nonce', async function () {
    const req = await mintAs(addr1);
    expect(await nfa.ownerOf(0)).to.equal(addr1.address);
    expect(await nfa.getMintedCount(addr1.address)).to.equal(1);
    expect(await nfa.nonces(addr1.address)).to.equal(req.nonce + 1);
  });

  it('rejects invalid signature', async function () {
    const block = await ethers.provider.getBlock('latest');
    const req = {
      wallet: addr1.address,
      nonce: 0,
      expiry: block.timestamp + 3600,
    };
    const badSig = await signMintRequest(nfa, addr2, req.wallet, req.nonce, req.expiry);

    await expect(nfa.connect(addr1).mint(req, badSig)).to.be.revertedWith('NFA: invalid signature');
  });

  it('requires minimum token balance for mint', async function () {
    await token.setBalance(addr2.address, 0);
    const block = await ethers.provider.getBlock('latest');
    const req = {
      wallet: addr2.address,
      nonce: 0,
      expiry: block.timestamp + 3600,
    };
    const sig = await signMintRequest(nfa, owner, req.wallet, req.nonce, req.expiry);

    await expect(nfa.connect(addr2).mint(req, sig)).to.be.revertedWith(
      'NFA: insufficient token balance',
    );
  });

  it('enforces logic allowlist and executes allowed logic', async function () {
    await mintAs(addr1);
    const Logic = await ethers.getContractFactory('MockAgentLogic');
    const logic = await Logic.deploy();
    await logic.deployed();

    await expect(nfa.connect(addr1).setLogicAddress(0, logic.address)).to.be.revertedWith(
      'NFA: logic contract not allowed',
    );

    await nfa.connect(owner).setAllowedLogicContract(logic.address, true);
    await nfa.connect(addr1).setLogicAddress(0, logic.address);

    const calldata = logic.interface.encodeFunctionData('run', [41]);
    await expect(nfa.connect(addr1).executeAction(0, calldata))
      .to.emit(nfa, 'AgentActionExecuted')
      .withArgs(0, ethers.utils.defaultAbiCoder.encode(['uint256'], [42]));
  });

  it('enforces pause and terminate transitions', async function () {
    await mintAs(addr1);
    await nfa.connect(addr1).pause(0);
    let state = await nfa.getState(0);
    expect(state.status).to.equal(1);

    await nfa.connect(addr1).unpause(0);
    state = await nfa.getState(0);
    expect(state.status).to.equal(0);

    await nfa.connect(addr1).terminate(0);
    state = await nfa.getState(0);
    expect(state.status).to.equal(2);

    await expect(nfa.connect(addr1).unpause(0)).to.be.revertedWith('NFA: not paused');
    await expect(
      nfa.connect(addr2).fundAgent(0, { value: ethers.utils.parseEther('1') }),
    ).to.be.revertedWith('NFA: terminated');
  });

  it('applies contract-level pause to mint and fund', async function () {
    await nfa.connect(owner).setPaused(true);

    const block = await ethers.provider.getBlock('latest');
    const req = {
      wallet: addr1.address,
      nonce: 0,
      expiry: block.timestamp + 3600,
    };
    const sig = await signMintRequest(nfa, owner, req.wallet, req.nonce, req.expiry);

    await expect(nfa.connect(addr1).mint(req, sig)).to.be.revertedWith('Contract is paused');

    await nfa.connect(owner).setPaused(false);
    await mintAs(addr1);
    await nfa.connect(owner).setPaused(true);

    await expect(
      nfa.connect(addr1).fundAgent(0, { value: ethers.utils.parseEther('1') }),
    ).to.be.revertedWith('Contract is paused');
  });

  it('prevents burn with non-zero balance and allows burn after withdraw', async function () {
    await mintAs(addr1);
    expect(await nfa.totalSupply()).to.equal(1);
    const amount = ethers.utils.parseEther('1');
    await nfa.connect(addr2).fundAgent(0, { value: amount });

    await expect(nfa.connect(addr1).burn(0)).to.be.revertedWith('NFA: non-zero balance');

    await nfa.connect(addr1).withdrawFromAgent(0, amount);
    await nfa.connect(addr1).burn(0);
    expect(await nfa.totalSupply()).to.equal(0);
    await expect(nfa.ownerOf(0)).to.be.revertedWith('NFA: nonexistent token');
  });

  it('does not allow owner to withdraw agent funds', async function () {
    await mintAs(addr1);
    await nfa.connect(addr2).fundAgent(0, { value: ethers.utils.parseEther('0.5') });

    await expect(nfa.connect(owner).withdraw()).to.be.revertedWith('NFA: nothing to withdraw');
  });
});
