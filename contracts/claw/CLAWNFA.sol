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
    // ERC721 Events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    string public name = "Non-Fungible Agent";
    string public symbol = "NFA";

    uint256 public constant MAX_SUPPLY = 1000;
    uint256 private _nextTokenId;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    
    // ERC721 Approvals
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    address public signerAddress;
    mapping(address => uint256) public nonces;
    
    uint256 public mintLimitPerAddress;
    mapping(address => uint256) private _mintedCount;

    // Logic Governance
    mapping(address => bool) public allowedLogicContracts;

    // ERC20 token requirements
    address public immutable REQUIRED_TOKEN;
    uint256 public constant MIN_TOKEN_BALANCE = 10000 * 10 ** 18;

    // Simplified metadata - only base URI + token ID
    string public baseURI;

    mapping(uint256 => State) private _states;
    mapping(uint256 => AgentMetadata) private _agentMetadata;

    // EIP-712
    bytes32 public DOMAIN_SEPARATOR;
    bytes32 public constant MINT_REQUEST_TYPEHASH = keccak256("MintRequest(address wallet,uint256 nonce,uint256 expiry)");

    struct MintRequest {
        address wallet;
        uint256 nonce;
        uint256 expiry;
    }

    constructor(address _requiredToken) Ownable() {
        require(_requiredToken != address(0), "NFA: zero address token");
        REQUIRED_TOKEN = _requiredToken;
        
        signerAddress = msg.sender;
        mintLimitPerAddress = 2;

        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
    }

    // ERC165
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165
            interfaceId == 0x80ac58cd || // ERC721
            interfaceId == 0x5b5e139f;   // ERC721Metadata
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

    // ERC721 Approvals
    function approve(address to, uint256 tokenId) public {
        address owner = ownerOf(tokenId);
        require(to != owner, "NFA: approval to current owner");
        require(msg.sender == owner || isApprovedForAll(owner, msg.sender), "NFA: not authorized");

        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        require(_owners[tokenId] != address(0), "NFA: nonexistent token");
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public {
        require(operator != msg.sender, "NFA: approve to caller");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    // ERC721 Transfers
    function transferFrom(address from, address to, uint256 tokenId) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "NFA: caller is not token owner or approved");
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "NFA: caller is not token owner or approved");
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "NFA: transfer to non ERC721Receiver implementer");
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "NFA: transfer from incorrect owner");
        require(to != address(0), "NFA: transfer to the zero address");

        // Clear approvals
        delete _tokenApprovals[tokenId];

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
        
        // Update State owner
        if (_states[tokenId].status != Status.Terminated) {
            _states[tokenId].owner = to;
        }
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("NFA: transfer to non ERC721Receiver implementer");
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
        return true;
    }

    // BAP + Minting 

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

    /**
     * @notice Mint with EIP-712 Signature
     */
    function mint(MintRequest calldata req, bytes calldata signature) external {
        require(req.wallet == msg.sender, "NFA: wallet mismatch");
        require(req.expiry > block.timestamp, "NFA: signature expired");
        require(nonces[msg.sender] == req.nonce, "NFA: invalid nonce");

        // Verify Signature using EIP-712
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(MINT_REQUEST_TYPEHASH, req.wallet, req.nonce, req.expiry))
            )
        );

        address recovered = _recover(digest, signature);
        require(recovered == signerAddress, "NFA: invalid signature");

        // Increment nonce
        nonces[msg.sender]++;

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

    function setAllowedLogicContract(address logic, bool allowed) external onlyOwner {
        allowedLogicContracts[logic] = allowed;
    }

    function setLogicAddress(uint256 tokenId, address newLogic) external override {
        require(ownerOf(tokenId) == msg.sender, "NFA: not owner");
        require(allowedLogicContracts[newLogic], "NFA: logic contract not allowed");

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

    function setSignerAddress(address newSigner) external onlyOwner {
        signerAddress = newSigner;
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

    function _recover(bytes32 digest, bytes memory signature) internal pure returns (address) {
        if (signature.length != 65) {
            return address(0);
        }

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        return ecrecover(digest, v, r, s);
    }

    receive() external payable {}
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}