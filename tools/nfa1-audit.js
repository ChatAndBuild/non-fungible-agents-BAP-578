/**
 * NFA-1 Off-Chain Compliance Audit Script
 *
 * Given only a contract address, generates a full NFA-1 compliance report.
 * Combines on-chain probing (via NFA1Verifier) with event log scanning.
 *
 * Usage:
 *   node nfa1-audit.js <contract-address> [--rpc <rpc-url>] [--verifier <verifier-address>]
 *
 * Requirements:
 *   npm install ethers
 *
 * Output: JSON compliance report to stdout
 */

const { ethers } = require("ethers");

// ======================== CONFIG ========================

const DEFAULT_RPC = "https://bsc-dataseed.binance.org";

// NFA-1 Core Event Signatures (keccak256 topic0)
const CORE_EVENTS = {
  ActionExecuted: ethers.id("ActionExecuted(uint256,bytes)"),
  LogicUpgraded: ethers.id("LogicUpgraded(uint256,address,address)"),
  AgentFunded: ethers.id("AgentFunded(uint256,address,uint256)"),
  StatusChanged: ethers.id("StatusChanged(uint256,uint8)"),
  MetadataUpdated: ethers.id("MetadataUpdated(uint256,string)"),
  LearningUpdated: ethers.id("LearningUpdated(uint256,bytes32,bytes32,uint256)"),
};

// NFA-1 Core Function Selectors
const CORE_SELECTORS = {
  executeAction: ethers.id("executeAction(uint256,bytes)").slice(0, 10),
  setLogicAddress: ethers.id("setLogicAddress(uint256,address)").slice(0, 10),
  fundAgent: ethers.id("fundAgent(uint256)").slice(0, 10),
  pause: ethers.id("pause(uint256)").slice(0, 10),
  unpause: ethers.id("unpause(uint256)").slice(0, 10),
  terminate: ethers.id("terminate(uint256)").slice(0, 10),
  getState: ethers.id("getState(uint256)").slice(0, 10),
  getAgentMetadata: ethers.id("getAgentMetadata(uint256)").slice(0, 10),
  getLearningRoot: ethers.id("getLearningRoot(uint256)").slice(0, 10),
  isLearningEnabled: ethers.id("isLearningEnabled(uint256)").slice(0, 10),
  getLearningVersion: ethers.id("getLearningVersion(uint256)").slice(0, 10),
  getLastLearningUpdate: ethers.id("getLastLearningUpdate(uint256)").slice(0, 10),
};

// ERC-165 & ERC-721 interface IDs
const ERC165_ID = "0x01ffc9a7";
const ERC721_ID = "0x80ac58cd";

// ======================== MAIN ========================

async function main() {
  const args = parseArgs(process.argv.slice(2));

  if (!args.address) {
    console.error("Usage: node nfa1-audit.js <contract-address> [--rpc <url>]");
    process.exit(1);
  }

  const provider = new ethers.JsonRpcProvider(args.rpc || DEFAULT_RPC);
  const target = args.address;

  console.error(`[*] NFA-1 Compliance Audit`);
  console.error(`[*] Target: ${target}`);
  console.error(`[*] RPC: ${args.rpc || DEFAULT_RPC}`);
  console.error(`[*] Timestamp: ${new Date().toISOString()}`);
  console.error("");

  // Step 1: Basic checks
  console.error("[1/5] Checking contract existence...");
  const code = await provider.getCode(target);
  if (code === "0x") {
    console.error("    FAIL: Not a contract (EOA or empty)");
    outputReport({ target, error: "NOT_CONTRACT" });
    return;
  }
  console.error("    OK: Contract detected");

  // Step 2: ERC-165 probing
  console.error("[2/5] Probing ERC-165 interfaces...");
  const erc165 = await supportsInterface(provider, target, ERC165_ID);
  const erc721 = await supportsInterface(provider, target, ERC721_ID);
  console.error(`    ERC-165: ${erc165 ? "YES" : "NO"}`);
  console.error(`    ERC-721: ${erc721 ? "YES" : "NO"}`);

  // Step 3: Function selector probing
  console.error("[3/5] Probing NFA-1 function selectors...");
  const selectorResults = {};
  for (const [name, selector] of Object.entries(CORE_SELECTORS)) {
    const exists = await hasFunction(provider, target, selector);
    selectorResults[name] = exists;
    console.error(`    ${name}: ${exists ? "YES" : "NO"}`);
  }

  // Step 4: Event log scanning (last 10000 blocks)
  console.error("[4/5] Scanning event logs...");
  const currentBlock = await provider.getBlockNumber();
  const fromBlock = Math.max(0, currentBlock - 10000);
  const eventResults = {};
  for (const [name, topic] of Object.entries(CORE_EVENTS)) {
    try {
      const logs = await provider.getLogs({
        address: target,
        topics: [topic],
        fromBlock,
        toBlock: currentBlock,
      });
      eventResults[name] = { found: logs.length > 0, count: logs.length };
      console.error(`    ${name}: ${logs.length} events`);
    } catch {
      eventResults[name] = { found: false, count: 0, error: "query_failed" };
      console.error(`    ${name}: query failed`);
    }
  }

  // Step 5: State probing (try to read token #1)
  console.error("[5/5] Probing state data...");
  const stateProbe = await probeState(provider, target);

  // Compile report
  const report = compileReport({
    target,
    erc165,
    erc721,
    selectorResults,
    eventResults,
    stateProbe,
  });

  console.error("");
  console.error(`[*] Verdict: ${report.verdict}`);
  console.error(`[*] Tier 1: ${report.tier1.passCount}/${report.tier1.totalChecks} checks`);
  console.error(`[*] Tier 2: ${report.tier2.passCount}/${report.tier2.totalChecks} checks`);
  console.error(`[*] Tier 3: ${report.tier3.passCount}/${report.tier3.totalChecks} checks`);
  console.error("");

  // Output JSON to stdout
  outputReport(report);
}

