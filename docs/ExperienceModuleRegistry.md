# Experience Module Registry

## Overview

The Experience Module Registry is a critical component of the BAP-578 Non-Fungible Agent (NFA) ecosystem that allows agents to register and manage external experience sources. This registry provides a secure and flexible way to extend an agent's capabilities through learning modules without modifying the core contracts.

## Purpose

The primary purpose of the ExperienceModuleRegistry is to:

1. Allow agent owners to register approved external experience modules with cryptographic verification
2. Manage different types of experience modules (Static, Adaptive, Learning, Federated)
3. Enforce security levels for modules (Experimental, Community, Professional, Enterprise)
4. Track module usage across all agents
5. Enable agents to configure their learning preferences
6. Provide a global registry of all available modules

## Contract Architecture

The ExperienceModuleRegistry is implemented as an upgradeable contract using UUPS pattern:

```solidity
contract ExperienceModuleRegistry is 
    Initializable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable 
{
    // Core state variables (automatically initialized in Solidity)
    IBAP578 public bap578Token;
    mapping(uint256 => address[]) private _registeredModules;
    mapping(uint256 => mapping(address => bool)) private _approvedModules;
    mapping(uint256 => mapping(address => string)) private _moduleMetadata;
    mapping(address => ExperienceModule) private _moduleRegistry;
    mapping(uint256 => AgentExperienceConfig) private _agentConfigs;
    mapping(address => uint256) private _moduleUsageCount;
    address[] private _allModules;
    mapping(address => uint256) private _moduleIndex;
}
```

## Key Data Structures

### ExperienceModule
```solidity
struct ExperienceModule {
    address moduleAddress;
    bytes32 moduleHash;
    string specification;
    ExperienceType experienceType;
    SecurityLevel securityLevel;
    bool active;
    uint256 registrationTime;
    address creator;
    uint256 version;
}
```

### Experience Types
```solidity
enum ExperienceType {
    STATIC,     // Traditional static experience (no learning)
    ADAPTIVE,   // Basic adaptive experience (simple learning)
    LEARNING,   // Full learning capabilities (advanced AI)
    FEDERATED   // Cross-agent learning support (collaborative)
}
```

### Security Levels
```solidity
enum SecurityLevel {
    EXPERIMENTAL,  // For development and testing
    COMMUNITY,     // Community-validated modules
    PROFESSIONAL,  // Professionally audited
    ENTERPRISE     // Enterprise-grade security
}
```

### Agent Experience Configuration
```solidity
struct AgentExperienceConfig {
    bool learningEnabled;
    ExperienceType preferredType;
    uint256 maxModules;
    uint256 lastUpdate;
}
```

## Core Functions

### Module Registration
- `registerModule(tokenId, moduleAddress, moduleHash, specification, experienceType, securityLevel, metadata, signature)`: Register a new module with cryptographic verification
- Module is added to global registry if new
- Module is added to agent's registry
- Usage count is tracked

### Module Management
- `setModuleApproval(tokenId, moduleAddress, approved)`: Approve/revoke module for an agent
- `updateModuleMetadata(tokenId, moduleAddress, metadata)`: Update module metadata
- `deactivateModule(moduleAddress, reason)`: Deactivate a module (creator or owner only)

### Agent Configuration
- `updateAgentExperienceConfig(tokenId, learningEnabled, preferredType, maxModules)`: Configure agent's learning preferences

### Query Functions
- `getRegisteredModules(tokenId)`: Get all modules registered for an agent
- `getApprovedModules(tokenId)`: Get only approved modules for an agent
- `getModuleInfo(moduleAddress)`: Get full module information
- `getAgentExperienceConfig(tokenId)`: Get agent's experience configuration
- `getModulesByType(experienceType)`: Get modules filtered by type
- `getModulesBySecurityLevel(securityLevel)`: Get modules filtered by security level
- `getAllModules()`: Get all registered modules globally
- `getModuleUsageCount(moduleAddress)`: Get usage count across all agents

## Cryptographic Verification

The registry uses ECDSA signatures to verify module registrations:

```solidity
bytes32 messageHash = keccak256(abi.encodePacked(
    tokenId,
    moduleAddress,
    moduleHash,
    specification,
    uint256(experienceType),
    uint256(securityLevel),
    metadata
));
bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
address signer = ethSignedMessageHash.recover(signature);
```

## Experience Module Specification Schema

Modules must provide a JSON specification with required fields:

