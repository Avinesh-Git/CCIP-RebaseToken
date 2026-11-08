//SPDX-License-Identifier:MIT

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title CCIP Rebase Token
 * @author Avinesh
 * @notice This is a cross chain rebase token that incentivises users to deposit token into a vault and gain interest in rewards.
 * @notice The interest rate in this contract can only decrease.
 * @notice Each user will have their own interest rate that is the global interest rate at the time of deposit.
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private s_interestRate = (5 * PRECISION_FACTOR) / 1e8; // Interest rate in basis points (e.g., 100 = 1%)
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");

    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_usersLastUpdatedTimeStamp;

    event InterestRateSet(uint256 _newInterestRate);

    constructor() ERC20("RebaseToken", "RBT") Ownable(msg.sender) {}

    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * @notice sets the interest rate in the contract.
     * @param _newInterestRate The new interest rate to set.
     * @dev the interest rate can only decrease.
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;

        emit InterestRateSet(_newInterestRate);
    }

    /**
     * @notice gets the principle balance of a user. the number of tokens currently minted to the user.
     * without including any interest.
     * @param _user the user to get the principle balance for.
     * @return linearInterest principle balance of the user.
     */
    function principleBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    /**
     * @notice mint the user tokes when they deposit into the vault.
     * @param _to the user to mint the tokens to.
     * @param _amount the amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = _userInterestRate;
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * calculates the balance for the user including the interest that has accumulated since the last update.
     * (pincliple balance) + interest accrued.
     * @param _user the user to calculate the balance for.
     * @return the balance for the user including the interest that has accumulated since the last update
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // get the currrent principle balance of the user.(the no.of tokens that have been minted to the user)
        // multiply the principle balance by the interest that have accumulated in the time since the balance was last updated.
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    /**
     * @notice transfer tokens from one to another.
     * @param _recipient the recipient of the token transfer.
     * @param _amount the amount of tokens to transfer.
     * @return true if the transfer was successful.
     */
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }

        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }

        return super.transfer(_recipient, _amount);
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }

        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    /**
     * @notice calculates the interest that has accumulated since the last update for the user.
     * @param _user The user to calculate the interest accumulated for.
     * @return linearInterest .
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        //we need to calculate the the interest that has accumulated since last update.
        // this is goin to be linear growth with time
        // 1. calculate the time since last update.
        // 2. calculate the amount of linear growth.
        // eg: deposit: 10 tokens, the interest rate is 0.5 tokens per sec, the time elapsed is 2sec
        // then 10 + (10 * 0.5 * 2) is:
        // principle amount + (1 * interest rate * time elapsed)
        uint256 timeElapsed = block.timestamp - s_usersLastUpdatedTimeStamp[_user];
        linearInterest = (PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed));
    }

    /**
     * @notice mints the accrued interest to the user from since last interaction (eg: burn, mint ..).
     * @param _user The user to mint the accrued interest to.
     */
    function _mintAccruedInterest(address _user) internal {
        //1.find their current balanceOf rebase tokens that have been minted -> pinciple balance.
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        //2.calculate their current balance including interest -> balanceOf.
        uint256 currentBalance = balanceOf(_user);
        //3.calculate the number of tokens that need to be minted to the user.
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;
        // call _mint to mint the tokens to the user.
        _mint(_user, balanceIncrease);
        // set the user's last updated time stamp.
        s_usersLastUpdatedTimeStamp[_user] = block.timestamp;
    }

    /**
     * @notice gets the current interest rate for the user.
     * @param _user The user to get the interest rate for.
     * @return The current interest rate for the user.
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }

    /**
     * @notice gets the global interest rate. any future deposits will will be assigned this interest rate.
     * @return The global interest rate from the contract.
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }
}
