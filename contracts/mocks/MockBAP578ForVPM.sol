// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @notice Minimal mock of the BAP578 surface that VaultPermissionManagerReference reads.
///         Used only by VaultPermissionManager.test.js. Not for production.
contract MockBAP578ForVPM {
    mapping(uint256 => address) public ownerOf;

    struct AgentState {
        uint256 balance;
        bool active;
        address logicAddress;
        uint256 createdAt;
    }

    mapping(uint256 => AgentState) public agentStates;

    function mint(uint256 tokenId, address to, address logicAddress) external {
        ownerOf[tokenId] = to;
        agentStates[tokenId] = AgentState({
            balance: 0,
            active: true,
            logicAddress: logicAddress,
            createdAt: block.timestamp
        });
    }

    function setLogic(uint256 tokenId, address logicAddress) external {
        agentStates[tokenId].logicAddress = logicAddress;
    }

    function transfer(uint256 tokenId, address to) external {
        ownerOf[tokenId] = to;
    }
}
