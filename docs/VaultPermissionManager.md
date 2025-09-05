# VaultPermissionManager.sol - Documentation

## **🔍 Quick Overview**

**VaultPermissionManager.sol** is a comprehensive permission management system for off-chain data vaults in the BEP007 ecosystem. It provides secure, time-based access control for agent data vaults with granular permission levels and delegation capabilities.

**Key Features:**
- ✅ **Time-Based Permissions** - Permissions with configurable start and end times
- ✅ **Granular Access Control** - Four permission levels (NONE, READ, WRITE, ADMIN)
- ✅ **Vault Management** - Create, manage, and deactivate data vaults
- ✅ **Agent Integration** - Authorized BEP007 agents can request and record access
- ✅ **Audit Trail** - Complete access logging and permission tracking
- ✅ **Automatic Cleanup** - Expired permission management
- ✅ **Circuit Breaker** - Emergency pause functionality

---

## **🏗️ Architecture Overview**

```
┌─────────────────────────────────────────┐
│        VaultPermissionManager           │
│         (Permission Controller)         │
├─────────────────────────────────────────┤
│ • Vault Creation & Management           │
│ • Permission Granting & Revocation      │
│ • Time-Based Access Control             │
│ • Agent Authorization                   │
│ • Access Audit & Logging                │
│ • Circuit Breaker Integration           │
└─────────────────┬───────────────────────┘
                  │ Manages Access To
                  ▼
┌─────────────────────────────────────────┐
│           Off-Chain Vaults              │
│        (Agent Data Storage)             │
├─────────────────────────────────────────┤
│ • Agent Metadata                        │
│ • Learning Data                         │
│ • Experience Records                    │
│ • Performance Metrics                   │
└─────────────────────────────────────────┘
                  ▲
                  │ Accessed By
┌─────────────────────────────────────────┐
│         BEP007 Agents                   │
│      (Authorized Accessors)             │
├─────────────────────────────────────────┤
│ • Permission-Based Access               │
│ • Time-Limited Sessions                 │
│ • Audit Trail Recording                 │
└─────────────────────────────────────────┘
```

---

## **🔐 Permission Levels**

### **PermissionLevel Enum**
```solidity
enum PermissionLevel {
    NONE,           // No access
    READ,           // Read-only access
    WRITE,          // Read and write access
    ADMIN           // Full administrative access
}
```

### **Permission Hierarchy**
- **NONE (0)**: No access to vault
- **READ (1)**: Can view vault contents
- **WRITE (2)**: Can read and modify vault contents
- **ADMIN (3)**: Full access including permission management

---

## **📊 Core Data Structures**

### **VaultPermission**
```solidity
struct VaultPermission {
    uint256 id;                 // Unique permission ID
    address vaultOwner;         // Owner of the vault
    address delegate;           // Address being granted permission
    string vaultId;             // Unique identifier for the vault
    PermissionLevel level;      // Permission level granted
    uint256 startTime;          // When permission becomes active
    uint256 endTime;            // When permission expires
    bool isActive;              // Whether permission is currently active
    string metadata;            // Additional metadata about the permission
    uint256 createdAt;          // When permission was created
}
```

### **VaultInfo**
```solidity
struct VaultInfo {
    address owner;              // Vault owner
    string vaultId;             // Unique vault identifier
    string description;         // Vault description
    bool isActive;              // Whether vault is active
    uint256 createdAt;          // Creation timestamp
    uint256 lastAccessed;       // Last access timestamp
}
```

---

## **🚀 Core Functions**

### **Vault Management**

#### **Create Vault**
```solidity
function createVault(
    string memory vaultId,
    string memory description
) external whenNotPaused nonReentrant
```

**Purpose**: Creates a new data vault for the caller
**Parameters**:
- `vaultId`: Unique identifier for the vault
- `description`: Human-readable description of vault contents

**Example**:
```javascript
await vaultPermissionManager.createVault(
    "agent-learning-data",
    "Contains agent learning metrics and experience data"
);
```

#### **Deactivate Vault**
```solidity
function deactivateVault(string memory vaultId) external whenNotPaused nonReentrant
```

**Purpose**: Deactivates a vault and revokes all associated permissions
**Parameters**:
- `vaultId`: Identifier of vault to deactivate

### **Permission Management**

#### **Grant Permission**
```solidity
function grantPermission(
    address delegate,
    string memory vaultId,
    PermissionLevel level,
    uint256 duration,
    string memory metadata
) external whenNotPaused nonReentrant
```

**Purpose**: Grants time-limited access to a vault
**Parameters**:
- `delegate`: Address to grant permission to
- `vaultId`: Vault identifier
- `level`: Permission level (READ, WRITE, ADMIN)
- `duration`: Permission duration in seconds
- `metadata`: Additional permission metadata

