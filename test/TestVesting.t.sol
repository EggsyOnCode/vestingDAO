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

    function testReleaseSchedule() public {
        // create a vesting schedule
        uint256 totalAmt = 1000;
        uint256 duration = 30 * 24 * 60 * 60; // 30 days
        uint256 cliff = 10 * 24 * 60 * 60; // 10 days
        uint256 slicePeriod = 1 * 24 * 60 * 60; // 1 day
        uint256 start = block.timestamp;
        bool revocable = true;
        bytes32 vestingScheduleId =
            tVesting.createVestingSchedule(address(this), totalAmt, duration, slicePeriod, cliff, revocable);

        vm.warp(start + 1 * 24 * 60 * 60);
        vm.expectRevert();
        tVesting.release(vestingScheduleId, 4);

        vm.warp(start + cliff + 1 * 24 * 60 * 60);
        tVesting.release(vestingScheduleId, 4);

        TokenVesting.VestingSchedule memory vs = tVesting.getVestingSchedule(vestingScheduleId);
        vm.assertEq(vs.released, 4);
    }

    function testComputeReleasableAmt() public {
        // create a vesting schedule
        uint256 totalAmt = 1000;
        uint256 duration = 30 * 24 * 60 * 60; // 30 days
        uint256 cliff = 10 * 24 * 60 * 60; // 10 days
        uint256 slicePeriod = 1 * 24 * 60 * 60; // 1 day
        uint256 start = block.timestamp;
        bool revocable = true;
        bytes32 vestingScheduleId =
            tVesting.createVestingSchedule(address(this), totalAmt, duration, slicePeriod, cliff, revocable);

        TokenVesting.VestingSchedule memory vs = tVesting.getVestingSchedule(vestingScheduleId);
        vm.warp(start + 9 * 24 * 60 * 60);
        uint256 releasableAmt = tVesting.computeReleasableAmt(vs);
        vm.assertEq(releasableAmt, 0);

        vm.warp(start + 10 * 24 * 60 * 60);
        emit log_uint(block.timestamp - start);
        uint256 rA = tVesting.computeReleasableAmt(vs);
        vm.assertEq(rA, 330);

        vm.warp(start + 15 * 24 * 60 * 60);
        emit log_uint(block.timestamp - start);
        uint256 rA1 = tVesting.computeReleasableAmt(vs);
        vm.assertEq(rA1, 495);

        vm.warp(start + duration);
        emit log_uint(block.timestamp - start);
        uint256 rA2 = tVesting.computeReleasableAmt(vs);
        vm.assertEq(rA2, 1000);

        vm.warp(start + duration + 1 * 24 * 60 * 60);
        emit log_uint(block.timestamp - start);
        uint256 rA3 = tVesting.computeReleasableAmt(vs);
        vm.assertEq(rA3, 1000);
    }

    function testRevoked() public {
        // create a vesting schedule
        uint256 totalAmt = 1000;
        uint256 duration = 30 * 24 * 60 * 60; // 30 days
        uint256 cliff = 10 * 24 * 60 * 60; // 10 days
        uint256 slicePeriod = 1 * 24 * 60 * 60; // 1 day
        uint256 start = block.timestamp;
        bool revocable = true;
        bytes32 vestingScheduleId =
            tVesting.createVestingSchedule(address(this), totalAmt, duration, slicePeriod, cliff, revocable);

        tVesting.revoke(vestingScheduleId);

        TokenVesting.VestingSchedule memory vs = tVesting.getVestingSchedule(vestingScheduleId);
        vm.assertEq(vs.revoked, true);

        vm.warp(start + cliff + 1 * 24 * 60 * 60);
        uint256 rA = tVesting.computeReleasableAmt(vs);
        vm.assertEq(rA, 0);

        vm.expectRevert();
        tVesting.release(vestingScheduleId, 8);
    }
}
