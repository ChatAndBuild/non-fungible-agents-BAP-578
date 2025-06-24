// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "./BEP007.sol";

/**
 * @title VaultPermissionManager
 * @dev Manages permissions for agent vaults
 * Handles cryptographic key-pair delegation for vault access
 */
contract VaultPermissionManager is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using ECDSAUpgradeable for bytes32;

    // BEP007 token contract
    BEP007 public bep007Token;

    // Mapping from token ID to delegated addresses
    mapping(uint256 => mapping(address => bool)) private _delegatedAccess;

    // Mapping from token ID to delegation expiry timestamps
    mapping(uint256 => mapping(address => uint256)) private _delegationExpiry;

    // Events
    event AccessDelegated(uint256 indexed tokenId, address indexed delegate, uint256 expiryTime);
    event AccessRevoked(uint256 indexed tokenId, address indexed delegate);
    event VaultAccessRequested(
        uint256 indexed tokenId,
        address indexed requester,
        bytes32 requestId
    );
    event VaultAccessGranted(uint256 indexed tokenId, address indexed requester, bytes32 requestId);

    /**
     * @dev Initializes the contract
     * @param _bep007Token The address of the BEP007 token contract
     */
    function initialize(address payable _bep007Token) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();

        require(_bep007Token != address(0), "VaultPermissionManager: token is zero address");
        bep007Token = BEP007(_bep007Token);
    }

    /**
     * @dev Delegates vault access to an address
     * @param tokenId The ID of the agent token
     * @param delegate The address to delegate access to
     * @param expiryTime The timestamp when the delegation expires
     * @param signature The signature of the agent owner
     */
    function delegateAccess(
        uint256 tokenId,
        address delegate,
        uint256 expiryTime,
        bytes memory signature
    ) external nonReentrant {
        require(delegate != address(0), "VaultPermissionManager: delegate is zero address");
        require(expiryTime > block.timestamp, "VaultPermissionManager: expiry time in the past");

        // Verify that the token exists
        require(
            bep007Token.ownerOf(tokenId) != address(0),
            "VaultPermissionManager: token does not exist"
        );

        // Get the owner of the token
        address owner = bep007Token.ownerOf(tokenId);

        // Verify the signature
        bytes32 messageHash = keccak256(abi.encodePacked(tokenId, delegate, expiryTime));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        address signer = ethSignedMessageHash.recover(signature);

        require(signer == owner, "VaultPermissionManager: invalid signature");

        // Grant access
        _delegatedAccess[tokenId][delegate] = true;
        _delegationExpiry[tokenId][delegate] = expiryTime;

        emit AccessDelegated(tokenId, delegate, expiryTime);
    }

    /**
     * @dev Revokes vault access from an address
     * @param tokenId The ID of the agent token
     * @param delegate The address to revoke access from
     */
    function revokeAccess(uint256 tokenId, address delegate) external {
        // Only the token owner can revoke access
        require(
            bep007Token.ownerOf(tokenId) == msg.sender,
            "VaultPermissionManager: not token owner"
        );

        _delegatedAccess[tokenId][delegate] = false;
        _delegationExpiry[tokenId][delegate] = 0;

        emit AccessRevoked(tokenId, delegate);
    }

    /**
     * @dev Requests access to a vault
     * @param tokenId The ID of the agent token
     * @return requestId A unique ID for the access request
     */
    function requestVaultAccess(uint256 tokenId) external returns (bytes32 requestId) {
        // Generate a unique request ID
        requestId = keccak256(abi.encodePacked(tokenId, msg.sender, block.timestamp));

        emit VaultAccessRequested(tokenId, msg.sender, requestId);

        return requestId;
    }

    /**
     * @dev Grants access to a vault
     * @param tokenId The ID of the agent token
     * @param requester The address requesting access
     * @param requestId The ID of the access request
     * @param signature The signature of the agent owner
     */
    function grantVaultAccess(
        uint256 tokenId,
        address requester,
        bytes32 requestId,
        bytes memory signature
    ) external {
        // Verify that the token exists
        require(
            bep007Token.ownerOf(tokenId) != address(0),
            "VaultPermissionManager: token does not exist"
        );

        // Get the owner of the token
        address owner = bep007Token.ownerOf(tokenId);

        // Verify the signature
        bytes32 messageHash = keccak256(abi.encodePacked(tokenId, requester, requestId));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        address signer = ethSignedMessageHash.recover(signature);

        require(signer == owner, "VaultPermissionManager: invalid signature");

        emit VaultAccessGranted(tokenId, requester, requestId);
    }

    /**
     * @dev Checks if an address has access to a vault
     * @param tokenId The ID of the agent token
     * @param delegate The address to check
     * @return Whether the address has access
     */
    function hasVaultAccess(uint256 tokenId, address delegate) external view returns (bool) {
        // The owner always has access
        if (bep007Token.ownerOf(tokenId) == delegate) {
            return true;
        }

        // Check if the address has delegated access and it hasn't expired
        return
            _delegatedAccess[tokenId][delegate] &&
            _delegationExpiry[tokenId][delegate] > block.timestamp;
    }

    /**
     * @dev Gets the expiry time of a delegation
     * @param tokenId The ID of the agent token
     * @param delegate The delegated address
     * @return The expiry timestamp
     */
    function getDelegationExpiry(
        uint256 tokenId,
        address delegate
    ) external view returns (uint256) {
        return _delegationExpiry[tokenId][delegate];
    }
}