```json
{
  "context_id": "nfa007-experience-001",
  "owner": "0xUserWalletAddress",
  "created": "2025-01-20T10:00:00Z",
  "persona": "Strategic crypto analyst with learning capabilities",
  "learning_enabled": true,
  "learning_type": "adaptive_experience",
  "experience_slots": [
    {
      "type": "alert_keywords",
      "data": ["FUD", "rugpull", "hack", "$BNB", "scam"],
      "learning_weight": 0.8,
      "adaptation_rate": 0.1
    },
    {
      "type": "behavior_rules",
      "data": [
        "If sentiment drops >10% in 24h, alert user",
        "Learn from user feedback on alerts"
      ]
    }
  ],
  "last_updated": "2025-01-20T11:00:00Z"
}
```

## Usage Examples

### Registering an Experience Module

```javascript
// Prepare module data
const moduleHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('module-code-hash'));
const specification = JSON.stringify({
    context_id: "nfa007-experience-001",
    persona: "Strategic crypto analyst",
    experience_slots: [...]
});

// Create signature
const messageHash = ethers.utils.solidityKeccak256(
    ['uint256', 'address', 'bytes32', 'string', 'uint256', 'uint256', 'string'],
    [tokenId, moduleAddress, moduleHash, specification, 2, 1, metadata] // LEARNING, COMMUNITY
);
const signature = await wallet.signMessage(ethers.utils.arrayify(messageHash));

// Register module
await experienceRegistry.registerModule(
    tokenId,
    moduleAddress,
    moduleHash,
    specification,
    2, // LEARNING
    1, // COMMUNITY
    metadata,
    signature
);
```

### Configuring Agent Experience

```javascript
await experienceRegistry.updateAgentExperienceConfig(
    tokenId,
    true,  // learningEnabled
    2,     // LEARNING preferredType
    5      // maxModules
);
```

### Querying Modules by Type

```javascript
// Get all learning modules
const learningModules = await experienceRegistry.getModulesByType(2); // LEARNING

// Get enterprise-grade modules
const enterpriseModules = await experienceRegistry.getModulesBySecurityLevel(3); // ENTERPRISE
```

## Security Considerations

### Access Control
- Only token owners can register modules for their agents
- Only token owners can approve/revoke modules
- Only module creators or contract owner can deactivate modules

### Signature Verification
- All module registrations require cryptographic proof from the token owner
- Prevents unauthorized module registration

### Reentrancy Protection
- Uses OpenZeppelin's ReentrancyGuard for all state-changing operations

### Upgradeable Pattern
- Implements UUPS pattern for future upgrades
- Only owner can authorize upgrades

### State Initialization
- All mappings and arrays are automatically initialized by Solidity
- No explicit initialization needed (Slither false positive suppressed)
- Safe for upgradeable contracts

## Events

- `ModuleRegistered`: Emitted when a new module is registered
- `ModuleApproved`: Emitted when module approval status changes
- `ModuleMetadataUpdated`: Emitted when module metadata is updated
- `AgentExperienceConfigUpdated`: Emitted when agent config is updated
- `ModuleDeactivated`: Emitted when a module is deactivated
- `ModuleUsageUpdated`: Emitted when module usage count changes
- `ContractInitialized`: Emitted when contract is initialized

## Integration with BAP-578 Ecosystem

1. **Agent Creation**: Agents can register experience modules upon creation
2. **Learning Modules**: Integrates with MerkleTreeLearning for advanced AI capabilities
3. **Agent Factory**: Factory can set default modules for new agents
4. **Governance**: Community can vote on module security levels
5. **Circuit Breaker**: Emergency pause capability for security

## Best Practices

1. **Module Validation**: Always validate module specifications before registration
2. **Security Levels**: Start with EXPERIMENTAL and upgrade after testing
3. **Usage Monitoring**: Track module usage to identify popular modules
4. **Version Management**: Use module versions to track updates
5. **Metadata Updates**: Keep module metadata current with capabilities

## Future Enhancements

1. **Module Marketplace**: Create a marketplace for buying/selling modules
2. **Reputation System**: Add reputation scoring based on usage and feedback
3. **Module Composability**: Allow modules to interact with each other
4. **Cross-Chain Modules**: Enable modules from other blockchains
5. **AI Model Integration**: Direct integration with AI model providers

## Conclusion

The Experience Module Registry provides a robust, secure, and flexible system for extending agent capabilities through external modules. With support for different experience types, security levels, and cryptographic verification, it enables the creation of a rich ecosystem of learning and adaptation modules for BAP-578 agents.
