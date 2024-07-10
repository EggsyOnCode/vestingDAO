// contracts/MockUSDT.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDT is ERC20 {
    constructor(uint256 initialSupply) ERC20("Mock USDT", "mUSDT") {
        _mint(msg.sender, initialSupply);
    }
}
