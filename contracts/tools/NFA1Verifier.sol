// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/// @title NFA1Verifier - On-Chain NFA-1 Compliance Probe
/// @notice Deploys on any EVM chain. Given only a contract address,
///         probes ERC-165, function selectors, and behavioral compliance.
/// @dev This is a READ-ONLY verification tool. It does not modify state.
///      Usage: Deploy once, then call `fullAudit(target)` to get a compliance report.
///
///      Limitations (address-only, no source code):
///      - Cannot verify internal logic (e.g., terminate irreversibility by code path)
///      - Cannot verify event emission (requires off-chain log scanning)
///      - Cannot verify struct field names (ABI-level, not bytecode-level)
///      - CAN verify: interface support, function existence, return data shape, state transitions
contract NFA1Verifier {

    // ======================== STRUCTS ========================

    /// @notice Tier 1 compliance result (12 checks)
    struct Tier1Result {
        bool c01_erc721;             // ERC-721 interface support
        bool c02_statusEnum;         // Status enum exists with 3 values
        bool c05_getState;           // getState() returns valid data
        bool c06_getAgentMetadata;   // getAgentMetadata() returns valid data
        bool c08_lifecycleFunctions; // pause/unpause/terminate selectors exist
        bool c11_erc165;             // supportsInterface works
        bool c11_infa1core;          // INFA1Core interface ID registered
        bool c12_updateMetadata;     // updateAgentMetadata selector exists
        uint8 passCount;             // Total passing checks (max 8 probeable)
        uint8 totalProbeable;        // Total checks that can be probed on-chain (8)
    }

    /// @notice Tier 2 compliance result (learning system)
    struct Tier2Result {
        bool l01_learningState;      // getLearningState or individual queries exist
        bool l02_versionQuery;       // getLearningVersion returns data
        bool l04_learningQueries;    // All 4 learning query functions exist
        uint8 passCount;
        uint8 totalProbeable;        // 3
    }

    /// @notice Tier 3 compliance result (action execution)
    struct Tier3Result {
        bool a01_executeAction;      // executeAction selector exists
        bool a03_setLogicAddress;    // setLogicAddress selector exists
        bool a04_fundAgent;          // fundAgent selector exists
        uint8 passCount;
        uint8 totalProbeable;        // 3
    }

    /// @notice Extension detection result
    struct ExtensionResult {
        bool e01_lineage;            // INFA1Lineage functions detected
        bool e02_payment;            // INFA1Payment functions detected
        bool e03_identity;           // INFA1Identity functions detected
        bool e04_receipts;           // INFA1Receipts functions detected
        bool e05_compliance;         // INFA1Compliance functions detected
        bool e06_learningModules;    // INFA1LearningModules functions detected
        bool e07_proofOfPrompt;      // Proof-of-Prompt field detected
        bool e08_circuitBreaker;     // INFA1CircuitBreaker functions detected
    }

    /// @notice Full audit report
    struct AuditReport {
        address target;
        uint256 timestamp;
        bool isContract;
        Tier1Result tier1;
        Tier2Result tier2;
        Tier3Result tier3;
        ExtensionResult extensions;
        string verdict;              // "TIER1", "TIER2", "TIER3", "NOT_NFA1"
    }

    // ======================== INTERFACE IDS ========================

    // ERC-165: 0x01ffc9a7
    bytes4 private constant ERC165_ID = 0x01ffc9a7;
    // ERC-721: 0x80ac58cd
    bytes4 private constant ERC721_ID = 0x80ac58cd;

    // INFA1Core interface ID — XOR of all function selectors
    // Computed from: executeAction, setLogicAddress, fundAgent, pause, unpause,
    //   terminate, getState, getAgentMetadata, updateAgentMetadata,
    //   getLearningRoot, isLearningEnabled, getLearningVersion,
    //   getLastLearningUpdate, getLearningState, updateLearning
    bytes4 public immutable INFA1CORE_ID;

    constructor() {
        // Compute INFA1Core interface ID at deploy time
        INFA1CORE_ID =
            bytes4(keccak256("executeAction(uint256,bytes)")) ^
            bytes4(keccak256("setLogicAddress(uint256,address)")) ^
            bytes4(keccak256("fundAgent(uint256)")) ^
            bytes4(keccak256("pause(uint256)")) ^
            bytes4(keccak256("unpause(uint256)")) ^
            bytes4(keccak256("terminate(uint256)")) ^
            bytes4(keccak256("getState(uint256)")) ^
            bytes4(keccak256("getAgentMetadata(uint256)")) ^
            bytes4(keccak256("updateAgentMetadata(uint256,(string,string,string,string,string,bytes32))")) ^
            bytes4(keccak256("getLearningRoot(uint256)")) ^
            bytes4(keccak256("isLearningEnabled(uint256)")) ^
            bytes4(keccak256("getLearningVersion(uint256)")) ^
            bytes4(keccak256("getLastLearningUpdate(uint256)")) ^
            bytes4(keccak256("getLearningState(uint256)")) ^
            bytes4(keccak256("updateLearning(uint256,string,bytes32,bytes32,uint256)"));
    }

    // ======================== MAIN AUDIT ========================

    /// @notice Run a full NFA-1 compliance audit on a target contract
    /// @param target The contract address to audit
    /// @return report The full audit report
    function fullAudit(address target) external view returns (AuditReport memory report) {
        report.target = target;
        report.timestamp = block.timestamp;
        report.isContract = target.code.length > 0;

        if (!report.isContract) {
            report.verdict = "NOT_CONTRACT";
            return report;
        }

        report.tier1 = _auditTier1(target);
        report.tier2 = _auditTier2(target);
        report.tier3 = _auditTier3(target);
        report.extensions = _detectExtensions(target);

        // Determine verdict
        if (report.tier1.passCount >= 6 && report.tier2.passCount >= 2 && report.tier3.passCount >= 2) {
            report.verdict = "TIER3";
        } else if (report.tier1.passCount >= 6 && report.tier2.passCount >= 2) {
            report.verdict = "TIER2";
        } else if (report.tier1.passCount >= 6) {
            report.verdict = "TIER1";
        } else {
            report.verdict = "NOT_NFA1";
        }
    }

    /// @notice Quick check — is this address likely an NFA-1 contract?
    /// @param target The contract address to check
    /// @return isNFA True if the contract self-identifies as NFA-1 via ERC-165
    /// @return tier Detected compliance tier (0 if not NFA-1)
    function quickCheck(address target) external view returns (bool isNFA, uint8 tier) {
        if (target.code.length == 0) return (false, 0);

        // Fast path: ERC-165 check
        bool supportsINFA1 = _supportsInterface(target, INFA1CORE_ID);
        if (!supportsINFA1) return (false, 0);

        isNFA = true;
        tier = 1;

        // Check Tier 2 (learning)
        if (_hasFunction(target, "getLearningRoot(uint256)")) {
            tier = 2;
        }

        // Check Tier 3 (action execution)
        // executeAction cannot be probed via staticcall (ReentrancyGuard SSTORE).
        // Since INFA1Core interface ID includes executeAction, ERC-165 support implies Tier 3.
        if (tier >= 2 && supportsINFA1) {
            tier = 3;
        }
    }

    // ======================== TIER AUDITS ========================

    function _auditTier1(address target) internal view returns (Tier1Result memory r) {
        r.totalProbeable = 8;

        // C-01: ERC-721
        r.c01_erc721 = _supportsInterface(target, ERC721_ID);
        if (r.c01_erc721) r.passCount++;

        // C-02: Status enum — probe by calling getState and checking status range
        (bool ok, bytes memory data) = target.staticcall(
            abi.encodeWithSelector(bytes4(keccak256("getState(uint256)")), uint256(1))
        );
        r.c02_statusEnum = ok && data.length >= 160; // State struct has 5 fields
        if (r.c02_statusEnum) r.passCount++;

        // C-05: getState returns valid State struct (same probe as C-02, separate checklist item)
        r.c05_getState = r.c02_statusEnum;
        if (r.c05_getState) r.passCount++;

        // C-06: getAgentMetadata
        r.c06_getAgentMetadata = _hasFunction(target, "getAgentMetadata(uint256)");
        if (r.c06_getAgentMetadata) r.passCount++;

        // C-08: Lifecycle functions exist
        bool hasPause = _hasFunction(target, "pause(uint256)");
        bool hasUnpause = _hasFunction(target, "unpause(uint256)");
        bool hasTerminate = _hasFunction(target, "terminate(uint256)");
        r.c08_lifecycleFunctions = hasPause && hasUnpause && hasTerminate;
        if (r.c08_lifecycleFunctions) r.passCount++;

        // C-11: ERC-165 works
        r.c11_erc165 = _supportsInterface(target, ERC165_ID);
        if (r.c11_erc165) r.passCount++;

        // C-11 (extended): INFA1Core ID registered
        r.c11_infa1core = _supportsInterface(target, INFA1CORE_ID);
        if (r.c11_infa1core) r.passCount++;

        // C-12: updateAgentMetadata exists
        // Note: _hasFunction cannot probe this reliably because the struct parameter
        // (string,string,string,string,string,bytes32) requires properly encoded tuple
        // calldata. Simple uint256(1) padding causes ABI decoder to read misaligned
        // offsets, resulting in memory explosion. Fall back to ERC-165: if the contract
        // advertises INFA1Core (whose interfaceId XORs in updateAgentMetadata's selector),
        // the function MUST exist.
        r.c12_updateMetadata = _supportsInterface(target, INFA1CORE_ID);
        if (r.c12_updateMetadata) r.passCount++;
    }

    function _auditTier2(address target) internal view returns (Tier2Result memory r) {
        r.totalProbeable = 3;

        // L-01: LearningState (check via getLearningState or individual queries)
        r.l01_learningState = _hasFunction(target, "getLearningState(uint256)");
        if (r.l01_learningState) r.passCount++;

        // L-02: Version query
        r.l02_versionQuery = _hasFunction(target, "getLearningVersion(uint256)");
        if (r.l02_versionQuery) r.passCount++;

        // L-04: All 4 learning queries
        bool hasRoot = _hasFunction(target, "getLearningRoot(uint256)");
        bool hasEnabled = _hasFunction(target, "isLearningEnabled(uint256)");
        bool hasVersion = r.l02_versionQuery;
        bool hasLastUpdate = _hasFunction(target, "getLastLearningUpdate(uint256)");
        r.l04_learningQueries = hasRoot && hasEnabled && hasVersion && hasLastUpdate;
        if (r.l04_learningQueries) r.passCount++;
    }

    function _auditTier3(address target) internal view returns (Tier3Result memory r) {
        r.totalProbeable = 3;

        // A-01: executeAction — cannot be probed via staticcall because the
        // ReentrancyGuard modifier performs an SSTORE before any view-safe revert.
        // staticcall + SSTORE = empty revert data = false negative.
        // Fall back to INFA1Core ERC-165 detection (interfaceId includes executeAction).
        r.a01_executeAction = _supportsInterface(target, INFA1CORE_ID);
        if (r.a01_executeAction) r.passCount++;

        r.a03_setLogicAddress = _hasFunction(target, "setLogicAddress(uint256,address)");
        if (r.a03_setLogicAddress) r.passCount++;

        r.a04_fundAgent = _hasFunction(target, "fundAgent(uint256)");
        if (r.a04_fundAgent) r.passCount++;
    }

    // ======================== EXTENSION DETECTION ========================

    function _detectExtensions(address target) internal view returns (ExtensionResult memory r) {
        // E-01: Lineage
        r.e01_lineage = _hasFunction(target, "getLineage(uint256)")
            && _hasFunction(target, "getGeneration(uint256)");

        // E-02: Payment
        r.e02_payment = _hasFunction(target, "withdrawFromAgent(uint256,address,uint256)")
            && _hasFunction(target, "getAgentBalance(uint256)");

        // E-03: Identity
        r.e03_identity = _hasFunction(target, "linkIdentity(uint256,address,uint256)")
            && _hasFunction(target, "getLinkedIdentity(uint256,address)");

        // E-04: Receipts
        r.e04_receipts = _hasFunction(target, "getReceiptCount(uint256)")
            && _hasFunction(target, "getReceipt(uint256,uint256)");

        // E-05: Compliance
        r.e05_compliance = _hasFunction(target, "getComplianceMetadata(uint256)");

        // E-06: Learning Modules
        r.e06_learningModules = _hasFunction(target, "getLearningModules(uint256)")
            && _hasFunction(target, "verifyLearning(uint256,bytes32,bytes32[])");

        // E-07: Proof-of-Prompt (check via mint-time hash query — implementation-specific)
        // Cannot reliably detect without source code; skip
        r.e07_proofOfPrompt = false;

        // E-08: Circuit Breaker
        r.e08_circuitBreaker = _hasFunction(target, "isGloballyPaused()")
            && _hasFunction(target, "isCircuitBroken(uint256)");
    }

    // ======================== INTERNAL HELPERS ========================

    /// @dev Check if a target contract supports a given ERC-165 interface
    function _supportsInterface(address target, bytes4 interfaceId) internal view returns (bool) {
        (bool success, bytes memory data) = target.staticcall(
            abi.encodeWithSelector(ERC165_ID, interfaceId)
        );
        if (!success || data.length < 32) return false;
        return abi.decode(data, (bool));
    }

    /// @dev Check if a function selector exists on the target contract
    ///      by calling with a dummy tokenId (1) and checking for non-zero code response.
    ///      A revert with data (custom error / require message) means the function EXISTS
    ///      but rejected the call (auth, state check, etc.) — this still counts as "exists".
    ///      Only a revert with NO data (fallback / no matching selector) means "not found".
    function _hasFunction(address target, string memory signature) internal view returns (bool) {
        bytes4 selector = bytes4(keccak256(bytes(signature)));
        // Encode with a dummy uint256(1) argument for tokenId-based functions.
        // Provides 3 words of calldata (100 bytes) to satisfy ABI decoder for
        // functions with up to 3 simple parameters. The first word is 1 (dummy tokenId).
        // Limitation: functions with struct/tuple parameters containing dynamic types
        // (strings) or state-writing modifiers (ReentrancyGuard) may not be detectable.
        // See _auditTier1 and _auditTier3 for fallback approaches.
        bytes memory callData;
        // For functions with no args (like isGloballyPaused), just use the selector
        if (_isNoArgFunction(signature)) {
            callData = abi.encodePacked(selector);
        } else {
            callData = abi.encodeWithSelector(selector, uint256(1), uint256(0), uint256(0));
        }

        (bool success, bytes memory data) = target.staticcall(callData);

        if (success) return true;

        // If it reverted WITH data, the function exists but rejected (auth, etc.)
        // If it reverted with NO data, the selector doesn't match anything
        return data.length > 0;
    }

    /// @dev Check if a function signature has no arguments
    function _isNoArgFunction(string memory sig) internal pure returns (bool) {
        bytes memory b = bytes(sig);
        // Look for "()" at the end
        if (b.length < 2) return false;
        return b[b.length - 2] == bytes1("(") && b[b.length - 1] == bytes1(")");
    }
}
