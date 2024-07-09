// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Token} from "./Token.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/console.sol";

contract TokenVesting is ReentrancyGuard, Ownable {
    // state vars

    struct VestingSchedule {
        address beneficiary;
        //total amt to be released
        uint256 totalAmt;
        uint256 released;
        // the total duration of vesting period say 12 Months
        uint256 duration;
        // min period where no tokens are released
        uint256 cliff;
        // slicePeriod interval of time in which duration is equally divided into
        uint256 slicePeriod;
        // time that marks the start of the vesting period
        uint256 start;
        // if the vesting is revocable by the owner
        bool revocable;
        bool revoked;
    }

    Token public immutable token;
    bytes32[] private vestingSchduleIds;
    mapping(bytes32 => VestingSchedule) private vestingSchedules;
    uint256 private totalVestingFunds = 0;
    uint256 public totalVestingSchedules = 0;
    // vesting schedules for an address
    mapping(address => uint256) vestingHoldersCount;

    // events
    event VestingScheduleCreated(bytes32 vestingScheduleId, address indexed beneficiary, uint256 totalAmt);
    event TokensReleased(bytes32 vestingScheduleId, uint256 amt);
    event TokenRevoked(bytes32 vestingScheduleId, uint256 amt);

    // constructor
    constructor(address _tokenAddr) Ownable(msg.sender) {
        require(_tokenAddr != address(0), "Invalid Token Address");
        token = Token(_tokenAddr);
    }

    // modifiers
    modifier notRevoked(bytes32 _scheduleId) {
        require(!vestingSchedules[_scheduleId].revoked, "Vesting Schedule has been revoked");
        _;
    }

    // Public Functions

    function release(bytes32 _scheduleId, uint256 _amt) public nonReentrant notRevoked(_scheduleId) {
        VestingSchedule storage vestingSch = vestingSchedules[_scheduleId];
        require(msg.sender == vestingSch.beneficiary || msg.sender == owner(), "TokenVesting: Invalid Caller");
        require(vestingSch.beneficiary != address(0), "TokenVesting: Invalid Vesting Schedule");
        require(vestingSch.totalAmt > 0, "TokenVesting: No Tokens to release");
        require(block.timestamp >= vestingSch.start, "TokenVesting: Vesting Schedule has not started");
        uint256 releasableAmt = computeReleasableAmt(vestingSch);
        require(releasableAmt > _amt, "TokenVesting : Insufficient releasable amount");

        // TODO: the tokens to be released should be computeReleasable - released
        emit TokensReleased(_scheduleId, _amt);

        vestingSch.released += _amt;
        token.transfer(payable(vestingSch.beneficiary), _amt);
    }

    // External Functions
    function createVestingSchedule(
        address _beneficiary,
        uint256 _totalAmt,
        uint256 _duration,
        uint256 _slicePeriod,
        uint256 _cliff,
        bool _revokable
    ) external onlyOwner returns (bytes32) {
        VestingSchedule memory vestingSchedule = VestingSchedule(
            _beneficiary, _totalAmt, 0, _duration, _cliff, _slicePeriod, block.timestamp, _revokable, false
        );

        bytes32 vestingScheduleId = computeNextVestingScheduleId(_beneficiary);
        vestingSchedules[vestingScheduleId] = vestingSchedule;
        vestingHoldersCount[_beneficiary] += 1;
        totalVestingFunds += _totalAmt;
        emit VestingScheduleCreated(vestingScheduleId, _beneficiary, _totalAmt);
        return vestingScheduleId;
    }

    function revoke(bytes32 _scheduleId) external nonReentrant onlyOwner notRevoked(_scheduleId) {
        VestingSchedule storage vestingSch = vestingSchedules[_scheduleId];
        require(vestingSch.revocable, "TokenVesting: Vesting Schedule is not revocable");
        require(vestingSch.beneficiary != address(0), "TokenVesting: Invalid Vesting Schedule");

        uint256 releasableAmt = computeReleasableAmt(vestingSch);
        if (releasableAmt > 0) {
            release(_scheduleId, releasableAmt);
        }
        uint256 unreleasedAmt = vestingSch.totalAmt - vestingSch.released;
        totalVestingFunds -= unreleasedAmt;
        vestingSch.revoked = true;

        emit TokenRevoked(_scheduleId, unreleasedAmt);
    }

    // Internal Functions
    function computeNextVestingScheduleId(address _holder) internal returns (bytes32) {
        uint256 nextVestingScheduleIndex = vestingHoldersCount[_holder];
        return computeVestingSchduleId(_holder, nextVestingScheduleIndex + 1);
    }

    function computeVestingSchduleId(address _holder, uint256 _vestingSchduleIndex) internal returns (bytes32) {
        return keccak256(abi.encodePacked(_holder, _vestingSchduleIndex));
    }

    function computeReleasableAmt(VestingSchedule memory _vestingSch) public view returns (uint256) {
        if (_vestingSch.revoked) {
            return 0;
        }
        uint256 timePassedSinceCreation = getCurrentTime() - _vestingSch.start;
        if (timePassedSinceCreation < _vestingSch.cliff || _vestingSch.revoked) {
            return 0;
        }
        if (timePassedSinceCreation >= _vestingSch.duration) {
            return _vestingSch.totalAmt - _vestingSch.released;
        } else {
            uint256 slicePeriod = _vestingSch.slicePeriod;
            if (slicePeriod == 0) {
                // Handle the case where slicePeriod is zero
                return 0;
            }
            uint256 releasable = _vestingSch.totalAmt - _vestingSch.released; // 1000
            uint256 iterations = _vestingSch.duration / slicePeriod; // 30
            uint256 pastIterations = timePassedSinceCreation / slicePeriod; // 10
            return (releasable / iterations) * pastIterations;
            // uint256 slicePeriod = _vestingSch.slicePeriod;
            // uint256 releasable = _vestingSch.totalAmt - _vestingSch.released;
            // uint256 iterations = _vestingSch.duration % slicePeriod;
            // uint256 pastIterations = timePassedSinceCreation % slicePeriod;
            // return (releasable / iterations) * pastIterations;
        }
    }

    function getCurrentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    // Getter Functions
    function getVestingSchedule(bytes32 _scheduleId) external view returns (VestingSchedule memory) {
        return vestingSchedules[_scheduleId];
    }
}
