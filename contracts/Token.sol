// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./libs/CustomBEP20.sol";

// Token with Governance.
contract Token is CustomBEP20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 maxSupply
    ) public CustomBEP20(name, symbol, maxSupply) {}

    /// @dev Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}
