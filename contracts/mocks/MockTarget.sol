// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MockTarget
 * @dev Mock contract for testing governance proposal execution
 */
contract MockTarget {
    uint256 public value;

    event ValueSet(uint256 newValue);

    constructor() {
        value = 0;
    }

    function setValue(uint256 _value) external {
        value = _value;
        emit ValueSet(_value);
    }

    function getValue() external view returns (uint256) {
        return value;
    }

    function increment() external {
        value++;
        emit ValueSet(value);
    }

    function decrement() external {
        require(value > 0, "MockTarget: value cannot be negative");
        value--;
        emit ValueSet(value);
    }

    function reset() external {
        value = 0;
        emit ValueSet(0);
    }
}
