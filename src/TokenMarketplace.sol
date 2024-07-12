// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Token} from "./Token.sol";
import {TokenVesting} from "./TokenVesting.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TokenMarketplace is Ownable {
    Token public token;
    TokenVesting public vestingScheduler;
    AggregatorV3Interface private priceFeed;
    // USDT pegged price of vesting token
    uint256 public immutable PRICE;
    address public immutable USDT_ADDRESS;
    bool private REVOKABLE;

    struct TokenScheme {
        // Vesting period in months
        uint256 vestingPeriod;
        // Cliff period in months
        uint256 vestingCliff;
        // Discount percentage on the token price
        uint256 discountPercentage;
        // Slice period; the time interval in which vesting period is divided into
        uint256 slicePeriod;
    }

    // Listing of available token funding schemes
    TokenScheme[4] public tokenSchemes;

    // Events
    event TokensBought(address indexed buyer, uint256 usdtAmount, uint256 tokenAmount, uint8 scheme);
    event VestingScheduleCreated(address indexed beneficiary, bytes32 scheduleId, uint256 amount, uint8 scheme);
    event VestingRevoked(bytes32 indexed scheduleId);
    event TokensWithdrawn(address indexed beneficiary, bytes32 scheduleId, uint256 amount);

    constructor(
        address _token,
        address _vestingScheduler,
        address _priceFeed,
        address _usdtContract,
        uint256 _price,
        bool _enableRevoking
    ) Ownable(msg.sender) {
        require(_token != address(0), "Invalid token address");
        require(_price > 0, "Invalid price");
        require(_vestingScheduler != address(0), "Invalid vesting scheduler address");
        require(_priceFeed != address(0), "Invalid price feed address");
        token = Token(_token);
        vestingScheduler = TokenVesting(_vestingScheduler);
        priceFeed = AggregatorV3Interface(_priceFeed);
        USDT_ADDRESS = _usdtContract;
        PRICE = _price;
        REVOKABLE = _enableRevoking;

        tokenSchemes[0] = TokenScheme(24, 6, 30, 1 days);
        tokenSchemes[1] = TokenScheme(8, 4, 20, 2 days);
        tokenSchemes[2] = TokenScheme(6, 3, 10, 3 days);
        // Default scheme
        tokenSchemes[3] = TokenScheme(3, 2, 0, 4 days);
    }

    function buyTokensWithDiscount(uint256 _usdtAmt, uint8 _scheme) external returns (bytes32) {
        require(_scheme <= 3, "Invalid scheme");
        TokenScheme memory scheme = tokenSchemes[_scheme];
        uint256 tokenDiscount = scheme.discountPercentage;
        // USDT to be transferred to USDT_ADDRESS
        uint256 discountedUsdt = _usdtAmt - (_usdtAmt * (tokenDiscount / 100));

        int256 price = getPrice();
        // The amount to be transferred to vestingScheduler
        uint256 tokenAmt = (discountedUsdt * uint256(price)) / PRICE;

        // Transfer USDT to USDT_ADDRESS
        IERC20(USDT_ADDRESS).transferFrom(msg.sender, address(vestingScheduler), discountedUsdt);
        // Create VestingSchedule
        bytes32 scheduleId = vestingScheduler.createVestingSchedule(
            msg.sender, tokenAmt, scheme.vestingPeriod, scheme.slicePeriod, scheme.vestingCliff, REVOKABLE
        );

        emit TokensBought(msg.sender, _usdtAmt, tokenAmt, _scheme);
        emit VestingScheduleCreated(msg.sender, scheduleId, tokenAmt, _scheme);

        return scheduleId;
    }

    function revokeVesting(bytes32 _scheduleId) external onlyOwner {
        vestingScheduler.revoke(_scheduleId);
        emit VestingRevoked(_scheduleId);
    }

    function withdrawTokens(bytes32 _scheduleId, uint256 _amt) external {
        vestingScheduler.release(_scheduleId, _amt);
        emit TokensWithdrawn(msg.sender, _scheduleId, _amt);
    }

    // GETTERS

    function getPrice() public view returns (int256) {
        (, int256 price,,,) = priceFeed.latestRoundData();
        return price;
    }

    function getPriceFeed() external view returns (address) {
        return address(priceFeed);
    }

    function isVestingRevokable() external view returns (bool) {
        return REVOKABLE;
    }
}
