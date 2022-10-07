// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * IStake interface display required methods any Staker smart contracts
 */
interface IStakeableSuperPool {
    function stake(uint256 amount) external;
    function claim(uint _id) external;
    function claimAll(uint _id) external;
    
    event Stake(address indexed staker, uint256 _amount);
    event Claim(address indexed staker);
    event ClaimAll(address indexed staker);
}