//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts@4.7.3/token/ERC20/IERC20.sol";

/**
 * @title Liquidity Locker Implementation
 * @author Avinash Jain
 */
contract LiquidityLocker {
    /**
     * @dev emitted when Assest are Vested
     * @param owner : address who vest token
     * @param amount : no of token vested
     * @param ScheduledId : Id of Scheduled Vesting
     */
    event VestAssest(
        address indexed owner,
        uint256 indexed amount,
        uint256 indexed ScheduledId
    );

    /**
     * @dev emitted when Owner withdraw some token
     * @param owner : address who vested token
     * @param amount : token amount withdrawn
     * @param rewardEarned : reward earned on withdrawn token before maturity
     */
    event WithdrawAssest(
        address indexed owner,
        uint256 indexed amount,
        uint256 rewardEarned
    );

    /**
     * @dev emitted when Vesting Schedule is added by owner
     * @param ScheduledId : Id for scheduled vesting
     * @param endTimestamp : Time in second before maturity
     * @param cliffDurartion : Time in second after which vested assest can be withdrawn
     */
    event VestingScheduled(
        uint256 indexed ScheduledId,
        uint256 endTimestamp,
        uint256 cliffDurartion
    );

    /**
     * @dev emitted when assest vester got some referal
     * @param from : address of contract
     * @param to : address of referer
     * @param amount : referal reward
     */
    event ReferalTransfer(
        address indexed from,
        address indexed to,
        uint256 amount
    );

    /**
     * @dev emitted when owner add some assest in already existing vest
     * @param owner : owner address
     * @param amount : assest added
     */
    event AddAssests(address indexed owner, uint256 indexed amount);

    /**
     * @dev emitted when a address Drop all his vested assests
     * @param owner : owner address
     * @param amount : amount dropped
     */
    event DropAllAssests(address indexed owner, uint256 amount);

    address owner;
    IERC20 token;
    mapping(address => Vesting) private vesting;
    mapping(uint256 => Schedule) private vestingScheme;
    mapping(address => bool) private isBenefiter;
    mapping(address => address) private referal;
    mapping(address => bool) private isRefered;
    uint256 rewardRateBeforeMaturity;
    uint256 manageralRate;
    uint256 referalRate;
    uint256 referalReward;

    uint256 private scheduleVestingCount = 1;

    struct Schedule {
        uint256 endTimestamp;
        uint256 cliffDurartion;
        uint256 rewardRate;
    }
    struct Vesting {
        uint256 startTimestamp;
        uint256 scheduleId;
        uint256 vestedAmount;
        uint256 rewardEarned;
        uint256 referalRewardRate;
    }

    /**
     * @dev sets value of reward rate, manageral rate, referal rate, referal reward
     * all these values cannot be changed after contract construction
     */
    constructor(
        address _token,
        uint256 _rewardRate,
        uint256 _manageralRate,
        uint256 _referalRate,
        uint256 _referalReward
    ) {
        token = IERC20(_token);
        owner = msg.sender;
        rewardRateBeforeMaturity = _rewardRate;
        manageralRate = _manageralRate;
        referalRate = _referalRate;
        referalReward = _referalReward;
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "LiquidityLocker: Only owner can Schedule Vesting"
        );
        _;
    }

    modifier onlyBenefiter() {
        require(
            isBenefiter[msg.sender],
            "LiquidityLocker: only benefiters can withdraw or add vested token"
        );
        _;
    }

    modifier notBenefiter() {
        require(
            !isBenefiter[msg.sender],
            "LiquidityLocker: sender already have assests vested in contract."
        );
        _;
    }

    modifier NotRefered(address addr) {
        require(
            isRefered[addr] == false,
            "LiquidityLocker: This user address is already refered."
        );
        _;
    }

    modifier existSchedule(uint256 _scheduleVestingCount) {
        require(
            _scheduleVestingCount < scheduleVestingCount &&
                _scheduleVestingCount > 0,
            "LiquidityLocker: This schedule does not exist"
        );
        _;
    }

    modifier notNull(address _address) {
        require(_address != address(0), "LiquidityLocker: Invalid address");
        _;
    }

    /**
     * @dev allow contract owner to Schedule a vesting
     * Requirement -
     *         only onwer can schedule
     *         cliff duration must be less than or equal to endTimestamp
     * @param _endTimestamp : time in second before maturity
     * @param _cliffDuration : time in second before assest withdrawal
     * @param _rewardRate : reward rate for that schedule
     * Emit a {VestingScheduled} event
     */
    function scheduleVesting(
        uint256 _endTimestamp,
        uint256 _cliffDuration,
        uint256 _rewardRate
    ) external onlyOwner {
        require(
            _cliffDuration <= _endTimestamp,
            "LiquidityLocker: Cliff Duration cannot be greater than End timestamp"
        );
        uint256 _scheduleVestingCount = scheduleVestingCount++;
        vestingScheme[_scheduleVestingCount] = Schedule(
            _endTimestamp,
            _cliffDuration,
            _rewardRate
        );
        emit VestingScheduled(
            _scheduleVestingCount,
            _endTimestamp,
            _cliffDuration
        );
    }

    /**
     * @dev a user can vest his assest for a particular vesting schedule
     * Requirement -
     *         vesting schedule must exist
     *         user address must not currently have some assest vested
     *         no of token vested must be greater than zero
     * @param _vestedAmount : no of token vested
     * @param _scheduleVestingCount : Schedule Vesting Id
     * Emit a {VestAssest} event and
     *        {ReferalTransfer} event only for address with a referal
     */
    function vestAssests(
        uint256 _vestedAmount,
        uint256 _scheduleVestingCount
    ) external payable existSchedule(_scheduleVestingCount) notBenefiter {
        require(
            _vestedAmount > 0,
            "LiquidityLocker: No of token should be greater than zero."
        );

        uint256 manageralFee = (_vestedAmount * manageralRate) / 100;

        if (isRefered[msg.sender]) {
            address referalAddress = referal[msg.sender];
            uint256 referalFee = (manageralFee * referalRate) / 100;
            token.transfer(referalAddress, referalFee);
            emit ReferalTransfer(address(this), referalAddress, referalFee);
            isRefered[msg.sender] = false;
            vesting[msg.sender] = Vesting(
                block.timestamp,
                _scheduleVestingCount,
                _vestedAmount - manageralFee,
                0,
                referalReward
            );
        } else {
            vesting[msg.sender] = Vesting(
                block.timestamp,
                _scheduleVestingCount,
                _vestedAmount - manageralFee,
                0,
                0
            );
        }
        isBenefiter[msg.sender] = true;

        token.transferFrom(msg.sender, address(this), _vestedAmount);

        emit VestAssest(
            msg.sender,
            _vestedAmount - manageralFee,
            _scheduleVestingCount
        );
    }

    /**
     * @dev a address can withdraw his token after cliff duration
     * Requirement -
     *         address with already existing vest can withdraw
     *         Cliff duration must have passed
     *         token to withdraw must be less than current token in vest
     * @param tokenToWithdraw : no of token to withdraw
     * Emit a {WithDrawAssest} event
     */
    function withdrawToken(uint256 tokenToWithdraw) external onlyBenefiter {
        Vesting memory userVest = vesting[msg.sender];
        require(
            tokenToWithdraw <= userVest.vestedAmount,
            "LiquidityLocker: Not enough token vested"
        );
        Schedule memory userSchedule = vestingScheme[userVest.scheduleId];

        require(
            block.timestamp >=
                userVest.startTimestamp + userSchedule.cliffDurartion,
            "LiquidityLocker: cliff duration have not passed"
        );

        uint256 reward = (tokenToWithdraw * rewardRateBeforeMaturity) / 100;

        vesting[msg.sender].vestedAmount -= tokenToWithdraw;
        vesting[msg.sender].rewardEarned += reward;
        token.transfer(msg.sender, tokenToWithdraw);
        emit WithdrawAssest(msg.sender, tokenToWithdraw, reward);
    }

    /**
     * @dev a address can drop all his assest in vest after maturity
     * Requirement -
     *         only address with existing vest can drop Assests
     *         current time stamp must be greater than equal to maturity time
     * Emit a {DropAllAssests} event
     */
    function dropAllAssests() external onlyBenefiter {
        Vesting memory userVest = vesting[msg.sender];
        Schedule memory userSchedule = vestingScheme[userVest.scheduleId];
        require(
            block.timestamp >=
                userVest.startTimestamp + userSchedule.endTimestamp,
            "LiquidityLocker: Vested assests have not reached their maturity."
        );

        uint256 totalReward = (userVest.vestedAmount *
            (userSchedule.rewardRate + userVest.referalRewardRate)) /
            100 +
            userVest.rewardEarned +
            userVest.vestedAmount;
        token.transfer(msg.sender, totalReward);
        isBenefiter[msg.sender] = false;
        emit DropAllAssests(msg.sender, totalReward);
    }

    /**
     * @dev a address can refer another address
     * Requirement -
     *         passed address must not be already refered
     *         passed address must not be null address
     *         sender cannot refer himself
     * @param to : address to refer
     */
    function refer(address to) external NotRefered(to) notNull(to) {
        require(
            msg.sender != to,
            "LiquidityLocker: Msg Sender cannot approve himself."
        );
        referal[to] = msg.sender;
        isRefered[to] = true;
    }

    /**
     * @dev a user can add assest to him already existing vest
     * Requirement -
     *         only address with existing vest can add assest
     *         cliffduration must not have passed
     * @param amount : token to add
     * Emit a {AddAssests} event
     */
    function addAssests(uint256 amount) external onlyBenefiter {
        Vesting memory userVest = vesting[msg.sender];
        Schedule memory userSchedule = vestingScheme[userVest.scheduleId];
        require(
            block.timestamp <
                userVest.startTimestamp + userSchedule.cliffDurartion,
            "LiquidityLocker: cannot add assest after cliffDuration."
        );
        uint256 reward = (userVest.vestedAmount) / 100;
        vesting[msg.sender].vestedAmount += amount;
        vesting[msg.sender].rewardEarned += reward;
        emit AddAssests(msg.sender, amount);
    }
}
