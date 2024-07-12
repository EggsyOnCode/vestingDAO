// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Token} from "./Token.sol";
import {TokenVesting} from "./TokenVesting.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggergatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract TokenMarketplace {
    Token public token;
    TokenVesting public vestingScheduler;
    AggregatorV3Interface private priceFeed;
    // usdt pegged price of vesting token
    uint256 public constant PRICE;
    address public immutable USDT_ADDRESS;

    struct TokenScheme {
        // vesting period in months
        uint256 vestingPeriod;
        // cliff period in months
        uint256 vestingCliff;
        // discount percentage on the token price
        uint256 discountPercentage;
    }

    TokenScheme[4] public tokenSchemes;

    constructor(address _token, address _vestingScheduler, address _priceFeed, address _usdtContract) {
        require(_token != address(0), "Invalid token address");
        require(_vestingScheduler != address(0), "Invalid vesting scheduler address");
        require(_priceFeed != address(0), "Invalid price feed address");
        token = Token(_token);
        // trasnfer ownership of token to this contract
        vestingScheduler = TokenVesting(_vestingScheduler);
        priceFeed = AggregatorV3Interface(_priceFeed);
        USDT_ADDRESS = _usdtContract;

        tokenSchemes[0] = TokenScheme(24, 6, 30);
        tokenSchemes[1] = TokenScheme(12, 3, 20);
        tokenSchemes[2] = TokenScheme(6, 1, 10);
        // default scheme
        // tokenSchemes[3] = TokenScheme(, 1, 10);
    }

    function buyTokensWithDiscount(uint256 _usdtAmt, uint8 _scheme) external {
        require(_scheme < 3, "Invalid scheme");
        int256 price = getPrice();
        uint256 tokenAmt = (usdtAmt * uint256(price)) / PRICE;
        uint256 discount = (tokenAmt * tokenSchemes[_scheme].discountPercentage) / 100;
        tokenAmt -= discount;
        IERC20(USDT_ADDRESS).transferFrom(msg.sender, address(vestingScheduler), _usdtAmt);
    }

    function getPrice() external view returns (int256) {
        (, int256 price,,,) = priceFeed.latestRoundData();
        return price;
    }

    function getPriceFeed() external view returns (address) {
        return address(priceFeed);
    }
}