**Example**:
```javascript
// Grant 1-hour READ access to an agent
await vaultPermissionManager.grantPermission(
    agentAddress,
    "learning-data",
    1, // READ level
    3600, // 1 hour
    "Agent learning session access"
);
```

#### **Revoke Permission**
```solidity
function revokePermission(uint256 permissionId) external whenNotPaused nonReentrant
```

**Purpose**: Revokes an active permission before it expires
**Parameters**:
- `permissionId`: ID of permission to revoke

#### **Check Permission**
```solidity
function checkPermission(
    address vaultOwner,
    string memory vaultId,
    address accessor,
    PermissionLevel requiredLevel
) external view returns (bool hasPermission, PermissionLevel permissionLevel)
```

**Purpose**: Checks if an address has required permission level
**Returns**:
- `hasPermission`: Whether accessor has required permission
- `permissionLevel`: Actual permission level granted

**Example**:
```javascript
const [hasAccess, level] = await vaultPermissionManager.checkPermission(
    vaultOwner,
    "learning-data",
    agentAddress,
    1 // READ level required
);

if (hasAccess) {
    console.log(`Agent has ${level} access to vault`);
}
```

### **Access Recording**

#### **Record Vault Access**
```solidity
function recordVaultAccess(
    address vaultOwner,
    string memory vaultId,
    address accessor,
    PermissionLevel level
) external whenNotPaused
```

**Purpose**: Records vault access for audit purposes
**Note**: Only vault owners and authorized agents can call this function

### **Vault Viewing**

#### **View Vault Contents**
```solidity
function viewVaultContents(
    address vaultOwner,
    string memory vaultId
) external view returns (VaultInfo memory vaultInfo, bool hasAccess)
```

**Purpose**: Views vault contents if user has appropriate permissions
**Parameters**:
- `vaultOwner`: Owner of the vault
- `vaultId`: Vault identifier
**Returns**:
- `vaultInfo`: The vault information (owner, vaultId, description, isActive, createdAt, lastAccessed)
- `hasAccess`: Whether the caller has access to view the vault

**Access Requirements**:
- Vault owner always has access
- Users with READ, WRITE, or ADMIN permissions have access
- Vault must exist and be active
- Permission must be active and not expired

**Example**:
```javascript
// View vault contents as vault owner
const [vaultInfo, hasAccess] = await vaultPermissionManager.viewVaultContents(
    vaultOwner,
    "learning-data"
);

if (hasAccess) {
    console.log(`Vault: ${vaultInfo.vaultId}`);
    console.log(`Description: ${vaultInfo.description}`);
    console.log(`Active: ${vaultInfo.isActive}`);
    console.log(`Created: ${new Date(vaultInfo.createdAt * 1000)}`);
    console.log(`Last Accessed: ${new Date(vaultInfo.lastAccessed * 1000)}`);
}
```

### **Efficient Cleanup System**

#### **Paginated Cleanup**
```solidity
function cleanupExpiredPermissions(
    uint256 startIndex,
    uint256 maxIterations
) external whenNotPaused returns (uint256 cleaned, uint256 nextIndex)
```

**Purpose**: Cleans up expired permissions with pagination to avoid gas limits
**Parameters**:
- `startIndex`: Starting index for cleanup (1-based)
- `maxIterations`: Maximum number of permissions to check (max 1000)
**Returns**:
- `cleaned`: Number of permissions cleaned up
- `nextIndex`: Next index to continue from (0 if complete)

**Example**:
```javascript
// Clean up expired permissions in batches
let nextIndex = 1;
let totalCleaned = 0;

while (nextIndex > 0) {
    const [cleaned, next] = await vaultPermissionManager.cleanupExpiredPermissions(nextIndex, 100);
    totalCleaned += cleaned;
    nextIndex = next;
}

console.log(`Cleaned up ${totalCleaned} expired permissions`);
```

#### **Vault-Specific Cleanup**
```solidity
function cleanupExpiredVaultPermissions(
    address vaultOwner,
    string memory vaultId,
    uint256 maxIterations
) external whenNotPaused returns (uint256 cleaned)
```

**Purpose**: Cleans up expired permissions for a specific vault
**Parameters**:
- `vaultOwner`: Owner of the vault
- `vaultId`: Vault identifier
- `maxIterations`: Maximum number of permissions to check

#### **User-Specific Cleanup**
```solidity
function cleanupExpiredUserPermissions(
    address user,
    uint256 maxIterations
) external whenNotPaused returns (uint256 cleaned)
```

**Purpose**: Cleans up expired permissions for a specific user
**Parameters**:
- `user`: Address of the user
- `maxIterations`: Maximum number of permissions to check

#### **Cleanup Index Helper**
```solidity
function getNextCleanupIndex(
    uint256 startIndex,
    uint256 maxIterations
) external view returns (uint256 nextIndex, uint256 expiredCount)
```

