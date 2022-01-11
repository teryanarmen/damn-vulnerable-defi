// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IReceiver {
    function receiveTokens(address tokenAddress, uint256 amount) external;
}

/**
 * @title UnstoppableLender
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract UnstoppableLender is ReentrancyGuard {
    IERC20 public immutable damnValuableToken;
    uint256 public poolBalance;

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "Token address cannot be zero");
        damnValuableToken = IERC20(tokenAddress);
    }

    function depositTokens(uint256 amount) external nonReentrant {
        require(amount > 0, "Must deposit at least one token");
        // Transfer token from sender. Sender must have first approved them.
        damnValuableToken.transferFrom(msg.sender, address(this), amount);
        poolBalance = poolBalance + amount;
    }

    // how to stop a lender from giving flash loans
    // 1. Drain the contract (balance >= borrow > 0)
    // 2. Make poolBalance != borrowAmount
    //  a. pay the contract so balanceOf(contract) > poolBalance

    function flashLoan(uint256 borrowAmount) external nonReentrant {
        // revert if borrowAmount <= 0, cant do anything about this
        require(borrowAmount > 0, "Must borrow at least one token");

        uint256 balanceBefore = damnValuableToken.balanceOf(address(this));
        // revert if not enough money to allow borrowing, potential avenue
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");

        // Ensured by the protocol via the `depositTokens` function
        // ^ big hint? make this fail? mess with depositTokens function?
        // ^ yup, just send the contract money so that poolBalance is less
        // than than balance Before since it only adds value when a borrow
        // is repaid using depositTokens and doesnt add when getting paid
        // normally
        assert(poolBalance == balanceBefore);

        // transfer fails? but its someone else not me, cant write their recieve function
        damnValuableToken.transfer(msg.sender, borrowAmount);

        // take tokens from sender, cant thing of how to break this
        IReceiver(msg.sender).receiveTokens(
            address(damnValuableToken),
            borrowAmount
        );

        // requires >= balance, somehow get less balance no matter what? idk
        uint256 balanceAfter = damnValuableToken.balanceOf(address(this));
        require(
            balanceAfter >= balanceBefore,
            "Flash loan hasn't been paid back"
        );
    }
}
