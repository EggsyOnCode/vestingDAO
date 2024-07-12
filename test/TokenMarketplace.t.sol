// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Token} from "../src/Token.sol";
import {TokenMarketplace} from "../src/TokenMarketplace.sol";
import {TokenVesting} from "../src/TokenVesting.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract TokenMarketplaceTest is Test {
    TokenMarketplace public marketplace;
    uint256 public fork;
    address public USER = makeAddr("tester");
    MockV3Aggregator public mockAggregator;
    Token public token;
    TokenVesting public vestingScheduler;
    address public usdtAddress = 0x1919F400B861D2169DB60178df9DBc4dfe5a9A45; // USDT contract on Ethereum mainnet
    address public mockPriceFeed;

    function setUp() public {
        // Fork from the Ethereum mainnet
        string memory RPC_URL = vm.envString("RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        // Deploy your contracts
        token = new Token(address(this));
        vestingScheduler = new TokenVesting(address(token));
        mockAggregator = new MockV3Aggregator(8, 2000 * 10 ** 8);
        mockPriceFeed = address(mockAggregator); // Example mock price feed with 2000 USDT per ETH

        marketplace = new TokenMarketplace(
            address(token),
            address(vestingScheduler),
            mockPriceFeed,
            usdtAddress,
            1 * 10 ** 18, // price of token is 1 eth
            true // Enable revoking
        );
        // Transfer ownership of the token to the marketplace
        token.transferOwnership(address(marketplace));
        vestingScheduler.transferOwnership(address(marketplace));
        fundUSER();
    }

    function fundUSER() public {
        // Impersonate a rich USDT account
        address richUSDTAccount = 0x085a958427aaA3Ac8Be6174F630a96641538E280;
        uint256 usdtAmt = 1000 * 10 ** 6; // 1000 USDT with 6 decimals

        vm.startPrank(richUSDTAccount);
        IERC20(usdtAddress).transfer(USER, usdtAmt);
        vm.stopPrank();
    }

    function testBuyTokensWithDiscount() public {
        // Set up test parameters
        uint256 usdtAmt = 1000 * 10 ** 6; // 1000 USDT with 6 decimals
        uint8 scheme = 0; // Choose a vesting scheme
        address buyer = USER;

        // Impersonate an account with USDT
        vm.startPrank(buyer);
        IERC20(usdtAddress).approve(address(marketplace), usdtAmt);

        // Call the buyTokensWithDiscount function
        bytes32 scheduleId = marketplace.buyTokensWithDiscount(usdtAmt, scheme);

        // Assert the expected outcomes
        TokenVesting.VestingSchedule memory schedule = vestingScheduler.getVestingSchedule(scheduleId);
        (, int256 answer,,,) = mockAggregator.latestRoundData();
        emit log_int(answer);
        assertNotEq(schedule.totalAmt, 0);
        assertEq(schedule.totalAmt * 100, 350);

        vm.stopPrank();
    }

    function testReleaseTokens() public {
        uint256 usdtAmt = 1000 * 10 ** 6; // 1000 USDT
        uint8 scheme = 1;

        address buyer = USER;
        vm.startPrank(buyer);

        IERC20(usdtAddress).approve(address(marketplace), usdtAmt);
        bytes32 scheduleId = marketplace.buyTokensWithDiscount(usdtAmt, scheme);
        TokenMarketplace.TokenScheme memory tokenScheme = marketplace.getTokenVestingScheme(scheme);

        // Simulate passing time for cliff and one slice period
        vm.warp(block.timestamp + tokenScheme.vestingCliff + tokenScheme.slicePeriod);

        // Calculate expected release amount
        uint256 expectedReleaseAmount = (1000 * 10 ** 18) / (tokenScheme.vestingPeriod / tokenScheme.slicePeriod);

        // Release tokens
        marketplace.withdrawTokens(scheduleId, expectedReleaseAmount);

        // Assert token balance after release
        uint256 buyerBalance = token.balanceOf(buyer);
        assertEq(buyerBalance, expectedReleaseAmount, "Incorrect release amount");

        vm.stopPrank();
    }

    function testRevokeTokens() public {
        uint256 usdtAmt = 1000 * 10 ** 6; // 1000 USDT
        uint8 scheme = 2;

        address buyer = USER;
        vm.startPrank(buyer);

        IERC20(usdtAddress).approve(address(marketplace), usdtAmt);
        bytes32 scheduleId = marketplace.buyTokensWithDiscount(usdtAmt, scheme);

        // Revoke vesting
        vm.stopPrank();
        vm.startPrank(address(marketplace.owner()));
        marketplace.revokeVesting(scheduleId);

        // Assert that the vesting is revoked
        TokenVesting.VestingSchedule memory schedule = vestingScheduler.getVestingSchedule(scheduleId);
        assertTrue(schedule.revoked, "Vesting should be revoked");

        vm.stopPrank();
    }
}
