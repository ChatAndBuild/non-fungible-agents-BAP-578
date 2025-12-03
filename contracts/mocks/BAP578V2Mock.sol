// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../BAP578.sol";

/**
 * @title BAP578V2Mock
 * @dev Mock V2 contract for testing UUPS upgrades
 */
contract BAP578V2Mock is BAP578 {
    // New state variable to verify upgrade worked
    uint256 public newV2Variable;

    // New function only available in V2
    function setNewV2Variable(uint256 value) external onlyOwner {
        newV2Variable = value;
    }

    // Function to verify this is V2
    function version() external pure returns (string memory) {
        return "v2";
    }
}
