// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface INFAOwner {
    function ownerOf(uint256 tokenId) external view returns (address);
}

interface IAgentVault {
    function creditNative(uint256 tokenId) external payable;
    function debitNative(uint256 tokenId, uint256 amount, address to) external;
}

contract BAP578AdapterBlueprint {
    address public immutable nfa;
    IAgentVault public immutable vault;
    uint256 private _locked;

    event NativeFunded(uint256 indexed tokenId, address indexed sender, uint256 amount);
    event NativeWithdrawn(uint256 indexed tokenId, address indexed recipient, uint256 amount);

    modifier onlyOperator(uint256 tokenId) {
        require(INFAOwner(nfa).ownerOf(tokenId) == msg.sender, "Not token owner");
        _;
    }

    modifier nonReentrant() {
        require(_locked == 0, "ReentrancyGuard");
        _locked = 1;
        _;
        _locked = 0;
    }

    constructor(address nfa_, address vault_) {
        require(nfa_ != address(0) && vault_ != address(0), "Invalid address");
        nfa = nfa_;
        vault = IAgentVault(vault_);
    }

    function fund(uint256 tokenId) external payable nonReentrant {
        require(msg.value > 0, "Amount must be > 0");
        emit NativeFunded(tokenId, msg.sender, msg.value);
        vault.creditNative{ value: msg.value }(tokenId);
    }

    function withdraw(uint256 tokenId, uint256 amount, address to) external onlyOperator(tokenId) nonReentrant {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be > 0");
        emit NativeWithdrawn(tokenId, to, amount);
        vault.debitNative(tokenId, amount, to);
    }
}
