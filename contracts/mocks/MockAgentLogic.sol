// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockAgentLogic {
    function run(uint256 value) external pure returns (uint256) {
        return value + 1;
    }

    function fail() external pure {
        revert("MockLogic: fail");
    }
}
