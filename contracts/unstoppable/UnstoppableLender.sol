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

    function flashLoan(uint256 borrowAmount) external nonReentrant {
        // our purpose is to stop the flash loan function from running
        // we need to find places where the function would stop running
        // this is not the place
        require(borrowAmount > 0, "Must borrow at least one token");

        uint256 balanceBefore = damnValuableToken.balanceOf(address(this));
        // we can assume that damnValuableToken is a bug free contract
        // so this place is also fine
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");

        // Ensured by the protocol via the `depositTokens` function
        // this part is suspicious, we get balanceBefore from checking the balance of DVT in the contract
        // while there is another variable poolBalance that tracks the balance as well
        // if we can find a way to make poolBalance not equal to balanceBefore, this function stops
        // we can do this by sending this contract DVT directly without calling depositTokens
        assert(poolBalance == balanceBefore);
        
        // transfer tokens to receiver
        damnValuableToken.transfer(msg.sender, borrowAmount);
        
        // receiver receiveTokens is called which returns the token back to the pool    
        IReceiver(msg.sender).receiveTokens(address(damnValuableToken), borrowAmount);
        
        uint256 balanceAfter = damnValuableToken.balanceOf(address(this));
        // we can assume that damnValuableToken is a bug free contract
        require(balanceAfter >= balanceBefore, "Flash loan hasn't been paid back");
    }
}
