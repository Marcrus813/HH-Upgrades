// Implementation
// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.7;

contract BoxV2 {
    uint256 internal s_value;

    event ValueChanged(uint256 indexed oldValue, uint256 indexed newValue);

    constructor() {}

    function store(uint256 value) public {
        uint256 oldValue = s_value;
        s_value = value;
        emit ValueChanged(oldValue, value);
    }

    function increment() public {
        uint256 oldValue = s_value;
        s_value += 1;
        emit ValueChanged(oldValue, s_value);
    }

    function retrieve() public view returns (uint256 result) {
        result = s_value;
    }

    function version() public pure returns (uint256 ver) {
        ver = 2;
    }
}
