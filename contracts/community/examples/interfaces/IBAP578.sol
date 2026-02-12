// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IBAP578
 * @dev Minimal interface for reading BAP-578 agent state.
 *      Used by logic contracts to verify agent ownership and status.
 */
interface IBAP578 {
    function ownerOf(uint256 tokenId) external view returns (address);

    function getAgentState(
        uint256 tokenId
    )
        external
        view
        returns (
            uint256 balance,
            bool active,
            address logicAddress,
            uint256 createdAt,
            address owner
        );
}
