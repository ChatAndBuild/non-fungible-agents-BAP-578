// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @notice Minimal mock implementing the ILogicModuleForwardable surface.
///         Records the last call and lets tests assert on (tokenId, action, data).
contract MockLogicModule {
    uint256 public lastTokenId;
    string public lastAction;
    bytes public lastData;
    address public lastCaller;
    bool public revertNext;
    string public revertMessage;

    function setRevertNext(bool on, string calldata message) external {
        revertNext = on;
        revertMessage = message;
    }

    function handleAction(
        uint256 tokenId,
        string calldata action,
        bytes calldata data
    ) external returns (bytes memory) {
        if (revertNext) {
            revertNext = false;
            revert(bytes(revertMessage).length == 0 ? "MockLogicModule: forced revert" : revertMessage);
        }
        lastTokenId = tokenId;
        lastAction = action;
        lastData = data;
        lastCaller = msg.sender;
        return abi.encode(true);
    }
}
