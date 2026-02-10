// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVaultPermissionManager {
    enum PermissionLevel { READ_ONLY, WRITE, ADMIN, FULL_CONTROL }

    struct Permission {
        address delegate;
        PermissionLevel level;
        uint256 expiryTime;
        bool isActive;
    }

    event AccessDelegated(uint256 indexed tokenId, address indexed delegate, PermissionLevel level, uint256 expiryTime);
    event AccessRevoked(uint256 indexed tokenId, address indexed delegate);

    function delegateAccess(uint256 tokenId, address delegate, PermissionLevel level, uint256 expiryTime) external;
    function revokeAccess(uint256 tokenId, address delegate) external;
    function verifyAccess(uint256 tokenId, address accessor, PermissionLevel requiredLevel) external view returns (bool);
    function getPermission(uint256 tokenId, address delegate) external view returns (Permission memory);
}