**Purpose**: Gets the next cleanup index and count of expired permissions
**Returns**:
- `nextIndex`: Next index to continue from (0 if complete)
- `expiredCount`: Number of expired permissions found

#### **Simple Cleanup (Backward Compatibility)**
```solidity
function cleanupAllExpiredPermissions() external whenNotPaused returns (uint256 cleaned)
```

**Purpose**: Simple cleanup function for backward compatibility
**Note**: Uses default pagination (1000 max iterations)

### **Agent Authorization**

#### **Set Agent Authorization**
```solidity
function setAgentAuthorization(address agent, bool authorized) external onlyOwner
```

**Purpose**: Authorizes or deauthorizes BEP007 agent contracts
**Parameters**:
- `agent`: Address of agent contract
- `authorized`: Whether to authorize or deauthorize

---

## **💡 Common Use Cases**

### **1. Agent Learning Data Access**
```solidity
// Agent requests access to learning data vault
await vaultPermissionManager.grantPermission(
    learningAgent.address,
    "learning-metrics",
    1, // READ access
    1800, // 30 minutes
    "Learning session access"
);

// Agent accesses vault and records access
await vaultPermissionManager.recordVaultAccess(
    vaultOwner,
    "learning-metrics",
    learningAgent.address,
    1 // READ level
);
```

### **2. Collaborative Agent Development**
```solidity
// Grant WRITE access to development team
await vaultPermissionManager.grantPermission(
    developerAgent.address,
    "development-data",
    2, // WRITE access
    86400, // 24 hours
    "Development collaboration session"
);
```

### **3. Temporary Data Sharing**
```solidity
// Grant short-term access for data analysis
await vaultPermissionManager.grantPermission(
    analyticsAgent.address,
    "performance-data",
    1, // READ access
    3600, // 1 hour
    "Performance analysis session"
);
```

### **4. Emergency Access Revocation**
```solidity
// Revoke all permissions for a compromised agent
const userPermissions = await vaultPermissionManager.getUserPermissions(compromisedAgent);
for (const permissionId of userPermissions) {
    await vaultPermissionManager.revokePermission(permissionId);
}
```

### **5. Efficient Permission Cleanup**
```solidity
// Clean up expired permissions in batches to avoid gas limits
let nextIndex = 1;
let totalCleaned = 0;

while (nextIndex > 0) {
    const [cleaned, next] = await vaultPermissionManager.cleanupExpiredPermissions(nextIndex, 100);
    totalCleaned += cleaned;
    nextIndex = next;
}

console.log(`Cleaned up ${totalCleaned} expired permissions`);
```

### **6. Vault-Specific Maintenance**
```solidity
// Clean up expired permissions for a specific vault
const cleaned = await vaultPermissionManager.cleanupExpiredVaultPermissions(
    vaultOwner,
    "learning-data",
    50 // Check up to 50 permissions
);
```

### **7. Viewing Vault Contents**
```solidity
// View vault contents (requires appropriate permissions)
const [vaultInfo, hasAccess] = await vaultPermissionManager.viewVaultContents(
    vaultOwner,
    "learning-data"
);

if (hasAccess) {
    console.log(`Vault: ${vaultInfo.vaultId}`);
    console.log(`Description: ${vaultInfo.description}`);
    console.log(`Active: ${vaultInfo.isActive}`);
    console.log(`Created: ${new Date(vaultInfo.createdAt * 1000)}`);
    console.log(`Last Accessed: ${new Date(vaultInfo.lastAccessed * 1000)}`);
} else {
    console.log("Insufficient permissions to view vault");
}
```

---

## **🔒 Security Features**

### **Access Control**
- **Owner-Only Functions**: Vault creation, permission granting, and revocation
- **Agent Authorization**: Only authorized BEP007 agents can record access
- **Time-Based Permissions**: Automatic expiration of access rights

### **Circuit Breaker Integration**
All operations are paused when the circuit breaker is activated:
```javascript
// Check if system is paused
const isPaused = await circuitBreaker.globalPause();
```

### **Reentrancy Protection**
All state-changing functions are protected against reentrancy attacks using OpenZeppelin's ReentrancyGuard.

### **Permission Validation**
- Vault ownership verification
- Permission level validation
- Time-based access control
- Active status checking

---

## **📈 Monitoring and Analytics**

### **Events**
```solidity
event VaultCreated(address indexed owner, string indexed vaultId, string description, uint256 timestamp);
event PermissionGranted(uint256 indexed permissionId, address indexed vaultOwner, address indexed delegate, string vaultId, PermissionLevel level, uint256 startTime, uint256 endTime);
event PermissionRevoked(uint256 indexed permissionId, address indexed vaultOwner, address indexed delegate, string vaultId);
event VaultAccessed(address indexed vaultOwner, string indexed vaultId, address indexed accessor, PermissionLevel level, uint256 timestamp);
```

