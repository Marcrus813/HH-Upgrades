// Implementation
// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Box is Initializable {
    uint256 internal s_value;

    event ValueChanged(uint256 indexed oldValue, uint256 indexed newValue);

    // constructor shouldn't exist! Use `initialize` instead!
    // constructor() {}

    function initialize() public initializer {

    }

    function store(uint256 value) public {
        uint256 oldValue = s_value;
        s_value = value;
        emit ValueChanged(oldValue, value);
    }

    function retrieve() public view returns (uint256 result) {
        result = s_value;
    }

    function version() public pure returns (uint256 ver) {
        ver = 1;
    }
}
