// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMemoryModuleRegistry {
    struct MemoryModule {
        address moduleAddress;
        string metadata;
        bytes32 metadataHash;
        uint256 registrationTime;
        bool isActive;
    }

    event ModuleRegistered(uint256 indexed tokenId, address indexed moduleAddress);
    event ModuleDeactivated(uint256 indexed tokenId, address indexed moduleAddress);

    function registerModule(uint256 tokenId, address moduleAddress, string memory metadata) external;
    function deactivateModule(uint256 tokenId, address moduleAddress) external;
    function verifyModule(uint256 tokenId, address moduleAddress, bytes32 expectedHash) external view returns (bool);
    function getModule(uint256 tokenId, address moduleAddress) external view returns (MemoryModule memory);
}
