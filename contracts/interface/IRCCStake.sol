// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRCCStake {
    function setRCC(IERC20 _RCC) external;
    function pauseWithdraw() external;
    function unpauseWithdraw() external;
    function pauseClaim() external;
    function unpauseClaim() external;
    function setStartBlock(uint256 _startBlock) external;
    function setEndBlock(uint256 _endBlock) external;
    function setRCCPerBlock(uint256 _RCCPerBlock) external;
    function addPool(address _stTokenAddress, uint256 _poolWeight, uint256 _minDepositAmount, uint256 _unstakeLockedBlocks, bool _withUpdate) external;
    function updatePool(uint256 _pid, uint256 _minDepositAmount, uint256 _unstakeLockedBlocks) external;
    function setPoolWeight(uint256 _pid, uint256 _poolWeight, bool _withUpdate) external;
    function poolLength() external view returns(uint256);
    function getMultiplier(uint256 _from, uint256 _to) external view returns(uint256);
    function pendingRCC(uint256 _pid, address _user) external view returns(uint256);
    function pendingRCCByBlockNumber(uint256 _pid, address _user, uint256 _blockNumber) external view returns(uint256);
    function stakingBalance(uint256 _pid, address _user) external view returns(uint256);
    function withdrawAmount(uint256 _pid, address _user) external view returns(uint256 requestAmount, uint256 pendingWithdrawAmount);
    function depositnativeCurrency() external payable;
    function deposit(uint256 _pid, uint256 _amount) external;
    function unstake(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid) external;
    function claim(uint256 _pid) external;
}