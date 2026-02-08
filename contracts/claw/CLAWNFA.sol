// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

/// @title Minimal Ownable (no OpenZeppelin)
contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Owner: not owner");
        _;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Owner: zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

/// @title IBAP578 Minimal Interface
interface IBAP578 {
    enum Status {
        Active,
        Paused,
        Terminated
    }

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

    event ActionExecuted(address indexed agent, bytes result);
    event LogicUpgraded(address indexed agent, address oldLogic, address newLogic);
    event AgentFunded(address indexed agent, address indexed funder, uint256 amount);
    event StatusChanged(address indexed agent, Status newStatus);
    event MetadataUpdated(uint256 indexed tokenId, string metadataURI);
    event MintLimitUpdated(uint256 oldLimit, uint256 newLimit);

    function executeAction(uint256 tokenId, bytes calldata data) external;
    function setLogicAddress(uint256 tokenId, address newLogic) external;
    function fundAgent(uint256 tokenId) external payable;
    function getState(uint256 tokenId) external view returns (State memory);
    function getAgentMetadata(uint256 tokenId) external view returns (AgentMetadata memory);
    function updateAgentMetadata(uint256 tokenId, AgentMetadata memory metadata) external;
    function pause(uint256 tokenId) external;
    function unpause(uint256 tokenId) external;
    function terminate(uint256 tokenId) external;
}

/// @title Minimal NFA (no OpenZeppelin)
contract NFA is Ownable, IBAP578 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    string public name = "Non-Fungible Agent";
    string public symbol = "NFA";

    uint256 public immutable MAX_SUPPLY;
    uint256 private _nextTokenId;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;

    uint256 public mintLimitPerAddress;
    mapping(address => uint256) private _mintedCount;

    // ERC20 token requirements
    address public immutable REQUIRED_TOKEN;
    uint256 public constant MIN_TOKEN_BALANCE = 10000 * 10 ** 18;

    // Simplified metadata - only base URI + token ID
    string public baseURI;

    mapping(uint256 => State) private _states;
    mapping(uint256 => AgentMetadata) private _agentMetadata;

    constructor(address _requiredToken, uint256 _maxSupply) Ownable() {
        require(_requiredToken != address(0), "NFA: zero address token");
        REQUIRED_TOKEN = _requiredToken;
        MAX_SUPPLY = _maxSupply;
        mintLimitPerAddress = 2;
    }

    // Core ERC721 Metadata function for marketplaces
    function tokenURI(uint256 tokenId) public view returns (string memory) {
        require(_owners[tokenId] != address(0), "NFA: nonexistent token");
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, _toString(tokenId))) : "";
    }

    // Owner sets base URL (e.g., "https://your-api.com/metadata/")
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address o = _owners[tokenId];
        require(o != address(0), "NFA: nonexistent token");
        return o;
    }

    function balanceOf(address user) external view returns (uint256) {
        return _balances[user];
    }

    function getMintedCount(address user) external view returns (uint256) {
        return _mintedCount[user];
    }

    function canMint(address user) public view returns (bool) {
        if (_mintedCount[user] >= mintLimitPerAddress) return false;
        uint256 tokenBalance = IERC20(REQUIRED_TOKEN).balanceOf(user);
        return tokenBalance >= MIN_TOKEN_BALANCE;
    }

    function _mint(address to) internal {
        require(_nextTokenId < MAX_SUPPLY, "NFA: max supply");
        require(_mintedCount[to] < mintLimitPerAddress, "NFA: exceed mint limit per address");
        
        uint256 tokenBalance = IERC20(REQUIRED_TOKEN).balanceOf(to);
        require(tokenBalance >= MIN_TOKEN_BALANCE, "NFA: insufficient token balance");

        uint256 tokenId = _nextTokenId++;

        _owners[tokenId] = to;
        _balances[to]++;
        _mintedCount[to]++;

        emit Transfer(address(0), to, tokenId);

        _states[tokenId] = State({
            balance: 0,
            status: Status.Active,
            owner: to,
            logicAddress: address(0),
            lastActionTimestamp: block.timestamp
        });
    }

    function mint() external {
        _mint(msg.sender);
    }

    function executeAction(uint256 tokenId, bytes calldata data) external override {
        require(ownerOf(tokenId) == msg.sender, "NFA: not owner");

        State storage s = _states[tokenId];
        require(s.status == Status.Active, "NFA: not active");
        require(s.logicAddress != address(0), "NFA: no logic");

        s.lastActionTimestamp = block.timestamp;

        (bool ok, bytes memory result) = s.logicAddress.delegatecall(data);
        require(ok, "NFA: action failed");

        emit ActionExecuted(address(this), result);
    }

    function setLogicAddress(uint256 tokenId, address newLogic) external override {
        require(ownerOf(tokenId) == msg.sender, "NFA: not owner");

        address old = _states[tokenId].logicAddress;
        _states[tokenId].logicAddress = newLogic;

        emit LogicUpgraded(address(this), old, newLogic);
    }

    function fundAgent(uint256 tokenId) external payable override {
        require(_owners[tokenId] != address(0), "NFA: nonexistent");

        _states[tokenId].balance += msg.value;
        emit AgentFunded(address(this), msg.sender, msg.value);
    }

    function getState(uint256 tokenId) external view override returns (State memory) {
        require(_owners[tokenId] != address(0), "NFA: nonexistent");
        return _states[tokenId];
    }

    function getAgentMetadata(uint256 tokenId) external view override returns (AgentMetadata memory) {
        require(_owners[tokenId] != address(0), "NFA: nonexistent");
        return _agentMetadata[tokenId];
    }

    function updateAgentMetadata(uint256 tokenId, AgentMetadata memory metadata) external override {
        require(ownerOf(tokenId) == msg.sender, "NFA: not owner");
        _agentMetadata[tokenId] = metadata;
        emit MetadataUpdated(tokenId, tokenURI(tokenId));
    }

    function pause(uint256 tokenId) external override {
        require(ownerOf(tokenId) == msg.sender, "NFA: not owner");
        _states[tokenId].status = Status.Paused;
        emit StatusChanged(address(this), Status.Paused);
    }

    function unpause(uint256 tokenId) external override {
        require(ownerOf(tokenId) == msg.sender, "NFA: not owner");
        _states[tokenId].status = Status.Active;
        emit StatusChanged(address(this), Status.Active);
    }

    function terminate(uint256 tokenId) external override {
        require(ownerOf(tokenId) == msg.sender, "NFA: not owner");
        _states[tokenId].status = Status.Terminated;
        emit StatusChanged(address(this), Status.Terminated);
    }

    function withdraw() external onlyOwner {
        (bool success, ) = owner().call{value: address(this).balance}("");
        require(success, "NFA: withdraw failed");
    }

    function setMintLimitPerAddress(uint256 newLimit) external onlyOwner {
        require(newLimit > 0, "NFA: limit must be greater than 0");
        uint256 oldLimit = mintLimitPerAddress;
        mintLimitPerAddress = newLimit;
        emit MintLimitUpdated(oldLimit, newLimit);
    }

    // Helper to convert uint256 to string for URI concatenation
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    receive() external payable {}
}