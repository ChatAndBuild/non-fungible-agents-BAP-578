// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MockTarget
 * @dev Mock contract for testing governance proposal execution
 */
contract MockTarget {
    uint256 public value;
    address public lastCaller;
    bool public paused;

    event ValueSet(uint256 newValue, address caller);
    event Paused(address caller);
    event Unpaused(address caller);

    function setValue(uint256 _value) external {
        value = _value;
        lastCaller = msg.sender;
        emit ValueSet(_value, msg.sender);
    }

    function pause() external {
        paused = true;
        lastCaller = msg.sender;
        emit Paused(msg.sender);
    }

    function unpause() external {
        paused = false;
        lastCaller = msg.sender;
        emit Unpaused(msg.sender);
    }

    function getValue() external view returns (uint256) {
        return value;
    }

    function isPaused() external view returns (bool) {
        return paused;
    }
}