### **Statistics**
```solidity
function getStats() external view returns (
    uint256 totalPermissionsCount,
    uint256 totalVaultsCount,
    uint256 activePermissionsCount
)
```

### **Query Functions**
- `getUserPermissions(address user)`: Get all permissions for a user
- `getVaultPermissions(address vaultOwner, string vaultId)`: Get all permissions for a vault
- `getVaultInfo(address vaultOwner, string vaultId)`: Get vault information

---

## **🔄 Permission Lifecycle**

### **1. Permission Creation**
```
User creates vault → Grants permission → Permission becomes active
```

### **2. Permission Usage**
```
Agent checks permission → Accesses vault → Records access
```

### **3. Permission Expiration**
```
Permission expires → Automatic cleanup → Access denied
```

### **4. Permission Revocation**
```
Owner revokes permission → Permission deactivated → Access denied
```

---

## **⚡ Performance Considerations**

### **Gas Optimization**
- Efficient permission lookup using mappings
- Batch operations for multiple permissions
- Cleanup functions for expired permissions

### **Scalability**
- Permission IDs use counters for uniqueness
- Vault permissions indexed by owner and vault ID
- User permissions indexed by user address

### **Storage Efficiency**
- Compact permission structures
- Efficient event emission
- Minimal state variables

---

## **🚀 Deployment**

### **Prerequisites**
1. Deploy CircuitBreaker contract
2. Set up vault owner addresses
3. Authorize BEP007 agent contracts

### **Deployment Script**
```javascript
const VaultPermissionManager = await ethers.getContractFactory("VaultPermissionManager");
const vaultPermissionManager = await upgrades.deployProxy(
    VaultPermissionManager,
    [circuitBreaker.address, owner.address],
    { initializer: 'initialize' }
);
```

### **Initial Configuration**
```javascript
// Authorize BEP007 agents
await vaultPermissionManager.setAgentAuthorization(agent1.address, true);
await vaultPermissionManager.setAgentAuthorization(agent2.address, true);
```

---

## **🔧 Integration with BEP007 Ecosystem**

### **Agent Integration**
```solidity
// In BEP007 agent contract
function accessVault(string memory vaultId) external {
    // Check permission
    (bool hasAccess, ) = vaultPermissionManager.checkPermission(
        vaultOwner,
        vaultId,
        address(this),
        1 // READ level
    );
    
    require(hasAccess, "No vault access permission");
    
    // Record access
    vaultPermissionManager.recordVaultAccess(
        vaultOwner,
        vaultId,
        address(this),
        1
    );
    
    // Perform vault operations
    // ...
}
```

### **Governance Integration**
The VaultPermissionManager integrates with the BEP007 governance system for:
- Agent authorization management
- Circuit breaker control
- Emergency permission revocation

---

## **📋 Best Practices**

### **Permission Management**
1. **Principle of Least Privilege**: Grant minimum required permission level
2. **Time-Limited Access**: Use short permission durations when possible
3. **Regular Cleanup**: Periodically clean up expired permissions
4. **Audit Trail**: Always record vault access for security

### **Vault Organization**
1. **Descriptive IDs**: Use clear, descriptive vault identifiers
2. **Logical Grouping**: Group related data in same vault
3. **Access Control**: Regularly review and update permissions
4. **Deactivation**: Deactivate unused vaults to reduce attack surface

### **Security**
1. **Agent Authorization**: Only authorize trusted BEP007 agents
2. **Permission Monitoring**: Monitor permission grants and usage
3. **Emergency Procedures**: Have procedures for rapid permission revocation
4. **Circuit Breaker**: Use circuit breaker for emergency situations

---

## **🎯 Future Enhancements**

### **Planned Features**
1. **Permission Templates**: Predefined permission sets for common use cases
2. **Conditional Permissions**: Permissions based on external conditions
3. **Permission Delegation**: Allow agents to delegate permissions to other agents
4. **Advanced Analytics**: Detailed access pattern analysis and reporting
5. **Multi-Signature Vaults**: Vaults requiring multiple signatures for access
6. **Encryption Integration**: Built-in encryption key management for vault data

### **Integration Opportunities**
1. **IPFS Integration**: Direct integration with IPFS for off-chain storage
2. **Oracle Integration**: External data validation for permission conditions
3. **Cross-Chain Support**: Multi-chain vault permission management
4. **AI/ML Integration**: Intelligent permission recommendation systems

---

This VaultPermissionManager provides a robust foundation for secure, time-based access control to off-chain data vaults in the BEP007 ecosystem, enabling sophisticated agent interactions while maintaining security and auditability.