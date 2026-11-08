//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IRebaseToken} from "./Interfaces/IRebaseToken.sol";

contract Vault {
    //we need to pass the token address to the constructor
    //create a deposit funciton that mints tokens to the user.
    //create a redeem function that burns tokens from the user and sends the user ETH.

    error Vault__RedeemFailed();

    IRebaseToken private immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    /**
     * @notice deposits ETH into the vault and mints rebase tokens to the user.
     */
    function deposit() external payable {
        // 1. we need to use amount of ETH the user has sent to mint tokens to the user.
        uint256 interestRate = i_rebaseToken.getInterestRate();
        i_rebaseToken.mint(msg.sender, msg.value, interestRate);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice allows the users to redeem their rebase tokens for ETH.
     * @param _amount the amount of rebase tokens to redeem.
     */
    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        //1. burn the user's rebase tokens.
        i_rebaseToken.burn(msg.sender, _amount);
        //2. send ETH to the user.
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    /**
     * @notice gets the address of the rebase tokens.
     * @return the address of the rebase token.
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}
