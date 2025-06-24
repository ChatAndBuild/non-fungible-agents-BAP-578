// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MockExperienceModule
 * @dev Mock contract for testing experience module functionality
 */
contract MockExperienceModule {
    string public name;
    string public version;

    event ExperienceProcessed(bytes data, bool success);

    constructor(string memory _name, string memory _version) {
        name = _name;
        version = _version;
    }

    function getName() external view returns (string memory) {
        return name;
    }

    function getVersion() external view returns (string memory) {
        return version;
    }

    function processExperience(bytes calldata data) external returns (bool) {
        bool success = data.length > 0;
        emit ExperienceProcessed(data, success);
        return success;
    }

    function updateName(string memory _name) external {
        name = _name;
    }

    function updateVersion(string memory _version) external {
        version = _version;
    }

    function getInfo() external view returns (string memory, string memory) {
        return (name, version);
    }
}
