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

    event NativeFunded(uint256 indexed tokenId, address indexed sender, uint256 amount);
    event NativeWithdrawn(uint256 indexed tokenId, address indexed recipient, uint256 amount);

    modifier onlyOperator(uint256 tokenId) {
        require(INFAOwner(nfa).ownerOf(tokenId) == msg.sender, "Not token owner");
        _;
    }

    constructor(address nfa_, address vault_) {
        require(nfa_ != address(0) && vault_ != address(0), "Invalid address");
        nfa = nfa_;
        vault = IAgentVault(vault_);
    }

    function fund(uint256 tokenId) external payable {
        require(msg.value > 0, "Amount must be > 0");
        vault.creditNative{ value: msg.value }(tokenId);
        emit NativeFunded(tokenId, msg.sender, msg.value);
    }

    function withdraw(uint256 tokenId, uint256 amount, address to) external onlyOperator(tokenId) {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be > 0");
        vault.debitNative(tokenId, amount, to);
        emit NativeWithdrawn(tokenId, to, amount);
    }
}
