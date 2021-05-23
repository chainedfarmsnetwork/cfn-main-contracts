// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./BaseBEP20.sol";

contract MockBEP20 is BaseBEP20 {
    uint256 private _currentBurnPercent = 0;

    constructor(
        string memory name,
        string memory symbol,
        uint256 supply
    ) public BaseBEP20(name, symbol) {
        _mint(msg.sender, supply);
    }

    /**
     * @dev Returns the current burned percent per transfert.
     */
    function getCurrentBurnPercent() external view override returns (uint256) {
        return _currentBurnPercent;
    }
}