// ======================== PROBING FUNCTIONS ========================

async function supportsInterface(provider, target, interfaceId) {
  try {
    const data = ethers.AbiCoder.defaultAbiCoder().encode(
      ["bytes4"],
      [interfaceId]
    );
    const calldata = ERC165_ID + data.slice(2);
    const result = await provider.call({ to: target, data: "0x01ffc9a7" + interfaceId.slice(2).padEnd(64, "0") });
    return result && ethers.AbiCoder.defaultAbiCoder().decode(["bool"], result)[0];
  } catch {
    return false;
  }
}

async function hasFunction(provider, target, selector) {
  try {
    // Call with tokenId=1 as dummy argument
    const calldata = selector + ethers.AbiCoder.defaultAbiCoder().encode(["uint256"], [1]).slice(2);
    await provider.call({ to: target, data: calldata });
    return true; // Success = function exists
  } catch (err) {
    // If error has data, function exists but reverted (auth, state check)
    // If no data, selector doesn't match (fallback revert)
    if (err.data && err.data !== "0x") return true;
    // Some providers encode errors differently
    if (err.message && err.message.includes("execution reverted")) return true;
    return false;
  }
}

async function probeState(provider, target) {
  const result = { hasState: false, hasMetadata: false, hasLearning: false };

  // Try getState(1)
  try {
    const data = CORE_SELECTORS.getState +
      ethers.AbiCoder.defaultAbiCoder().encode(["uint256"], [1]).slice(2);
    const res = await provider.call({ to: target, data });
    result.hasState = res.length > 66; // More than just a single word
  } catch {}

  // Try getAgentMetadata(1)
  try {
    const data = CORE_SELECTORS.getAgentMetadata +
      ethers.AbiCoder.defaultAbiCoder().encode(["uint256"], [1]).slice(2);
    const res = await provider.call({ to: target, data });
    result.hasMetadata = res.length > 66;
  } catch {}

  // Try getLearningRoot(1)
  try {
    const data = CORE_SELECTORS.getLearningRoot +
      ethers.AbiCoder.defaultAbiCoder().encode(["uint256"], [1]).slice(2);
    const res = await provider.call({ to: target, data });
    result.hasLearning = res.length >= 66;
  } catch {}

  return result;
}

// ======================== REPORT COMPILATION ========================

function compileReport({ target, erc165, erc721, selectorResults, eventResults, stateProbe }) {
  // Tier 1
  const tier1 = {
    c01_erc721: erc721,
    c05_getState: selectorResults.getState && stateProbe.hasState,
    c06_getMetadata: selectorResults.getAgentMetadata && stateProbe.hasMetadata,
    c08_lifecycle: selectorResults.pause && selectorResults.unpause && selectorResults.terminate,
    c10_events: Object.values(eventResults).filter(e => e.found).length >= 3,
    c11_erc165: erc165,
    c12_updateMetadata: !!selectorResults.getAgentMetadata, // Proxy check
  };
  tier1.passCount = Object.values(tier1).filter(Boolean).length;
  tier1.totalChecks = Object.keys(tier1).length - 2; // Exclude passCount/totalChecks

  // Tier 2
  const tier2 = {
    l01_learningState: stateProbe.hasLearning,
    l04_learningQueries:
      selectorResults.getLearningRoot &&
      selectorResults.isLearningEnabled &&
      selectorResults.getLearningVersion &&
      selectorResults.getLastLearningUpdate,
    l03_learningEvent: eventResults.LearningUpdated?.found || false,
  };
  tier2.passCount = Object.values(tier2).filter(Boolean).length;
  tier2.totalChecks = Object.keys(tier2).length - 2;

  // Tier 3
  const tier3 = {
    a01_executeAction: !!selectorResults.executeAction,
    a03_setLogicAddress: !!selectorResults.setLogicAddress,
    a04_fundAgent: !!selectorResults.fundAgent,
    a05_actionEvent: eventResults.ActionExecuted?.found || false,
  };
  tier3.passCount = Object.values(tier3).filter(Boolean).length;
  tier3.totalChecks = Object.keys(tier3).length - 2;

  // Verdict
  let verdict = "NOT_NFA1";
  if (tier1.passCount >= 5) verdict = "LIKELY_TIER1";
  if (tier1.passCount >= 5 && tier2.passCount >= 2) verdict = "LIKELY_TIER2";
  if (tier1.passCount >= 5 && tier2.passCount >= 2 && tier3.passCount >= 3) verdict = "LIKELY_TIER3";

  return {
    standard: "NFA-1",
    version: "1.1",
    target,
    timestamp: new Date().toISOString(),
    verdict,
    confidence: erc165 && erc721 ? "HIGH" : erc721 ? "MEDIUM" : "LOW",
    note: "Address-only audit. Source code review required for full compliance verification.",
    tier1,
    tier2,
    tier3,
    events: eventResults,
    selectorProbe: selectorResults,
    stateProbe,
  };
}

// ======================== UTILS ========================

function parseArgs(argv) {
  const result = { address: null, rpc: null, verifier: null };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--rpc" && argv[i + 1]) {
      result.rpc = argv[++i];
    } else if (argv[i] === "--verifier" && argv[i + 1]) {
      result.verifier = argv[++i];
    } else if (argv[i].startsWith("0x")) {
      result.address = argv[i];
    }
  }
  return result;
}

function outputReport(report) {
  console.log(JSON.stringify(report, null, 2));
}

main().catch(console.error);
