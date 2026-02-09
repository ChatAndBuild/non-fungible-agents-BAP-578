# NFA-1: 非同质化代理标准

**状态**: 草案
**版本**: 1.4
**创建日期**: 2026-02-08
**作者**: NFA-1 工作组
**许可证**: CC0-1.0
**依赖**: ERC-721, ERC-165
**基于**: [BAP-578 BEP 草案](https://github.com/bnb-chain/BEPs/blob/master/BAPs/BAP-578.md)（BNB Chain 官方）

---

## 目录

- [第 0 节: 约定](#第-0-节-约定)
- [第 1 节: 摘要](#第-1-节-摘要)
- [第 2 节: 动机](#第-2-节-动机)
- [第 3 节: 核心规范](#第-3-节-核心规范)
- [第 4 节: 可选扩展](#第-4-节-可选扩展)
- [第 5 节: 安全要求](#第-5-节-安全要求)
- [第 6 节: 升级性声明](#第-6-节-升级性声明)
- [第 7 节: 合规层级](#第-7-节-合规层级)
- [第 8 节: 跨协议集成](#第-8-节-跨协议集成)
- [第 9 节: 参考实现](#第-9-节-参考实现)
- [第 10 节: 设计决策说明](#第-10-节-设计决策说明)
- [第 11 节: 安全考虑](#第-11-节-安全考虑)
- [第 12 节: 向后兼容性](#第-12-节-向后兼容性)
- [第 13 节: 版权](#第-13-节-版权)

---

## 第 0 节: 约定

### 0.1 关键词

本文档中的关键词 "MUST"（必须）、"MUST NOT"（必须不）、"REQUIRED"（要求）、"SHALL"（应当）、"SHALL NOT"（不应当）、"SHOULD"（建议）、"SHOULD NOT"（不建议）、"RECOMMENDED"（推荐）、"MAY"（可以）和 "OPTIONAL"（可选）按照 [RFC 2119](https://www.ietf.org/rfc/rfc2119.txt) 的描述进行解释。

### 0.2 数据分类模型

NFA-1 区分三种数据存储层级。本规范中的每个数据字段都归属于其中一个层级：

| 层级 | 标签 | 描述 | 信任模型 |
|------|------|------|----------|
| 1 | **链上 (On-Chain)** | 直接存储在合约存储中。任何节点均可读取。 | 无信任 — 共识验证 |
| 2 | **可验证上链 (Verifiably On-Chain)** | 数据存储在链下，但加密承诺（哈希、Merkle 根）存储在链上。任何人可通过重新计算哈希来验证完整性。 | 最小化信任 — 可验证 |
| 3 | **链下 (Off-Chain)** | 无链上承诺。依赖托管方信任。 | 需要信任 — 托管 |

**为什么这很重要**：AI 代理的数据量很大（对话历史、模型权重、知识库）。将所有数据上链在经济上不可行。可验证上链层级提供了最佳权衡：链下存储成本 + 链上完整性保证。

示例：
- `Status`、`balance`、`learningRoot` → **链上**（第 1 层）
- `vaultHash` 锚定 vault JSON → **可验证上链**（第 2 层）
- `animationURI` 的动画文件 → **链下**（第 3 层）

### 0.3 术语

| 术语 | 定义 |
|------|------|
| **NFA** | 非同质化代理 (Non-Fungible Agent) — 代表具有身份、状态和学习能力的 AI 代理的 ERC-721 代币 |
| **Agent（代理）** | 由 NFA 代币代表的链上 + 链下实体 |
| **Vault（保险库）** | 包含代理完整数据（个性、记忆、训练配置）的链下 JSON |
| **Learning Root（学习根）** | 代理累积学习数据的链上哈希承诺 |
| **Logic Contract（逻辑合约）** | 代理委托动作执行的独立智能合约 |
| **Proof-of-Prompt（提示证明）** | 代理初始训练配置的不可变哈希，在铸造时设置 |

---

## 第 1 节: 摘要

NFA-1 为**非同质化代理 (Non-Fungible Agents)** 定义了标准接口 — 在 EVM 兼容区块链上代表可拥有、可交易、可学习的 AI 代理的 ERC-721 代币。

ERC-721 为静态数字资产定义了所有权和可转让性，而 NFA-1 在此基础上扩展了：

1. **生命周期管理** — 代理具有状态（活跃、暂停、终止）和定义明确的状态转换
2. **学习演进** — 对链下学习数据的版本化、可验证的链上承诺
3. **委托动作执行** — 代理可通过可插拔的逻辑合约执行链上操作
4. **身份和元数据** — 结构化的代理元数据，桥接链上状态和链下数据保险库

NFA-1 定义**接口和行为**（*是什么*），而非实现细节（*怎么做*）。它在 EVM 网络间通用，并与更广泛的 AI 代理生态系统兼容，包括 ERC-8004（代理身份）、X402（机器支付）和 A2A（代理间通信）协议。

核心理念转变：从 **AI 即服务 (AI-as-a-Service)**（你租用访问权）到 **AI 即资产 (AI-as-an-Asset)**（你拥有代理，它的成长是你的权益）。

---

## 第 2 节: 动机

### 2.1 NFT 与 AI 代理之间的差距

当前的 NFT (ERC-721) 代表静态资产 — 图片、音乐、收藏品。它们没有以下概念：
- **状态**：NFT 只有"被拥有"或"不被拥有"。没有"暂停"或"终止"状态。
- **学习**：NFT 的元数据一旦设置就固定了。没有渐进式改进的标准。
- **动作**：NFT 不能自主执行链上交易。
- **身份**：NFT 不携带描述代理能力的结构化元数据。

与此同时，AI 代理是动态实体——它们学习、行动、进化。缺乏将代理表示为可拥有链上资产的标准导致了碎片化：每个项目发明自己的方法，代理无法互操作，也不存在可组合的代理经济。

### 2.2 为什么 ERC-721 不够

ERC-721 提供了所有权和可转让性，但缺少：
- 生命周期状态（如何在不销毁代币的情况下暂停/终止代理）
- 学习语义（如何在链上追踪代理的改进）
- 动作委托（如何让代理安全地执行链上交易）
- 结构化代理元数据（个性、声音、能力）

### 2.3 为什么 ERC-8004 不够

ERC-8004（无信任代理）定义了代理身份注册和 Agent Card，这对于代理发现和声誉非常出色。但它不涉及：
- **所有权**：ERC-8004 代理不是天然可拥有/可交易的资产
- **学习生命周期**：没有追踪代理演进的标准
- **生命周期管理**：没有暂停/终止/状态语义
- **资产语义**：代理不被视为可增值的数字资产

### 2.4 NFA-1 填补空白

NFA-1 位于 ERC-721（所有权）和 ERC-8004（身份）之间：

```
ERC-721           NFA-1              ERC-8004
所有权     +   代理语义      +    代理发现
(静态)        (动态、可学习)       (注册)
```

NFA-1 可与两者组合：NFA 代币可以链接到 ERC-8004 注册表条目（通过身份扩展），其底层所有权遵循标准 ERC-721。

---

## 第 3 节: 核心规范

### 3.1 接口: INFA1Core

每个 NFA-1 合规合约 MUST 实现 `INFA1Core` 接口。合约也 MUST 符合 ERC-721 和 ERC-165。

```solidity
interface INFA1Core /* is IERC721 */ {
    enum Status { Active, Paused, Terminated }

    struct State {
        uint256 balance;
        Status status;
        address owner;
        address logicAddress;
        uint256 lastActionTimestamp;
    }

    struct AgentMetadata {
        string persona;
        string experience;
        string voiceHash;
        string animationURI;
        string vaultURI;
        bytes32 vaultHash;
    }

    struct LearningState {
        bytes32 learningRoot;
        uint256 learningVersion;
        uint256 lastLearningUpdate;
        bool learningEnabled;
    }
}
```

### 3.2 生命周期状态

代理 MUST 恰好存在于三种状态之一：

| 状态 | 值 | 描述 |
|------|-----|------|
| Active（活跃） | 0 | 正常运行。所有功能可用。 |
| Paused（暂停） | 1 | 动作执行被阻止。转账 MUST 保持允许。 |
| Terminated（终止） | 2 | 永久状态。MUST NOT 可逆。 |

**状态转换规则：**

```
          pause()            terminate()
Active ────────► Paused ──────────────► Terminated
  │                                        ▲
  │               terminate()              │
  └────────────────────────────────────────┘
          unpause()
Paused ────────► Active
```

- Active → Paused: MUST 允许（可逆）
- Paused → Active: MUST 允许（可逆）
- Active → Terminated: MUST 允许（不可逆）
- Paused → Terminated: MUST 允许（不可逆）
- Terminated → *: MUST 禁止

**关键要求**：暂停的代理 MUST 保持可转让。代理的生命周期状态 MUST NOT 阻止 ERC-721 转账操作。这保持了资产流动性——所有者必须始终能够出售或转让暂停的代理。

### 3.3 数据结构

#### 3.3.1 State（链上状态）

`State` 结构体的所有字段都是**链上**（第 1 层）：

| 字段 | 类型 | 分类 | 描述 |
|------|------|------|------|
| `balance` | uint256 | 链上 | 代理内部资金余额（原生货币） |
| `status` | Status | 链上 | 当前生命周期状态 |
| `owner` | address | 链上 | 当前所有者（MUST 反映 ERC-721 ownerOf） |
| `logicAddress` | address | 链上 | 委托逻辑合约（address(0) = 无） |
| `lastActionTimestamp` | uint256 | 链上 | 最后 executeAction 调用的时间戳 |

#### 3.3.2 AgentMetadata（混合存储）

| 字段 | 类型 | 分类 | 描述 |
|------|------|------|------|
| `persona` | string | 链上 | JSON 编码的个性特征 |
| `experience` | string | 链上 | 角色/用途摘要 |
| `voiceHash` | string | 链上 | 语音身份的哈希引用（MAY 为空） |
| `animationURI` | string | 链上 | 动画/头像的 URI（MAY 为空） |
| `vaultURI` | string | 链上 | 指向链下 vault 数据的 URI |
| `vaultHash` | bytes32 | **可验证上链** | vault JSON 的 keccak256（完整性锚点） |

`vaultHash` 字段是链上状态和链下数据之间的桥梁。它使任何人都能：
1. 从 `vaultURI` 获取 vault JSON
2. 计算 `keccak256(stableStringify(vaultJSON))`
3. 与链上 `vaultHash` 比较
4. 无需信任托管方即可验证完整性

#### 3.3.3 LearningState（链上学习状态）

| 字段 | 类型 | 分类 | 描述 |
|------|------|------|------|
| `learningRoot` | bytes32 | **可验证上链** | 学习数据的 Merkle 根或哈希 |
| `learningVersion` | uint256 | 链上 | 单调递增的版本计数器 |
| `lastLearningUpdate` | uint256 | 链上 | 最后更新的区块时间戳 |
| `learningEnabled` | bool | 链上 | 是否接受学习更新 |

### 3.4 核心事件

实现 MUST 在指定时刻发出以下事件：

```solidity
// 调用 executeAction 时 MUST 发出
event ActionExecuted(uint256 indexed tokenId, bytes result);

// 逻辑地址更改时 MUST 发出
event LogicUpgraded(uint256 indexed tokenId, address indexed oldLogic, address indexed newLogic);

// 代理收到资金时 MUST 发出
event AgentFunded(uint256 indexed tokenId, address indexed funder, uint256 amount);

// 任何状态转换时 MUST 发出
event StatusChanged(uint256 indexed tokenId, Status newStatus);

// 元数据更新时 MUST 发出
event MetadataUpdated(uint256 indexed tokenId, string metadataURI);

// 学习状态更新时 MUST 发出
event LearningUpdated(uint256 indexed tokenId, bytes32 indexed oldRoot, bytes32 indexed newRoot, uint256 newVersion);
```

### 3.5 核心函数

#### 3.5.1 动作执行

```solidity
function executeAction(uint256 tokenId, bytes calldata data)
    external returns (bytes memory result);
```

- MUST 在 `status != Active` 时回滚
- MUST 在 `logicAddress == address(0)` 时回滚
- MUST 将 `lastActionTimestamp` 更新为 `block.timestamp`
- MUST 发出 `ActionExecuted`
- SHOULD 对委托调用强制 gas 限制
- MUST 仅允许代币所有者或已授权者调用

```solidity
function setLogicAddress(uint256 tokenId, address newLogic) external;
```

- MUST 仅允许代币所有者或已授权者调用
- MUST NOT 在 `newLogic == address(0)` 时回滚（这是禁用逻辑合约）
- MUST 发出 `LogicUpgraded`

#### 3.5.2 资金管理

```solidity
function fundAgent(uint256 tokenId) external payable;
```

- MUST 允许任何人调用（无需许可）
- MUST 发出 `AgentFunded`

#### 3.5.3 生命周期管理

```solidity
function pause(uint256 tokenId) external;
function unpause(uint256 tokenId) external;
function terminate(uint256 tokenId) external;
```

- `pause()`：MUST 在状态非 Active 时回滚。MUST 仅允许所有者或已授权者调用。
- `unpause()`：MUST 在状态非 Paused 时回滚。MUST 仅允许所有者或已授权者调用。
- `terminate()`：MUST 在已 Terminated 时回滚。MUST 仅允许所有者或已授权者调用。MUST NOT 可逆。
- 三者均 MUST 发出 `StatusChanged`。

#### 3.5.4 状态查询

```solidity
function getState(uint256 tokenId) external view returns (State memory);
function getAgentMetadata(uint256 tokenId) external view returns (AgentMetadata memory);
function getLearningState(uint256 tokenId) external view returns (LearningState memory);
```

- `getState()` MUST 返回反映当前 ERC-721 `ownerOf()` 结果的 `owner` 字段。

#### 3.5.5 元数据更新

```solidity
function updateAgentMetadata(uint256 tokenId, AgentMetadata calldata metadata) external;
```

- MUST 在 Terminated 时回滚
- MUST 仅允许所有者、已授权者或指定更新者角色调用
- MUST 发出 `MetadataUpdated`

#### 3.5.6 学习系统

```solidity
function updateLearning(
    uint256 tokenId,
    string calldata newVaultURI,
    bytes32 newVaultHash,
    bytes32 newLearningRoot,
    uint256 newVersion
) external;
```

- MUST 在 `learningEnabled == false` 时回滚
- MUST 在 `newVersion <= 当前 learningVersion` 时回滚（单调性强制）
- MUST 在 Terminated 时回滚
- MUST 发出 `LearningUpdated`
- 授权模型由实现定义（所有者、指定更新者或预言机）

```solidity
function getLearningRoot(uint256 tokenId) external view returns (bytes32);
function isLearningEnabled(uint256 tokenId) external view returns (bool);
function getLearningVersion(uint256 tokenId) external view returns (uint256);
function getLastLearningUpdate(uint256 tokenId) external view returns (uint256);
```

### 3.6 提示证明 (Proof-of-Prompt)

实现 SHOULD 支持提示证明 (PoP) 机制：

- 铸造时 SHOULD 提交 `proofOfPromptHash` (bytes32) 并不可变存储
- PoP 哈希 MUST NOT 在铸造后可修改
- PoP 文档（链下存储）SHOULD 包含：

```json
{
  "model": "gpt-4o-mini",
  "systemPromptHash": "0xabc...",
  "configHash": "0xdef...",
  "trainingDataHash": "0x123...",
  "timestamp": 1707350400
}
```

**隐私说明**：实际系统提示不上链。仅存储哈希。所有者可选择性披露完整 PoP 文档以证明代理的训练血统。

### 3.7 数据验证架构

#### 3.7.1 Vault 哈希验证

```
vaultHash = keccak256(stableStringify(vaultJSON))
```

其中 `stableStringify` 是确定性 JSON 序列化器（键按字母排序，无尾随空格，一致的数字格式）。实现 MUST 文档化其序列化方法。

#### 3.7.2 学习根计算

定义了两条路径。实现 MUST 文档化使用哪条路径。

**路径 A — JSON 轻量记忆（较简单）**

```
learningRoot = keccak256(vaultHash || summaryHash)
```

其中 `summaryHash = keccak256(stableStringify(learningSummaryJSON))`。适用于学习数据较小且作为 vault 一部分或简单摘要存储的实现。

**路径 B — Merkle 树学习（可扩展）**

```
memoriesRoot = MerkleTree(memory1Hash, memory2Hash, ..., memoryNHash)
learningRoot = keccak256(vaultHash || memoriesRoot || summaryHash)
```

其中每个记忆条目可独立哈希，记忆构成 Merkle 树。适用于具有大量或细粒度学习数据的实现。

### 3.8 访问控制

NFA-1 定义**必须执行什么**访问控制规则，而非**如何**实现：

| 函数 | 所需授权 |
|------|----------|
| `executeAction` | 代币所有者或已授权者 |
| `setLogicAddress` | 代币所有者或已授权者 |
| `pause` / `unpause` / `terminate` | 代币所有者或已授权者 |
| `fundAgent` | 任何人（无需许可） |
| `updateAgentMetadata` | 所有者、已授权者或指定更新者 |
| `updateLearning` | 所有者或指定学习更新者 |

实现 MAY 使用任何访问控制模式：OpenZeppelin 的 `Ownable`、`AccessControl`、自定义角色映射、多签治理等。

### 3.9 ERC-165 接口检测

实现 MUST 支持 ERC-165 并 MUST 为 `INFA1Core` 接口 ID 返回 `true`：

```solidity
function supportsInterface(bytes4 interfaceId) external view returns (bool);
```

`INFA1Core` 接口 ID 是接口中定义的所有函数选择器的 XOR 运算结果。

### 3.10 实现说明 — BAP-578 BEP 草案对齐

> NFA-1 **基于** BAP-578 BEP 草案（[`bnb-chain/BEPs/BAPs/BAP-578.md`](https://github.com/bnb-chain/BEPs/blob/master/BAPs/BAP-578.md)），即 BNB Chain 官方的非同质化代理规范。本节记录标准如何与 BEP 草案对齐，以及哪些地方做了设计选择上的差异。

**核心对齐**：INFA1Core 实现了 BAP-578 BEP 草案的 `IBAP578` 接口。Status 枚举（`Active, Paused, Terminated`）、State 结构体、AgentMetadata 结构体、生命周期函数（`pause/unpause/terminate`）、`executeAction()`、`fundAgent()`、`setLogicAddress()` 以及学习系统均遵循 BEP 草案规范。

**事件索引**：BEP 草案在大多数事件中使用 `address indexed agent`（假设每个代理一个合约）。NFA-1 使用 `uint256 indexed tokenId`（遵循 ERC-721 多代币模式）。这是有意的设计选择 — BEP 草案自身存在不一致（`MetadataUpdated` 使用 `tokenId`，其他事件使用 `address`）。NFA-1 将所有事件统一为 `tokenId`，更符合 ERC-721 集合模式。

**学习系统架构**：BEP 草案将学习分离为独立的 `ILearningModule` 接口。NFA-1 在核心接口（INFA1Core）中包含基础学习状态和查询以简化采用，并提供 `INFA1LearningModules` 作为可选扩展用于高级 Merkle 证明验证，对应 BEP 草案的 `ILearningModule.verifyLearning()` 概念。

**提款函数位置**：BEP 草案的参考实现将 `withdrawFromAgent()` 放在核心合约中。NFA-1 将其移到可选的 `INFA1Payment` 扩展中，因为：
- `fundAgent()` 无需许可（任何人可资助）— 属于核心
- `withdrawFromAgent()` 仅限所有者且具有支付语义 — 属于支付扩展
- 保持核心最小化可提高 Tier 1 采用率

**升级机制中立性**：BEP 草案的参考实现使用 UUPS（`UUPSUpgradeable`）。NFA-1 不强制任何升级机制，回应社区反馈。标准定义接口，不限定架构。

**Gas 上限**：BEP 草案指定 `MAX_GAS_FOR_DELEGATECALL = 3,000,000`。NFA-1 推荐 500,000 作为保守默认值。实现 MAY 根据其委托调用复杂度覆盖此值。

**BEP 草案中未纳入 NFA-1 的功能**：`IMemoryModuleRegistry`（可插拔记忆模块）、`IVaultPermissionManager`（链下数据访问控制）和 `IAgentTemplate`（工厂模板）未包含。这些属于部署基础设施而非代理接口行为，可作为未来扩展候选。

---

## 第 4 节: 可选扩展

NFA-1 定义了八个可选扩展接口。实现 MAY 支持任意组合。

### 4.1 INFA1Lineage — 血统与融合

**状态**: MAY 实现

支持代理繁殖、代际追踪和融合机制。

```solidity
interface INFA1Lineage {
    struct Lineage {
        uint256 parent1;      // 创世代为 0
        uint256 parent2;      // 创世代为 0
        uint256 generation;   // 创世代为 0
        bool isSealed;        // 已用于融合
    }

    event OffspringCreated(uint256 indexed offspringId, uint256 indexed parent1, uint256 indexed parent2, uint256 generation);
    event AgentSealed(uint256 indexed tokenId);
    event AgentBurned(uint256 indexed tokenId);

    function getLineage(uint256 tokenId) external view returns (Lineage memory);
    function getGeneration(uint256 tokenId) external view returns (uint256);
    function isSealed(uint256 tokenId) external view returns (bool);
}
```

**实现说明**：
- 融合 SHOULD 使用 commit-reveal 模式防止抢跑
- 父代代理 MAY 在融合时被封存（锁定）或销毁，取决于实现的经济设计
- 代际计算：`max(parent1.generation, parent2.generation) + 1`

### 4.2 INFA1Payment — X402 支付兼容

**状态**: MAY 实现

使代理能参与 [X402 支付协议](https://x402.org) 生态系统，实现自主的机器间支付。

```solidity
interface INFA1Payment {
    event PaymentProcessed(uint256 indexed tokenId, address indexed counterparty, uint256 amount, bytes32 paymentRef);

    function withdrawFromAgent(uint256 tokenId, address payable recipient, uint256 amount) external;
    function getAgentBalance(uint256 tokenId) external view returns (uint256);
}
```

**NFA 的 X402 支付流程：**

```
1. NFA 支持的服务返回 HTTP 402 + 支付要求
2. 客户端构造 EIP-712 签名支付授权
3. 支付引用 NFA tokenId 作为服务提供者身份
4. Facilitator 验证签名，在链上结算支付
5. NFA 合约通过 fundAgent() 接收资金
6. 合约发出 PaymentProcessed / AgentFunded 事件
```

### 4.3 INFA1Identity — ERC-8004 身份桥接

**状态**: MAY 实现

将 NFA 桥接到 [ERC-8004 无信任代理](https://eips.ethereum.org/EIPS/eip-8004) 身份注册生态系统。

```solidity
interface INFA1Identity {
    event IdentityLinked(uint256 indexed tokenId, address indexed registry, uint256 indexed externalAgentId);
    event IdentityUnlinked(uint256 indexed tokenId, address indexed registry);

    function linkIdentity(uint256 tokenId, address registry, uint256 externalAgentId) external;
    function unlinkIdentity(uint256 tokenId, address registry) external;
    function getLinkedIdentity(uint256 tokenId, address registry) external view returns (uint256 externalAgentId);
}
```

**双向桥接：**
- NFA → ERC-8004：NFA 代币可链接到身份注册表中的 Agent Card，使其可被发现
- ERC-8004 → NFA：ERC-8004 代理可证明它有可验证的 NFA 资产背书，并具有链上学习历史

### 4.4 INFA1Receipts — 回执与审计

**状态**: SHOULD 实现（推荐）

为代理操作创建不可变的链上审计轨迹。这对于自主代理系统的信任和问责至关重要。

```solidity
interface INFA1Receipts {
    struct Receipt {
        uint256 tokenId;
        uint256 timestamp;
        bytes4 actionSelector;
        bytes32 inputHash;       // 可验证上链
        bytes32 outputHash;      // 可验证上链
        bool success;
    }

    event ReceiptCreated(uint256 indexed tokenId, uint256 indexed receiptIndex, bytes4 actionSelector, bytes32 inputHash, bytes32 outputHash, bool success);

    function getReceiptCount(uint256 tokenId) external view returns (uint256);
    function getReceipt(uint256 tokenId, uint256 index) external view returns (Receipt memory);
}
```

**数据分类**：回执结构体在链上存储哈希（第 2 层 — 可验证上链）。实际输入/输出数据存储在链下，但可通过链上哈希承诺进行验证。这最小化了 gas 成本同时保留了可审计性。

### 4.5 INFA1Compliance — 合规元数据

**状态**: MAY 实现

支持企业和监管合规要求。面向机构采用场景设计。

```solidity
interface INFA1Compliance {
    struct ComplianceMetadata {
        bytes32 kycHash;           // 可验证上链
        uint256 kycTimestamp;
        address kycProvider;
        uint8 complianceLevel;     // 0=无, 1=基础, 2=增强, 3=机构
        bool sanctionsCleared;
    }

    event ComplianceUpdated(uint256 indexed tokenId, address indexed kycProvider, uint8 complianceLevel);

    function getComplianceMetadata(uint256 tokenId) external view returns (ComplianceMetadata memory);
    function updateCompliance(uint256 tokenId, ComplianceMetadata calldata metadata) external;
}
```

**隐私**：所有敏感 KYC 数据存储在链下。仅哈希证明上链（可验证上链模式）。

### 4.6 INFA1LearningModules — 学习模块注册

**状态**: MAY 实现

为支持多种学习方法的代理提供可插拔学习策略。

```solidity
interface INFA1LearningModules {
    struct LearningModule {
        address moduleAddress;
        string moduleType;        // "rag", "finetune", "rl", "hybrid"
        bytes32 configHash;
        bool isActive;
    }

    struct LearningMetrics {
        uint256 totalInteractions;
        uint256 learningEvents;
        uint256 lastUpdateTimestamp;
        uint256 confidenceScore;      // 0-10000 基点
    }

    event LearningModuleRegistered(uint256 indexed tokenId, address indexed moduleAddress, string moduleType);
    event LearningModuleDeactivated(uint256 indexed tokenId, address indexed moduleAddress);
    event LearningMilestone(uint256 indexed tokenId, string milestone, uint256 value);

    function registerLearningModule(uint256 tokenId, LearningModule calldata module) external;
    function deactivateLearningModule(uint256 tokenId, address moduleAddress) external;
    function getLearningModules(uint256 tokenId) external view returns (LearningModule[] memory);
    function verifyLearning(uint256 tokenId, bytes32 claim, bytes32[] calldata proof) external view returns (bool);
    function getLearningMetrics(uint256 tokenId) external view returns (LearningMetrics memory);
}
```

**支持的模块类型：**
| 类型 | 描述 |
|------|------|
| `rag` | 检索增强生成 — 代理从知识库检索 |
| `finetune` | 微调 — 代理基础模型定期重新训练 |
| `rl` | 强化学习 — 代理通过奖励信号改进 |
| `hybrid` | 多种方法的组合 |

**学习验证**：`verifyLearning()` 函数启用链上 Merkle 证明验证。给定叶哈希（`claim`）和 Merkle 证明，验证声明是否存在于代理的学习树中。

**学习指标**：`LearningMetrics` 结构体追踪学习进展。`confidenceScore`（0-10000 基点）提供标准化的学习成熟度度量。里程碑（如 "100_interactions"、"confidence_90"）作为事件发出。

### 4.7 INFA1CircuitBreaker — 紧急熔断器

**状态**: SHOULD 实现（推荐用于生产部署）

提供独立于个别代理生命周期暂停的全生态和逐代理紧急暂停能力。

```solidity
interface INFA1CircuitBreaker {
    event GlobalPauseUpdated(bool paused);
    event AgentCircuitBreakerUpdated(uint256 indexed tokenId, bool paused);

    function isGloballyPaused() external view returns (bool);
    function isCircuitBroken(uint256 tokenId) external view returns (bool);
    function setGlobalPause(bool paused) external;
    function setAgentCircuitBreaker(uint256 tokenId, bool paused) external;
}
```

**与 INFA1Core.pause() 的关键区别：**

| 方面 | INFA1Core.pause() | INFA1CircuitBreaker |
|------|-------------------|---------------------|
| 范围 | 单个代理 | 全局或逐代理 |
| 权限 | 代币所有者 | 治理 / 紧急多签 |
| 目的 | 所有者选择 | 紧急响应 |
| 可逆性 | 所有者可恢复 | 治理可恢复 |

代理可以同时处于 Active（生命周期）但被熔断（紧急）状态。当熔断器激活时，`executeAction()` SHOULD 回滚，即使代理的生命周期状态为 Active。

---

## 第 5 节: 安全要求

### 5.1 MUST（必须）

| ID | 要求 |
|----|------|
| S-01 | **最小权限默认**：代理 MUST 默认无任何权限，仅限显式授予 |
| S-02 | **Gas 限制**：通过 `executeAction` 的委托调用 SHOULD 强制 gas 上限以防止 griefing 攻击 |
| S-03 | **不可逆终止**：一旦 Terminated，代理 MUST NOT 在任何代码路径下可重新激活 |
| S-04 | **状态门控**：`executeAction` MUST 在状态非 Active 时回滚 |
| S-05 | **单调学习版本**：`learningVersion` MUST 只增不减；MUST 拒绝相同或更低版本 |
| S-06 | **暂停可转让**：暂停的代理 MUST 可通过标准 ERC-721 函数转让 |
| S-07 | **终止禁用学习**：`terminate()` MUST 将 `learningEnabled` 设为 false |

### 5.2 SHOULD（建议）

| ID | 要求 |
|----|------|
| S-08 | **熔断机制**：实现 INFA1CircuitBreaker 扩展以实现全局/逐代理紧急暂停 |
| S-09 | **渐进自主**：以有限权限启动代理，基于信任逐步扩展 |
| S-10 | **审计轨迹**：实现 INFA1Receipts 扩展以实现操作问责 |
| S-11 | **沙箱执行**：逻辑合约 SHOULD 被隔离，不能影响其他代理的状态 |
| S-12 | **重入保护**：状态修改函数 SHOULD 使用重入保护 |

### 5.3 MAY（可选）

| ID | 要求 |
|----|------|
| S-13 | 关键操作的多签治理 |
| S-14 | 逻辑合约变更的时间锁 |
| S-15 | 代理余额提取的支出限制 |
| S-16 | 动作执行频率的速率限制 |
| S-17 | Vault 权限管理 — 链下 vault 数据的访问控制，防止未授权读取敏感代理数据 |

---

## 第 6 节: 升级性声明

> **NFA-1 不强制任何特定的升级机制。**

这是刻意的设计选择。标准定义接口和行为（*是什么*），而非实现架构（*怎么做*）。不同的应用有不同的需求：

| 模式 | 使用场景 |
|------|----------|
| **不可变** | 最大无信任性；部署后不可升级 |
| **UUPS 代理** | 轻量升级；升级逻辑在实现合约中 |
| **透明代理** | 代理管理员和用户之间有清晰分离 |
| **Diamond (EIP-2535)** | 模块化升级；各个 facet 可独立升级 |
| **Beacon 代理** | 多个代理共享同一实现；单点升级 |
| **Create2 重部署** | 使用确定性地址的全新部署 |

以上任何一种均 MAY 使用，前提是：

1. 部署的合约满足 `INFA1Core` 接口
2. `terminate()` 的不可逆性在升级后保留 — Terminated 代理在任何升级后 MUST 保持 Terminated
3. `learningVersion` 的单调性在升级后保留 — 版本计数器在任何升级后 MUST NOT 减少
4. ERC-165 的 `supportsInterface` 在升级后继续为 `INFA1Core` 返回 `true`

使用升级机制的实现 SHOULD 文档化其升级机制和治理流程。

---

## 第 7 节: 合规层级

NFA-1 定义了四个合规层级。详见完整的 [NFA-1 合规检查清单](../checklist/NFA1-CHECKLIST.md) 以获取逐项验证。

### 第 1 层 — 最小可行 NFA (MUST 全部通过)

将代币称为 NFA 的绝对最低要求。涵盖：ERC-721 合规、Status 枚举、状态转换、暂停可转让、核心状态查询、vaultHash 完整性锚点、生命周期函数、不可逆终止、核心事件和 ERC-165。

**12 项 (C-01 至 C-12)**

### 第 2 层 — 可学习 NFA (SHOULD 全部通过)

添加学习系统。涵盖：LearningState 结构体、单调版本强制、LearningUpdated 事件、学习查询函数、终止禁用学习、文档化学习路径（A 或 B）和验证流程。

**7 项 (L-01 至 L-07)**

### 第 3 层 — 自主 NFA (MAY)

添加动作执行能力。涵盖：executeAction、gas 限制、setLogicAddress、fundAgent、动作事件、lastActionTimestamp 追踪和非 Active 拒绝。

**7 项 (A-01 至 A-07)**

### 第 4 层 — 全栈 NFA（可选扩展组合）

八个可选扩展的任意组合。每个扩展有自己的子项。

**8 个扩展组 (E-01 至 E-08)**

---

## 第 8 节: 跨协议集成

NFA-1 设计为与新兴 AI 代理协议栈可组合：

```
┌─────────────────────────────────────────────────────┐
│                     应用层                            │
│          (代理 UI、仪表板、市场)                       │
├─────────────────────────────────────────────────────┤
│                   A2A / MCP 层                       │
│              (代理间通信)                              │
├──────────┬──────────┬──────────┬────────────────────┤
│  NFA-1   │ ERC-8004 │   X402   │    其他协议         │
│ (可拥有   │ (代理    │ (机器    │                     │
│  代理)    │  身份)   │  支付)   │                     │
├──────────┴──────────┴──────────┴────────────────────┤
│                   ERC-721 / EVM                      │
│               (所有权与转账)                           │
└─────────────────────────────────────────────────────┘
```

### 8.1 NFA-1 ↔ ERC-8004

| NFA-1 概念 | ERC-8004 映射 |
|-----------|--------------|
| tokenId | 注册表中的代理 ID |
| AgentMetadata.persona | Agent Card 描述 |
| AgentMetadata.vaultURI | Agent Card 端点 |
| INFA1Identity.linkIdentity() | 身份注册表中的注册 |

### 8.2 NFA-1 ↔ X402

| NFA-1 概念 | X402 映射 |
|-----------|----------|
| tokenId | 服务提供者身份 |
| fundAgent() | 支付结算 |
| INFA1Payment.withdrawFromAgent() | 收入提取 |
| AgentMetadata.vaultURI | 服务端点（返回 402） |

### 8.3 NFA-1 ↔ A2A

| NFA-1 概念 | A2A 映射 |
|-----------|---------|
| AgentMetadata | Agent Card（发现） |
| executeAction() | 任务执行 |
| INFA1Receipts | 操作审计轨迹 |
| learningRoot | 能力证明 |

### 8.4 跨链考量

NFA-1 设计为 EVM 无关，可部署在任何 EVM 兼容链上。对于多链部署：

**单链**：标准 NFA-1 合约在任何单一 EVM 链上直接可用（BNB Chain、Ethereum、Polygon、Arbitrum 等）。

**跨链代理可移植性**：需要跨多链运行的代理，实现 MAY 集成跨链消息协议：

| 协议 | 使用场景 |
|------|----------|
| **Hyperlane** | 无需许可的链间消息传递；支持 100+ 链的代理状态同步 |
| **LayerZero** | 全链消息传递用于跨链代理操作 |
| **Wormhole** | 跨链资产和消息传输 |
| **Chainlink CCIP** | 安全跨链互操作性 |

**跨链设计原则：**
- 权威代理状态（所有权、Status、learningRoot）SHOULD 存在于一条"主链"上
- 跨链操作 SHOULD 通过消息传递引用主链状态
- 学习更新 SHOULD 仅在主链上接受以保持版本单调性
- `vaultURI` 和 `vaultHash` 验证架构天然支持跨链场景：哈希在主链上，vault 数据可从任何链访问

NFA-1 不强制特定的跨链解决方案。由实现根据目标链生态系统决定。

---

## 第 9 节: 参考实现

### 9.1 已知合规实现

**KinForge (BNB Chain)**
首个已知的 NFA-1 合规部署。实现了完整的 BAP-578 BEP 草案规范。

- 合约：`HouseForgeAgent.sol`
- 网络：BNB Chain 主网
- 合规：第 1 层 + 第 2 层 + 第 3 层 + 部分第 4 层（血统）
- 铸造 1300+ 代理并具有活跃学习系统

详见 [BAP-578 合规映射](../compliance/BAP578-COMPLIANCE.md) 获取逐项验证。

### 9.2 最小实现

在 [`contracts/examples/MinimalNFA.sol`](../contracts/examples/MinimalNFA.sol) 提供了最小的 Tier 1 参考实现。该实现：

- 满足所有 Tier 1 合规项 (C-01 至 C-12)
- 包含 Tier 2（学习）和 Tier 3（动作执行）以供参考
- 使用 OpenZeppelin ERC-721 作为基础
- 故意保持简单用于教育目的
- 不应在未添加额外安全措施的情况下用于生产

---

## 第 10 节: 设计决策说明

### 10.1 为什么选择混合存储（链上 + 可验证上链）？

AI 代理数据量很大：对话历史、模型配置、知识库和训练数据很容易超过数兆字节。将所有数据上链需要数千美元的 gas 费用，经济上不可行。

可验证上链模式兼具两者优势：
- **成本**：链下存储（IPFS、Arweave、中心化服务器）使用链下价格
- **完整性**：链上哈希承诺意味着任何人可验证数据未被篡改
- **隐私**：敏感数据留在链下；仅哈希上链

### 10.2 为什么要单调学习版本？

`learningVersion` 计数器 MUST 只增不减，以防止：
- **重放攻击**：攻击者无法将代理恢复到之前的（能力较弱的）学习状态
- **版本冲突**：并发更新通过版本号序列化
- **审计完整性**：版本序列提供清晰、线性的学习演进历史

### 10.3 为什么是三种状态（Active/Paused/Terminated）？

两种状态（Active/Terminated）不够，因为：
- **Paused** 允许临时暂停而无永久后果（例如维护期间、所有权争议或安全事件）
- **暂停但可转让**确保代理即使在暂停时仍是流动资产

三种状态优于更细粒度的状态（如 Dormant、Restricted），以保持标准简单且普遍适用。

### 10.4 为什么暂停代理 MUST 可转让？

如果暂停的代理不可转让，恶意实现可以通过暂停来永久锁定资产。可转让要求确保：
- 资产流动性始终得到保持
- 所有者始终可以退出其头寸
- 市场兼容性（代理始终可以上架/出售）

### 10.5 为什么不强制 UUPS？

强制特定升级机制会：
- **限制采用**：有不同升级需求的项目将不合规
- **混合关注点**：标准定义行为，而非实现架构
- **降低无信任性**：某些场景（如完全去中心化代理）需要不可变合约

通过仅定义接口，标准让构建者选择适合其应用的升级机制（或不使用）。

### 10.6 为什么将动作执行与学习分离？

动作执行 (`executeAction`) 和学习 (`updateLearning`) 服务于根本不同的目的：
- **动作**是同步的、链上的、消耗 gas 的操作，具有即时效果
- **学习**是异步的、主要在链下的，链上状态仅限于哈希承诺

分离它们允许：
- 不同的授权模型（动作由所有者执行，学习由后端预言机执行）
- 独立演进（学习系统可以在不影响动作执行的情况下升级）
- 更清晰的安全边界（动作执行需要更严格的控制）

### 10.7 混合架构的 Gas 效率

NFA-1 混合存储模型（链上 + 可验证上链）相比全链上存储实现显著 gas 节省：

- **学习更新**：每次学习更新仅写入 32 字节 Merkle 根，无论链下学习了多少数据。单次 `SSTORE`（约 20,000 gas）锚定潜在数兆字节的链下数据。
- **Vault 完整性**：`vaultHash`（32 字节）锚定整个 vault JSON（可能是数千字节到数兆字节），避免链上字符串存储。
- **元数据最小化**：仅基本身份字段存储在链上；详细的个性数据、对话历史和训练配置存在 vault 中。

该架构相比朴素的全链上方法实现 80-90% 的 gas 节省，同时保持加密可验证性。

### 10.8 工厂模式与治理

虽然 NFA-1 不标准化工厂或治理合约，但生产部署 SHOULD 考虑：

**代理工厂**：管理以下内容的工厂合约：
- 不同代理类型的模板审批和版本管理
- 学习模块注册和审批
- 所有代理的全局学习统计
- 具有一致初始化的标准化代理部署

**链上治理**：用于协议级决策：
- 参数变更的提案/投票/执行
- 熔断器激活（通过 INFA1CircuitBreaker）
- 模板和模块审批

这些是实现关注点，而非标准要求，因为其设计因项目的治理模型和部署架构而异。

---

## 第 11 节: 安全考虑

### 11.1 逻辑合约风险

`executeAction` 函数将调用委托给任意的 `logicAddress`。这是标准中风险最高的函数：

- **恶意逻辑**：被入侵的逻辑合约可能耗尽代理余额或执行未授权操作
- **重入**：委托调用可能重入 NFA 合约
- **Gas griefing**：无界委托调用可能消耗所有可用 gas

**缓解措施：**
- 实现 SHOULD 对委托调用强制 gas 限制
- 实现 SHOULD 使用重入保护（如 OpenZeppelin 的 `ReentrancyGuard`）
- 高价值代理的逻辑合约变更 SHOULD 有时间锁或多签要求

### 11.2 学习系统信任模型

学习系统信任指定的学习更新者提交准确的学习根。被入侵的更新者可能：

- 提交不正确的学习根（数据完整性攻击）
- 快速递增版本（如果版本空间耗尽则拒绝未来更新）

**缓解措施：**
- 学习更新者角色应谨慎管理
- 实现 MAY 要求学习更新由多方验证
- 单调版本要求防止回滚攻击

### 11.3 融合中的抢跑

对于支持 Lineage 扩展的实现，涉及随机性（特征继承）的融合操作容易受到抢跑攻击：

- 矿工/验证者可以观察待处理的融合交易并操纵区块参数以影响特征结果

**缓解措施**：使用 commit-reveal 模式进行融合。用户提交其选择的哈希，等待 N 个区块，然后揭示。这防止了抢跑。

### 11.4 Vault URI 可用性

指向链下数据的 `vaultURI` 引入了中心化风险：

- 如果 vault 托管提供者下线，代理数据将无法访问
- 链上 `vaultHash` 证明数据*应该是*什么，但不提供数据访问

**缓解措施：**
- 使用去中心化存储（IPFS、Arweave）存储 vault 数据
- 跨多个托管提供者维护冗余副本
- 链上 `vaultHash` 确保数据可用时始终可验证完整性

### 11.5 Vault 数据访问控制

虽然 `vaultHash` 确保完整性，但它不控制谁可以读取 vault 数据。具有敏感数据（专有训练配置、私人对话）的代理需要访问控制：

- Vault 托管提供者 SHOULD 为 vault 读取访问实现身份验证
- 实现 MAY 使用所有者控制的密钥加密敏感 vault 字段
- MAY 使用 VaultPermissionManager 模式（向特定地址授予读取权限）进行受控披露
- 公开 vault 数据（个性、能力）SHOULD 与私有 vault 数据（对话历史、训练配置）可分离

---

## 第 12 节: 向后兼容性

NFA-1 完全向后兼容 ERC-721。任何 NFA-1 合规合约同时也是有效的 ERC-721 合约。这意味着：

- NFA 兼容所有现有 ERC-721 基础设施（钱包、市场、浏览器）
- 现有 ERC-721 工具可以转账、授权和查询 NFA
- 额外的 NFA-1 函数是附加的，不修改 ERC-721 行为

对于在现有 ERC-721 合约基础上构建的实现，NFA-1 函数可通过以下方式添加：
- 直接继承（将 INFA1Core 添加到合约）
- 代理模式（在新实现中添加 NFA-1 函数）
- Diamond 模式（将 NFA-1 作为新 facet 添加）

---

## 第 13 节: 版权

本规范以 [CC0 1.0 通用](https://creativecommons.org/publicdomain/zero/1.0/) 许可发布。在法律允许的范围内，作者放弃了对本作品的所有版权和相关或邻接权利。
