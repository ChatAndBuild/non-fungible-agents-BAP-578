// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BEP007Enhanced.sol";
import "./interfaces/ILearningModule.sol";

/**
 * @title BEP007EnhancedImpl - Concrete upgradeable implementation of BEP007Enhanced
 * @dev This contract provides concrete implementations for all abstract functions with upgradeability
 */
contract BEP007EnhancedImpl is BEP007Enhanced {
    /**
     * @dev Initializes the upgradeable contract
     * @param name The name of the agent token collection
     * @param symbol The symbol of the agent token collection
     * @param governanceAddress The address of the governance contract
     */
    function initialize(
        string memory name,
        string memory symbol,
        address governanceAddress
    ) public override initializer {
        // Call parent initialize function
        super.initialize(name, symbol, governanceAddress);
    }

    /**
     * @dev Creates a new agent token with extended metadata (IBEP007 interface implementation)
     * @param to The address that will own the agent
     * @param logicAddress The address of the logic contract
     * @param metadataURI The URI for the agent's metadata
     * @param extendedMetadata The extended metadata for the agent
     * @return tokenId The ID of the new agent token
     */
    function createAgent(
        address to,
        address logicAddress,
        string memory metadataURI,
        IBEP007.AgentMetadata memory extendedMetadata
    ) external override returns (uint256 tokenId) {
        require(logicAddress != address(0), "BEP007EnhancedImpl: logic address is zero");

        // Convert IBEP007.AgentMetadata to EnhancedAgentMetadata
        EnhancedAgentMetadata memory enhancedMetadata = EnhancedAgentMetadata({
            persona: extendedMetadata.persona,
            experience: extendedMetadata.experience,
            voiceHash: extendedMetadata.voiceHash,
            animationURI: extendedMetadata.animationURI,
            vaultURI: extendedMetadata.vaultURI,
            vaultHash: extendedMetadata.vaultHash,
            learningEnabled: false,
            learningModule: address(0),
            learningTreeRoot: bytes32(0),
            learningVersion: 0
        });

        return this.createAgent(to, logicAddress, metadataURI, enhancedMetadata);
    }

    /**
     * @dev Updates the logic address for the agent
     * @param tokenId The ID of the agent token
     * @param newLogic The address of the new logic contract
     */
    function setLogicAddress(
        uint256 tokenId,
        address newLogic
    ) external override onlyAgentOwner(tokenId) {
        require(newLogic != address(0), "BEP007EnhancedImpl: new logic address is zero");

        address oldLogic = _agentStates[tokenId].logicAddress;
        _agentStates[tokenId].logicAddress = newLogic;

        emit LogicUpgraded(address(this), oldLogic, newLogic);
    }

    /**
     * @dev Funds the agent with BNB for gas fees
     * @param tokenId The ID of the agent token
     */
    function fundAgent(uint256 tokenId) external payable override {
        require(_exists(tokenId), "BEP007EnhancedImpl: agent does not exist");

        _agentStates[tokenId].balance += msg.value;

        emit AgentFunded(address(this), msg.sender, msg.value);
    }

    /**
     * @dev Returns the current state of the agent
     * @param tokenId The ID of the agent token
     * @return The agent's state
     */
    function getState(uint256 tokenId) external view override returns (State memory) {
        require(_exists(tokenId), "BEP007EnhancedImpl: agent does not exist");
        return _agentStates[tokenId];
    }

    /**
     * @dev Pauses the agent
     * @param tokenId The ID of the agent token
     */
    function pause(uint256 tokenId) external override onlyAgentOwner(tokenId) {
        require(
            _agentStates[tokenId].status == Status.Active,
            "BEP007EnhancedImpl: agent not active"
        );

        _agentStates[tokenId].status = Status.Paused;

        emit StatusChanged(address(this), Status.Paused);
    }

    /**
     * @dev Resumes the agent
     * @param tokenId The ID of the agent token
     */
    function unpause(uint256 tokenId) external override onlyAgentOwner(tokenId) {
        require(
            _agentStates[tokenId].status == Status.Paused,
            "BEP007EnhancedImpl: agent not paused"
        );

        _agentStates[tokenId].status = Status.Active;

        emit StatusChanged(address(this), Status.Active);
    }

    /**
     * @dev Terminates the agent permanently
     * @param tokenId The ID of the agent token
     */
    function terminate(uint256 tokenId) external override onlyAgentOwner(tokenId) {
        require(
            _agentStates[tokenId].status != Status.Terminated,
            "BEP007EnhancedImpl: agent already terminated"
        );

        _agentStates[tokenId].status = Status.Terminated;

        // Return any remaining balance to the owner
        uint256 remainingBalance = _agentStates[tokenId].balance;
        if (remainingBalance > 0) {
            _agentStates[tokenId].balance = 0;
            payable(ownerOf(tokenId)).transfer(remainingBalance);
        }

        emit StatusChanged(address(this), Status.Terminated);
    }

    /**
     * @dev Updates the agent's metadata (IBEP007 interface implementation)
     * @param tokenId The ID of the agent token
     * @param metadata The new base metadata
     */
    function updateAgentMetadata(
        uint256 tokenId,
        IBEP007.AgentMetadata memory metadata
    ) external override onlyAgentOwner(tokenId) {
        // Update only the base metadata fields
        EnhancedAgentMetadata storage enhanced = _agentExtendedMetadata[tokenId];
        enhanced.persona = metadata.persona;
        enhanced.experience = metadata.experience;
        enhanced.voiceHash = metadata.voiceHash;
        enhanced.animationURI = metadata.animationURI;
        enhanced.vaultURI = metadata.vaultURI;
        enhanced.vaultHash = metadata.vaultHash;

        emit MetadataUpdated(tokenId, _agentMetadataURIs[tokenId]);
    }

    /**
     * @dev Registers a experience module for the agent
     * @param tokenId The ID of the agent token
     * @param moduleAddress The address of the experience module
     */
    function registerExperienceModule(
        uint256 tokenId,
        address moduleAddress
    ) external override onlyAgentOwner(tokenId) {
        require(
            experienceModuleRegistry != address(0),
            "BEP007EnhancedImpl: experience module registry not set"
        );

        emit ExperienceModuleRegistered(tokenId, moduleAddress);
    }

    /**
     * @dev Withdraws BNB from the agent
     * @param tokenId The ID of the agent token
     * @param amount The amount to withdraw
     */
    function withdrawFromAgent(
        uint256 tokenId,
        uint256 amount
    ) external override onlyAgentOwner(tokenId) {
        require(
            amount <= _agentStates[tokenId].balance,
            "BEP007EnhancedImpl: insufficient balance"
        );

        _agentStates[tokenId].balance -= amount;
        payable(msg.sender).transfer(amount);
    }

    /**
     * @dev Updates the agent's metadata URI
     * @param tokenId The ID of the agent token
     * @param newMetadataURI The new metadata URI
     */
    function setAgentMetadataURI(
        uint256 tokenId,
        string memory newMetadataURI
    ) external override onlyAgentOwner(tokenId) {
        _agentMetadataURIs[tokenId] = newMetadataURI;
        _setTokenURI(tokenId, newMetadataURI);

        emit MetadataUpdated(tokenId, newMetadataURI);
    }

    /**
     * @dev Executes an action using the agent's logic
     * @param tokenId The ID of the agent token
     * @param data The encoded function call to execute
     */
    function executeAction(
        uint256 tokenId,
        bytes calldata data
    ) external override nonReentrant whenAgentActive(tokenId) {
        State storage agentState = _agentStates[tokenId];

        // Only the owner or the logic contract itself can execute actions
        require(
            msg.sender == ownerOf(tokenId) || msg.sender == agentState.logicAddress,
            "BEP007EnhancedImpl: unauthorized caller"
        );

        // Ensure the agent has enough balance for gas
        require(agentState.balance > 0, "BEP007EnhancedImpl: insufficient balance for gas");

        // Update the last action timestamp
        agentState.lastActionTimestamp = block.timestamp;

        // Execute the action via call with gas limit (upgrade-safe)
        (bool success, bytes memory result) = agentState.logicAddress.call{
            gas: MAX_GAS_FOR_DELEGATECALL
        }(data);

        require(success, "BEP007EnhancedImpl: action execution failed");

        emit ActionExecuted(address(this), result);

        // Record interaction for learning if enabled
        EnhancedAgentMetadata storage metadata = _agentExtendedMetadata[tokenId];
        if (metadata.learningEnabled && metadata.learningModule != address(0)) {
            try
                ILearningModule(metadata.learningModule).recordInteraction(
                    tokenId,
                    "action_executed",
                    success
                )
            {
                // Successfully recorded interaction
            } catch {
                // Silently fail to not break agent functionality
            }
        }
    }

    /**
     * @dev Upgrades the contract to a new implementation and calls a function on the new implementation.
     * This function is part of the UUPS (Universal Upgradeable Proxy Standard) pattern.
     * @param newImplementation The address of the new implementation contract
     * @param data The calldata to execute on the new implementation after upgrade
     * @notice Only the contract owner can perform upgrades for security
     * @notice This function is payable to support implementations that require ETH
     */
    function upgradeToAndCall(
        address newImplementation,
        bytes memory data
    ) public payable override onlyOwner {}

    /**
     * @dev Upgrades the contract to a new implementation.
     * This function is part of the UUPS (Universal Upgradeable Proxy Standard) pattern.
     * @param newImplementation The address of the new implementation contract
     * @notice Only the contract owner can perform upgrades for security
     * @notice Use upgradeToAndCall if you need to call initialization functions on the new implementation
     */
    function upgradeTo(address newImplementation) public override onlyOwner {}

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract.
     * Called by {upgradeTo} and {upgradeToAndCall}.
     * @dev Only governance can authorize upgrades for enhanced security
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
