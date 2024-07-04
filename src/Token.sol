// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC20, Ownable {
    constructor(address initialOwner) ERC20("Vesting", "VT") Ownable(initialOwner) {}

    function mint(uint256 amt, address to) public onlyOwner {
        _mint(to, amt);
    }
}
