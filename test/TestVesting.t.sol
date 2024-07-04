// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Token} from "../src/Token.sol";
import {TokenVesting} from "../src/TokenVesting.sol";

contract TestVesting is Test {
    Token private i_token;
    TokenVesting private tVesting;
    uint256 public constant TOKEN_AMT = 10000;

    function setUp() public {
        i_token = new Token(address(this));
        tVesting = new TokenVesting(address(i_token));
        i_token.mint(TOKEN_AMT, address(tVesting));
        i_token.transferOwnership(address(tVesting));
    }

    function testVestingSchedule() public {
        // create a vesting schedule
        uint256 totalAmt = 1000;
        uint256 duration = 12;
        uint256 cliff = 3;
        uint256 slicePeriod = 1;
        uint256 start = block.timestamp;
        bool revocable = true;
        bytes32 vestingScheduleId =
            tVesting.createVestingSchedule(address(this), totalAmt, duration, slicePeriod, cliff, revocable);
        // check the vesting schedule
        TokenVesting.VestingSchedule memory vs = tVesting.getVestingSchedule(vestingScheduleId);
        assertEq(vs.beneficiary, address(this));
        assertEq(vs.totalAmt, totalAmt);
        assertEq(vs.released, 0);
        assertEq(vs.duration, duration);
        assertEq(vs.cliff, cliff);
        assertEq(vs.slicePeriod, slicePeriod);
        assertEq(vs.start, start);
        assertEq(vs.revocable, revocable);
        assertEq(vs.revoked, false);
    }

}
