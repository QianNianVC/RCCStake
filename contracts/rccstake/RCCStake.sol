// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "../library/RCCStakeLib.sol";
import "../interface/IRCCStake.sol";
import "./Events.sol";

contract RCCStake is
Initializable,
UUPSUpgradeable,
PausableUpgradeable,
AccessControlUpgradeable,
IRCCStake
{
    using SafeERC20 for IERC20;
    using Address for address;
    using Math for uint256;
    using RCCStakeLib for RCCStakeLib.Pool;

    // ************************************** INVARIANT **************************************

    bytes32 public constant ADMIN_ROLE = keccak256("admin_role");
    bytes32 public constant UPGRADE_ROLE = keccak256("upgrade_role");

    uint256 public constant nativeCurrency_PID = 0;

    // ************************************** DATA STRUCTURE **************************************

    RCCStakeLib.Pool[] public pool;
    mapping(uint256 => mapping(address => RCCStakeLib.User)) public user;

    // ************************************** STATE VARIABLES **************************************

    uint256 public startBlock;
    uint256 public endBlock;
    uint256 public RCCPerBlock;
    bool public withdrawPaused;
    bool public claimPaused;
    IERC20 public RCC;
    uint256 public totalPoolWeight;

    // ************************************** MODIFIER **************************************

    modifier checkPid(uint256 _pid) {
        require(_pid < pool.length, "invalid pid");
        _;
    }

    modifier whenNotClaimPaused() {
        require(!claimPaused, "claim is paused");
        _;
    }

    modifier whenNotWithdrawPaused() {
        require(!withdrawPaused, "withdraw is paused");
        _;
    }

    // ************************************** INITIALIZER **************************************

    function initialize(
        IERC20 _RCC,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _RCCPerBlock
    ) public initializer {
        require(_startBlock <= _endBlock && _RCCPerBlock > 0, "invalid parameters");

        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADE_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        setRCC(_RCC);

        startBlock = _startBlock;
        endBlock = _endBlock;
        RCCPerBlock = _RCCPerBlock;
    }

    function _authorizeUpgrade(address newImplementation)
    internal
    onlyRole(UPGRADE_ROLE)
    override
    {}

    // ************************************** ADMIN FUNCTION **************************************

    function setRCC(IERC20 _RCC) public onlyRole(ADMIN_ROLE) {
        RCC = _RCC;
        emit Events.SetRCC(RCC);
    }

    function pauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(!withdrawPaused, "withdraw has been already paused");
        withdrawPaused = true;
        emit Events.PauseWithdraw();
    }

    function unpauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(withdrawPaused, "withdraw has been already unpaused");
        withdrawPaused = false;
        emit Events.UnpauseWithdraw();
    }

    function pauseClaim() public onlyRole(ADMIN_ROLE) {
        require(!claimPaused, "claim has been already paused");
        claimPaused = true;
        emit Events.PauseClaim();
    }

    function unpauseClaim() public onlyRole(ADMIN_ROLE) {
        require(claimPaused, "claim has been already unpaused");
        claimPaused = false;
        emit Events.UnpauseClaim();
    }

    function setStartBlock(uint256 _startBlock) public onlyRole(ADMIN_ROLE) {
        require(_startBlock <= endBlock, "start block must be smaller than end block");
        startBlock = _startBlock;
        emit Events.SetStartBlock(_startBlock);
    }

    function setEndBlock(uint256 _endBlock) public onlyRole(ADMIN_ROLE) {
        require(startBlock <= _endBlock, "start block must be smaller than end block");
        endBlock = _endBlock;
        emit Events.SetEndBlock(_endBlock);
    }

    function setRCCPerBlock(uint256 _RCCPerBlock) public onlyRole(ADMIN_ROLE) {
        require(_RCCPerBlock > 0, "invalid parameter");
        RCCPerBlock = _RCCPerBlock;
        emit Events.SetRCCPerBlock(_RCCPerBlock);
    }

    function addPool(address _stTokenAddress, uint256 _poolWeight, uint256 _minDepositAmount, uint256 _unstakeLockedBlocks, bool _withUpdate) public onlyRole(ADMIN_ROLE) {
        if (pool.length > 0) {
            require(_stTokenAddress != address(0x0), "invalid staking token address");
        } else {
            require(_stTokenAddress == address(0x0), "invalid staking token address");
        }
        require(_unstakeLockedBlocks > 0, "invalid withdraw locked blocks");
        require(block.number < endBlock, "Already ended");

        if (_withUpdate) {
            massUpdatePools();
        }

        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalPoolWeight += _poolWeight;

        pool.push(RCCStakeLib.Pool({
            stTokenAddress: _stTokenAddress,
            poolWeight: _poolWeight,
            lastRewardBlock: lastRewardBlock,
            accRCCPerST: 0,
            stTokenAmount: 0,
            minDepositAmount: _minDepositAmount,
            unstakeLockedBlocks: _unstakeLockedBlocks
        }));

        emit Events.AddPool(_stTokenAddress, _poolWeight, lastRewardBlock, _minDepositAmount, _unstakeLockedBlocks);
    }

    function updatePool(uint256 _pid, uint256 _minDepositAmount, uint256 _unstakeLockedBlocks) public onlyRole(ADMIN_ROLE) checkPid(_pid) {
        pool[_pid].minDepositAmount = _minDepositAmount;
        pool[_pid].unstakeLockedBlocks = _unstakeLockedBlocks;
        emit Events.UpdatePoolInfo(_pid, _minDepositAmount, _unstakeLockedBlocks);
    }

    function setPoolWeight(uint256 _pid, uint256 _poolWeight, bool _withUpdate) public onlyRole(ADMIN_ROLE) checkPid(_pid) {
        require(_poolWeight > 0, "invalid pool weight");

        if (_withUpdate) {
            massUpdatePools();
        }

        totalPoolWeight = totalPoolWeight - pool[_pid].poolWeight + _poolWeight;
        pool[_pid].poolWeight = _poolWeight;

        emit Events.SetPoolWeight(_pid, _poolWeight, totalPoolWeight);
    }

    // ************************************** QUERY FUNCTION **************************************

    function poolLength() external view returns (uint256) {
        return pool.length;
    }

    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256 multiplier) {
        require(_from <= _to, "invalid block range");
        if (_from < startBlock) {_from = startBlock;}
        if (_to > endBlock) {_to = endBlock;}
        require(_from <= _to, "end block must be greater than start block");
        multiplier = (_to - _from) * RCCPerBlock;
    }

    function pendingRCC(uint256 _pid, address _user) external checkPid(_pid) view returns (uint256) {
        return pendingRCCByBlockNumber(_pid, _user, block.number);
    }

    function pendingRCCByBlockNumber(uint256 _pid, address _user, uint256 _blockNumber) public checkPid(_pid) view returns (uint256) {
        RCCStakeLib.Pool storage pool_ = pool[_pid];
        RCCStakeLib.User storage user_ = user[_pid][_user];
        uint256 accRCCPerST = pool_.accRCCPerST;
        uint256 stSupply = pool_.stTokenAmount;

        if (_blockNumber > pool_.lastRewardBlock && stSupply != 0) {
            uint256 multiplier = getMultiplier(pool_.lastRewardBlock, _blockNumber);
            uint256 RCCForPool = multiplier * pool_.poolWeight / totalPoolWeight;
            accRCCPerST += RCCForPool * 1 ether / stSupply;
        }

        return user_.stAmount * accRCCPerST / 1 ether - user_.finishedRCC + user_.pendingRCC;
    }

    function stakingBalance(uint256 _pid, address _user) external checkPid(_pid) view returns (uint256) {
        return user[_pid][_user].stAmount;
    }

    function withdrawAmount(uint256 _pid, address _user) public checkPid(_pid) view returns (uint256 requestAmount, uint256 pendingWithdrawAmount) {
        RCCStakeLib.User storage user_ = user[_pid][_user];

        for (uint256 i = 0; i < user_.requests.length; i++) {
            if (user_.requests[i].unlockBlocks <= block.number) {
                pendingWithdrawAmount += user_.requests[i].amount;
            }
            requestAmount += user_.requests[i].amount;
        }
    }

    // ************************************** PUBLIC FUNCTION **************************************

    function updatePool(uint256 _pid) public checkPid(_pid) {
        pool[_pid].updatePool(totalPoolWeight, RCCPerBlock, block.number);
        emit Events.UpdatePool(_pid, pool[_pid].lastRewardBlock, pool[_pid].accRCCPerST);
    }

    function massUpdatePools() public {
        uint256 length = pool.length;
        for (uint256 pid = 0; pid < length; pid++) {
            updatePool(pid);
        }
    }

    function depositnativeCurrency() public whenNotPaused() payable {
        RCCStakeLib.Pool storage pool_ = pool[nativeCurrency_PID];
        require(pool_.stTokenAddress == address(0x0), "invalid staking token address");

        uint256 _amount = msg.value;
        require(_amount >= pool_.minDepositAmount, "deposit amount is too small");

        _deposit(nativeCurrency_PID, _amount);
    }

    function deposit(uint256 _pid, uint256 _amount) public whenNotPaused() checkPid(_pid) {
        require(_pid != 0, "deposit not support nativeCurrency staking");
        RCCStakeLib.Pool storage pool_ = pool[_pid];
        require(_amount > pool_.minDepositAmount, "deposit amount is too small");

        if (_amount > 0) {
            IERC20(pool_.stTokenAddress).safeTransferFrom(msg.sender, address(this), _amount);
        }

        _deposit(_pid, _amount);
    }

    function unstake(uint256 _pid, uint256 _amount) public whenNotPaused() checkPid(_pid) whenNotWithdrawPaused() {
        RCCStakeLib.Pool storage pool_ = pool[_pid];
        RCCStakeLib.User storage user_ = user[_pid][msg.sender];

        require(user_.stAmount >= _amount, "Not enough staking token balance");

        updatePool(_pid);

        uint256 pendingRCC_ = user_.stAmount * pool_.accRCCPerST / 1 ether - user_.finishedRCC;

        if (pendingRCC_ > 0) {
            user_.pendingRCC += pendingRCC_;
        }

        if (_amount > 0) {
            user_.stAmount -= _amount;
            user_.requests.push(RCCStakeLib.UnstakeRequest({
                amount: _amount,
                unlockBlocks: block.number + pool_.unstakeLockedBlocks
            }));
        }

        pool_.stTokenAmount -= _amount;
        user_.finishedRCC = user_.stAmount * pool_.accRCCPerST / 1 ether;

        emit Events.RequestUnstake(msg.sender, _pid, _amount);
    }

    function withdraw(uint256 _pid) public whenNotPaused() checkPid(_pid) whenNotWithdrawPaused() {
        RCCStakeLib.Pool storage pool_ = pool[_pid];
        RCCStakeLib.User storage user_ = user[_pid][msg.sender];

        uint256 pendingWithdraw_;
        uint256 popNum_;
        for (uint256 i = 0; i < user_.requests.length; i++) {
            if (user_.requests[i].unlockBlocks > block.number) {
                break;
            }
            pendingWithdraw_ += user_.requests[i].amount;
            popNum_++;
        }

        for (uint256 i = 0; i < user_.requests.length - popNum_; i++) {
            user_.requests[i] = user_.requests[i + popNum_];
        }

        for (uint256 i = 0; i < popNum_; i++) {
            user_.requests.pop();
        }

        if (pendingWithdraw_ > 0) {
            if (pool_.stTokenAddress == address(0x0)) {
                RCCStakeLib.safeNativeCurrencyTransfer(msg.sender, pendingWithdraw_);
            } else {
                IERC20(pool_.stTokenAddress).safeTransfer(msg.sender, pendingWithdraw_);
            }
        }

        emit Events.Withdraw(msg.sender, _pid, pendingWithdraw_, block.number);
    }

    function claim(uint256 _pid) public whenNotPaused() checkPid(_pid) whenNotClaimPaused() {
        RCCStakeLib.Pool storage pool_ = pool[_pid];
        RCCStakeLib.User storage user_ = user[_pid][msg.sender];

        updatePool(_pid);

        uint256 pendingRCC_ = user_.stAmount * pool_.accRCCPerST / 1 ether - user_.finishedRCC + user_.pendingRCC;

        if (pendingRCC_ > 0) {
            user_.pendingRCC = 0;
            RCCStakeLib.safeRCCTransfer(RCC, msg.sender, pendingRCC_);
        }

        user_.finishedRCC = user_.stAmount * pool_.accRCCPerST / 1 ether;

        emit Events.Claim(msg.sender, _pid, pendingRCC_);
    }

    // ************************************** INTERNAL FUNCTION **************************************

    function _deposit(uint256 _pid, uint256 _amount) internal {
        RCCStakeLib.Pool storage pool_ = pool[_pid];
        RCCStakeLib.User storage user_ = user[_pid][msg.sender];

        updatePool(_pid);

        if (user_.stAmount > 0) {
            uint256 accST = user_.stAmount * pool_.accRCCPerST / 1 ether;
            uint256 pendingRCC_ = accST - user_.finishedRCC;

            if (pendingRCC_ > 0) {
                user_.pendingRCC += pendingRCC_;
            }
        }

        if (_amount > 0) {
            user_.stAmount += _amount;
        }

        pool_.stTokenAmount += _amount;
        user_.finishedRCC = user_.stAmount * pool_.accRCCPerST / 1 ether;

        emit Events.Deposit(msg.sender, _pid, _amount);
    }
}