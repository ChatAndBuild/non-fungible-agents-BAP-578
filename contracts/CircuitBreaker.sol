// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/ICircuitBreaker.sol";

/**
 * @title CircuitBreaker
 * @dev Emergency shutdown mechanism for the BAP-578 ecosystem
 */
contract CircuitBreaker is ICircuitBreaker, Initializable, OwnableUpgradeable {
    // The address of the governance contract
    address public governance;

    // The address of the emergency multi-sig wallet
    address public emergencyMultiSig;

    // The global pause state
    bool public globalPause;

    // Mapping of contract addresses to their pause state
    mapping(address => bool) public contractPauses;

    // Event emitted when the global pause state is updated
    event GlobalPauseUpdated(bool paused);

    // Event emitted when a contract's pause state is updated
    event ContractPauseUpdated(address indexed contractAddress, bool paused);

    /**
     * @dev Initializes the contract
     * @param _governance The address of the governance contract
     * @param _emergencyMultiSig The address of the emergency multi-sig wallet
     */
    function initialize(address _governance, address _emergencyMultiSig) public initializer {
        __Ownable_init();

        require(_governance != address(0), "CircuitBreaker: governance is zero address");
        require(_emergencyMultiSig != address(0), "CircuitBreaker: multi-sig is zero address");

        governance = _governance;
        emergencyMultiSig = _emergencyMultiSig;
        globalPause = false;
    }

    /**
     * @dev Modifier to check if the caller is the governance contract or the emergency multi-sig
     */
    modifier onlyAuthorized() {
        require(
            msg.sender == governance || msg.sender == emergencyMultiSig,
            "CircuitBreaker: caller not authorized"
        );
        _;
    }

    /**
     * @dev Sets the global pause state
     * @param paused The new pause state
     */
    function setGlobalPause(bool paused) external onlyAuthorized {
        globalPause = paused;
        emit GlobalPauseUpdated(paused);
    }

    /**
     * @dev Sets the pause state for a specific contract
     * @param contractAddress The address of the contract
     * @param paused The new pause state
     */
    function setContractPause(address contractAddress, bool paused) external onlyAuthorized {
        require(contractAddress != address(0), "CircuitBreaker: contract is zero address");

        contractPauses[contractAddress] = paused;
        emit ContractPauseUpdated(contractAddress, paused);
    }

    /**
     * @dev Checks if a contract is paused
     * @param contractAddress The address of the contract
     * @return Whether the contract is paused
     */
    function isContractPaused(address contractAddress) external view returns (bool) {
        return globalPause || contractPauses[contractAddress];
    }

    /**
     * @dev Updates the governance address
     * @param _governance The address of the new governance contract
     */
    function setGovernance(address _governance) external onlyAuthorized {
        require(_governance != address(0), "CircuitBreaker: governance is zero address");
        governance = _governance;
    }

    /**
     * @dev Updates the emergency multi-sig address
     * @param _emergencyMultiSig The address of the new emergency multi-sig wallet
     */
    function setEmergencyMultiSig(address _emergencyMultiSig) external onlyAuthorized {
        require(_emergencyMultiSig != address(0), "CircuitBreaker: multi-sig is zero address");
        emergencyMultiSig = _emergencyMultiSig;
    }
}
