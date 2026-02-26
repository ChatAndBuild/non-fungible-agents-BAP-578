// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

/// @title Minimal Ownable (no OpenZeppelin)
contract Ownable {
    address private _owner;
    address private _pendingOwner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

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

    function pendingOwner() public view returns (address) {
        return _pendingOwner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Owner: zero address");
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(_owner, newOwner);
    }

    function acceptOwnership() external {
        require(msg.sender == _pendingOwner, "Owner: not pending owner");
        address oldOwner = _owner;
        _owner = _pendingOwner;
        _pendingOwner = address(0);
        emit OwnershipTransferred(oldOwner, _owner);
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
    event ContractPaused(bool paused);
    event AllowedLogicContractUpdated(address indexed logic, bool allowed);
    event BaseURIUpdated(string previousBaseURI, string newBaseURI);
    event SignerAddressUpdated(address indexed oldSigner, address indexed newSigner);
    event OwnerWithdrawal(address indexed owner, uint256 amount);
    event AgentWithdrawn(uint256 indexed tokenId, address indexed recipient, uint256 amount);
    event AgentActionExecuted(uint256 indexed tokenId, bytes result);
    event AgentLogicUpgraded(uint256 indexed tokenId, address oldLogic, address newLogic);
    event AgentFundedByToken(uint256 indexed tokenId, address indexed funder, uint256 amount);
    event AgentStatusChanged(uint256 indexed tokenId, Status newStatus);

    string public constant NAME = "Non-Fungible Agent";
    string public constant SYMBOL = "NFA";

    uint256 public constant MAX_SUPPLY = 10000;
    uint256 private _nextTokenId;
    uint256 private _burnedTokenCount;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;

    // ERC721 Approvals
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    address public signerAddress;
    mapping(address => uint256) public nonces;

    uint256 public mintLimitPerAddress;
    mapping(address => uint256) private _mintedCount;
    bool public paused;

    // Logic Governance
    mapping(address => bool) public allowedLogicContracts;

    // ERC20 token requirements
    address public immutable REQUIRED_TOKEN;
    uint256 public constant MIN_TOKEN_BALANCE = 10000 * 10 ** 18;

    // Simplified metadata - only base URI + token ID
    string public baseURI;

    mapping(uint256 => State) private _states;
    mapping(uint256 => AgentMetadata) private _agentMetadata;
    uint256 private _totalAgentFunds;
    bool private _locked;

    // EIP-712
    bytes32 public constant MINT_REQUEST_TYPEHASH =
        keccak256("MintRequest(address wallet,uint256 nonce,uint256 expiry)");
    uint256 private constant _SECP256K1_HALF_ORDER =
        0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;
    bytes32 private constant _EIP712_DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
    uint256 private immutable _initialChainId;
    bytes32 private immutable _initialDomainSeparator;

    struct MintRequest {
        address wallet;
        uint256 nonce;
        uint256 expiry;
    }

    modifier nonReentrant() {
        require(!_locked, "NFA: reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor(address _requiredToken) Ownable() {
        require(_requiredToken != address(0), "NFA: zero address token");
        REQUIRED_TOKEN = _requiredToken;

        signerAddress = msg.sender;
        mintLimitPerAddress = 2;
        _initialChainId = block.chainid;
        _initialDomainSeparator = _buildDomainSeparator(block.chainid);
    }

    // ERC165
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165
            interfaceId == 0x80ac58cd || // ERC721
            interfaceId == 0x5b5e139f; // ERC721Metadata
    }

    function name() public pure returns (string memory) {
        return NAME;
    }

    function symbol() public pure returns (string memory) {
        return SYMBOL;
    }

    // Core ERC721 Metadata function for marketplaces
    function tokenURI(uint256 tokenId) public view returns (string memory) {
        require(_owners[tokenId] != address(0), "NFA: nonexistent token");
        return bytes(baseURI).length > 0 ? string.concat(baseURI, _toString(tokenId)) : "";
    }

    // Owner sets base URL (e.g., "https://your-api.com/metadata/")
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        string memory oldBaseURI = baseURI;
        baseURI = newBaseURI;
        emit BaseURIUpdated(oldBaseURI, newBaseURI);
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address o = _owners[tokenId];
        require(o != address(0), "NFA: nonexistent token");
        return o;
    }

    function balanceOf(address user) external view returns (uint256) {
        require(user != address(0), "NFA: zero address");
        return _balances[user];
    }

    function totalSupply() external view returns (uint256) {
        return _nextTokenId - _burnedTokenCount;
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
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "NFA: caller is not token owner or approved"
        );
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "NFA: caller is not token owner or approved"
        );
        _transfer(from, to, tokenId);
        require(
            _checkOnERC721Received(from, to, tokenId, data),
            "NFA: transfer to non ERC721Receiver implementer"
        );
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner ||
            isApprovedForAll(owner, spender) ||
            getApproved(tokenId) == spender);
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

        // Keep ERC721 owner and tracked state owner consistent.
        _states[tokenId].owner = to;
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (
                bytes4 retval
            ) {
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
    function mint(MintRequest calldata req, bytes calldata signature) external whenNotPaused {
        require(req.wallet == msg.sender, "NFA: wallet mismatch");
        require(req.expiry > block.timestamp, "NFA: signature expired");
        require(nonces[msg.sender] == req.nonce, "NFA: invalid nonce");
        require(signerAddress != address(0), "NFA: signer not set");

        // Verify Signature using EIP-712
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(MINT_REQUEST_TYPEHASH, req.wallet, req.nonce, req.expiry))
            )
        );

        address recovered = _recover(digest, signature);
        require(recovered != address(0) && recovered == signerAddress, "NFA: invalid signature");

        // Increment nonce
        nonces[msg.sender]++;

        _mint(msg.sender);
    }

    function executeAction(uint256 tokenId, bytes calldata data) external override nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "NFA: not owner");

        State storage s = _states[tokenId];
        require(s.status == Status.Active, "NFA: not active");
        require(s.logicAddress != address(0), "NFA: no logic");

        s.lastActionTimestamp = block.timestamp;

        (bool ok, bytes memory result) = s.logicAddress.call(data);
        if (!ok) {
            if (result.length == 0) {
                revert("NFA: action failed");
            }
            /// @solidity memory-safe-assembly
            assembly {
                revert(add(32, result), mload(result))
            }
        }

        emit AgentActionExecuted(tokenId, result);
    }

    function setAllowedLogicContract(address logic, bool allowed) external onlyOwner {
        require(logic != address(0), "NFA: zero address logic");
        allowedLogicContracts[logic] = allowed;
        emit AllowedLogicContractUpdated(logic, allowed);
    }

    function setLogicAddress(uint256 tokenId, address newLogic) external override {
        require(ownerOf(tokenId) == msg.sender, "NFA: not owner");
        require(allowedLogicContracts[newLogic], "NFA: logic contract not allowed");

        address old = _states[tokenId].logicAddress;
        _states[tokenId].logicAddress = newLogic;

        emit AgentLogicUpgraded(tokenId, old, newLogic);
    }

    function fundAgent(uint256 tokenId) external payable override whenNotPaused {
        require(_owners[tokenId] != address(0), "NFA: nonexistent");
        require(_states[tokenId].status != Status.Terminated, "NFA: terminated");
        require(msg.value > 0, "NFA: zero value");

        _states[tokenId].balance += msg.value;
        _totalAgentFunds += msg.value;
        emit AgentFundedByToken(tokenId, msg.sender, msg.value);
    }

    function withdrawFromAgent(uint256 tokenId, uint256 amount) external nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "NFA: not owner");
        require(amount > 0, "NFA: zero amount");
        require(_states[tokenId].balance >= amount, "NFA: insufficient");

        _states[tokenId].balance -= amount;
        _totalAgentFunds -= amount;

        (bool success, ) = msg.sender.call{ value: amount }("");
        require(success, "NFA: withdraw failed");
        emit AgentWithdrawn(tokenId, msg.sender, amount);
    }

    function burn(uint256 tokenId) external {
        address tokenOwner = ownerOf(tokenId);
        require(tokenOwner == msg.sender, "NFA: not owner");
        require(_states[tokenId].balance == 0, "NFA: non-zero balance");

        delete _tokenApprovals[tokenId];
        _balances[tokenOwner] -= 1;
        delete _owners[tokenId];
        delete _states[tokenId];
        delete _agentMetadata[tokenId];
        _burnedTokenCount += 1;

        emit Transfer(tokenOwner, address(0), tokenId);
    }

    function getState(uint256 tokenId) external view override returns (State memory) {
        require(_owners[tokenId] != address(0), "NFA: nonexistent");
        return _states[tokenId];
    }

    function getAgentMetadata(
        uint256 tokenId
    ) external view override returns (AgentMetadata memory) {
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
        require(_states[tokenId].status == Status.Active, "NFA: not active");
        _states[tokenId].status = Status.Paused;
        emit AgentStatusChanged(tokenId, Status.Paused);
    }

    function unpause(uint256 tokenId) external override {
        require(ownerOf(tokenId) == msg.sender, "NFA: not owner");
        require(_states[tokenId].status == Status.Paused, "NFA: not paused");
        _states[tokenId].status = Status.Active;
        emit AgentStatusChanged(tokenId, Status.Active);
    }

    function terminate(uint256 tokenId) external override {
        require(ownerOf(tokenId) == msg.sender, "NFA: not owner");
        require(_states[tokenId].status != Status.Terminated, "NFA: terminated");
        _states[tokenId].status = Status.Terminated;
        emit AgentStatusChanged(tokenId, Status.Terminated);
    }

    function setPaused(bool pausedState) external onlyOwner {
        paused = pausedState;
        emit ContractPaused(pausedState);
    }

    function setSignerAddress(address newSigner) external onlyOwner {
        require(newSigner != address(0), "NFA: zero signer");
        address oldSigner = signerAddress;
        signerAddress = newSigner;
        emit SignerAddressUpdated(oldSigner, newSigner);
    }

    function withdraw() external onlyOwner nonReentrant {
        uint256 ownerBalance = address(this).balance - _totalAgentFunds;
        require(ownerBalance > 0, "NFA: nothing to withdraw");
        (bool success, ) = owner().call{ value: ownerBalance }("");
        require(success, "NFA: withdraw failed");
        emit OwnerWithdrawal(owner(), ownerBalance);
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

        if (uint256(s) > _SECP256K1_HALF_ORDER) {
            return address(0);
        }
        if (v != 27 && v != 28) {
            return address(0);
        }

        return ecrecover(digest, v, r, s);
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        if (block.chainid == _initialChainId) {
            return _initialDomainSeparator;
        }
        return _buildDomainSeparator(block.chainid);
    }

    function _buildDomainSeparator(uint256 chainId) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _EIP712_DOMAIN_TYPEHASH,
                    keccak256(bytes(NAME)),
                    keccak256(bytes("1")),
                    chainId,
                    address(this)
                )
            );
    }

    receive() external payable {
        revert("NFA: use fundAgent");
    }
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}
