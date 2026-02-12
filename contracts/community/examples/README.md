# BAP-578 Agent Logic Contract Examples

Example logic contracts demonstrating how to extend BAP-578 agents with custom on-chain capabilities.

## What Are Logic Contracts?

Every BAP-578 agent has a `logicAddress` field — an optional smart contract that serves as the agent's "brain". By binding a logic contract via `BAP578.setLogicAddress(tokenId, address)`, you give your agent programmable, autonomous on-chain behavior.

```
┌─────────────────┐     setLogicAddress()     ┌──────────────────┐
│   BAP-578 Agent  │ ──────────────────────► │  Logic Contract   │
│   (NFT + Wallet) │                          │  (Custom Brain)   │
└─────────────────┘                          └──────────────────┘
```

## Standard Interface

All examples implement `IAgentLogic`:

```solidity
interface IAgentLogic {
    function execute(uint256 tokenId, bytes calldata data)
        external payable returns (bytes memory);
    function description() external view returns (string memory);
}
```

## Examples

### 1. SimpleTrader

A token swap executor with built-in safety limits.

| Feature | Description |
|---------|-------------|
| Per-trade limit | Max 1 BNB per trade |
| Daily limit | Max 5 BNB per day per agent |
| Ownership check | Only agent owner can execute |
| Binding check | Verifies logic contract is bound to agent |

**Quick Start:**
```solidity
// 1. Deploy
SimpleTrader trader = new SimpleTrader(bap578Address);

// 2. Bind to agent
bap578.setLogicAddress(tokenId, address(trader));

// 3. Execute a swap
bytes memory tradeData = abi.encode(dexRouter, swapValue, swapCalldata);
trader.execute(tokenId, tradeData);
```

### 2. PriceAlert

On-chain price monitoring with configurable alert thresholds, powered by Binance Oracle.

| Feature | Description |
|---------|-------------|
| Binance Oracle | Reads from Binance Oracle Feed Adapters on BNB Chain |
| Configurable thresholds | Alert above or below target price |
| Keeper-compatible | `checkAlert()` callable by anyone |
| Event-driven | Emits `AlertTriggered` for off-chain indexing |

**Quick Start:**
```solidity
// 1. Deploy
PriceAlert alert = new PriceAlert(bap578Address);

// 2. Bind to agent
bap578.setLogicAddress(tokenId, address(alert));

// 3. Set alert: notify when BNB > $800
// Use Binance Oracle Feed Adapter address for BNB/USD
// See: https://oracle.binance.com/docs/price-feeds/contract-addresses/
alert.setAlert(tokenId, bnbUsdFeedAdapter, 80000000000, true);

// 4. Keeper checks periodically
alert.checkAlert(tokenId);
```

### 3. AutoFunder

Automatic agent balance top-up when funds run low.

| Feature | Description |
|---------|-------------|
| Balance monitoring | Triggers when agent balance drops below threshold |
| Pre-funded reserve | Owner deposits BNB reserve in advance |
| Keeper-compatible | `checkAndFund()` callable by anyone |
| Withdrawable | Owner can reclaim unused reserve |

**Quick Start:**
```solidity
// 1. Deploy
AutoFunder funder = new AutoFunder(bap578Address);

// 2. Bind to agent
bap578.setLogicAddress(tokenId, address(funder));

// 3. Configure: top up 0.1 BNB when balance < 0.05 BNB
funder.configure(tokenId, 0.05 ether, 0.1 ether);

// 4. Fund the reserve
funder.depositReserve{value: 1 ether}(tokenId);

// 5. Keeper checks periodically
funder.checkAndFund(tokenId);
```

## Building Your Own Logic Contract

1. Implement `IAgentLogic` interface
2. Accept `BAP578` address in constructor
3. Always verify `bap578.ownerOf(tokenId) == msg.sender` in `execute()`
4. Check `active` status and `logicAddress` binding via `getAgentState()`
5. Use events for off-chain indexing

```solidity
contract MyLogic is IAgentLogic {
    IBAP578 public immutable bap578;

    constructor(address _bap578) {
        bap578 = IBAP578(_bap578);
    }

    function execute(uint256 tokenId, bytes calldata data)
        external payable returns (bytes memory)
    {
        require(bap578.ownerOf(tokenId) == msg.sender, "Not owner");
        // Your logic here
    }

    function description() external pure returns (string memory) {
        return "My custom agent logic";
    }
}
```

## Security Notes

> ⚠️ These are educational examples. Do NOT deploy to production without a full security audit.

- Logic contracts interact with external protocols — always validate inputs
- Use reentrancy guards for functions that transfer value
- Test thoroughly on BSC Testnet before mainnet deployment

## License

MIT
