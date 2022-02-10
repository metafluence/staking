// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * IStake interface display required methods any Staker smart contracts
 */
interface IStakeable {
    function stake(uint256 amount) external;
    function claim(uint _id) external;
    
    event Stake(address indexed staker, uint256 _amount);
    event Unstake(address indexed staker);
}