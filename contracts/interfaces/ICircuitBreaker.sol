// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ICircuitBreaker - Interface for CircuitBreaker
 */
interface ICircuitBreaker {
    // The global pause state
    function globalPause() external view returns (bool);

    /**
     * @dev Checks if a contract is paused
     * @param contractAddress The address of the contract
     * @return Whether the contract is paused
     */
    function isContractPaused(address contractAddress) external view returns (bool);
}
