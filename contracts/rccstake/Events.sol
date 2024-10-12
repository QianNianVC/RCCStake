// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev
 */
contract Events {

    event SetRCC(IERC20 indexed RCC);
    event PauseWithdraw();
    event UnpauseWithdraw();
    event PauseClaim();
    event UnpauseClaim();
    event SetStartBlock(uint256 indexed startBlock);
    event SetEndBlock(uint256 indexed endBlock);
    event SetRCCPerBlock(uint256 indexed RCCPerBlock);
    event AddPool(address indexed stTokenAddress, uint256 indexed poolWeight, uint256 indexed lastRewardBlock, uint256 minDepositAmount, uint256 unstakeLockedBlocks);
    event UpdatePoolInfo(uint256 indexed poolId, uint256 indexed minDepositAmount, uint256 indexed unstakeLockedBlocks);
    event SetPoolWeight(uint256 indexed poolId, uint256 indexed poolWeight, uint256 totalPoolWeight);
    event UpdatePool(uint256 indexed poolId, uint256 indexed lastRewardBlock, uint256 totalRCC);
    event Deposit(address indexed user, uint256 indexed poolId, uint256 amount);
    event RequestUnstake(address indexed user, uint256 indexed poolId, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed poolId, uint256 amount, uint256 indexed blockNumber);
    event Claim(address indexed user, uint256 indexed poolId, uint256 RCCReward);

}
