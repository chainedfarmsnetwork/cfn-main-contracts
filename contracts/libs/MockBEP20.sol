// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./BaseBEP20.sol";

abstract contract MockBEP20 is BaseBEP20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 supply
    ) public BaseBEP20(name, symbol) {
        _mint(msg.sender, supply);
    }
}
