// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

library RCCStakeLib {
    using SafeERC20 for IERC20;
    using Math for uint256;

    struct Pool {
        address stTokenAddress;
        uint256 poolWeight;
        uint256 lastRewardBlock;
        uint256 accRCCPerST;
        uint256 stTokenAmount;
        uint256 minDepositAmount;
        uint256 unstakeLockedBlocks;
    }

    struct UnstakeRequest {
        uint256 amount;
        uint256 unlockBlocks;
    }

    struct User {
        uint256 stAmount;
        uint256 finishedRCC;
        uint256 pendingRCC;
        UnstakeRequest[] requests;
    }

    function updatePool(Pool storage pool, uint256 totalPoolWeight, uint256 RCCPerBlock, uint256 blockNumber) internal {
        if (blockNumber <= pool.lastRewardBlock) {
            return;
        }

        uint256 multiplier = (blockNumber - pool.lastRewardBlock) * RCCPerBlock;
        uint256 RCCForPool = multiplier * pool.poolWeight / totalPoolWeight;

        if (pool.stTokenAmount > 0) {
            pool.accRCCPerST += RCCForPool * 1 ether / pool.stTokenAmount;
        }

        pool.lastRewardBlock = blockNumber;
    }

    function safeRCCTransfer(IERC20 RCC, address to, uint256 amount) internal {
        uint256 RCCBal = RCC.balanceOf(address(this));
        if (amount > RCCBal) {
            RCC.safeTransfer(to, RCCBal);
        } else {
            RCC.safeTransfer(to, amount);
        }
    }

    function safeNativeCurrencyTransfer(address to, uint256 amount) internal {
        (bool success, ) = to.call{value: amount}("");
        require(success, "nativeCurrency transfer failed");
    }
}