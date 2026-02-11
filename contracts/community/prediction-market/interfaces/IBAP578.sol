// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBAP578 {
    enum AgentState { ACTIVE, PAUSED, TERMINATED }

    struct AgentMetadata {
        string name;
        string persona;
        bytes32 voiceHash;
        string animationURI;
        string vaultURI;
        bytes32 vaultHash;
    }

    event ActionExecuted(uint256 indexed tokenId, bytes result);
    event AgentFunded(uint256 indexed tokenId, uint256 amount);
    event AgentWithdrawn(uint256 indexed tokenId, uint256 amount);
    event AgentPaused(uint256 indexed tokenId);
    event AgentUnpaused(uint256 indexed tokenId);
    event AgentTerminated(uint256 indexed tokenId);
    event MetadataUpdated(uint256 indexed tokenId);
    event LogicAddressUpdated(uint256 indexed tokenId, address newLogic);

    function executeAction(uint256 tokenId, bytes calldata data) external returns (bytes memory);
    function fundAgent(uint256 tokenId) external payable;
    function withdrawFromAgent(uint256 tokenId, uint256 amount) external;
    function pauseAgent(uint256 tokenId) external;
    function unpauseAgent(uint256 tokenId) external;
    function terminateAgent(uint256 tokenId) external;
    function getState(uint256 tokenId) external view returns (AgentState);
    function getAgentMetadata(uint256 tokenId) external view returns (AgentMetadata memory);
    function updateAgentMetadata(uint256 tokenId, AgentMetadata calldata metadata) external;
    function setLogicAddress(uint256 tokenId, address logic) external;
}
