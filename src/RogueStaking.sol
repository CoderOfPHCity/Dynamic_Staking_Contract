// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract RogueStaking is ReentrancyGuard, Ownable {
    IERC20 public immutable stakingToken;
    AggregatorV3Interface public immutable priceFeed;
    uint256 public constant MIN_DOLLAR_VALUE = 100; // $0.01 (adjust decimals as necessary)
    uint256 public constant MIN_LOCKUP_PERIOD = 5 days;

    address public daoWallet;
    address public penaltyWallet;
    uint8 public daoSplit = 80; // 80% to DAO

    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lockupPeriod;
        uint256 apy;
        uint256 endTime;
    }

    struct LeaderboardEntry {
        address user;
        uint256 combinedBalance;
    }

    mapping(address => StakeInfo) public stakes;
    mapping(address => uint256) public rewards;
    mapping(address => LeaderboardEntry) public leaderboard;
    LeaderboardEntry[] public topStakers;
    address[] public users;

    event Withdraw(address indexed user, uint256 amount);
    event Stake(address indexed user, uint256 amount);
    event PenaltyPaid(address indexed user, uint256 penaltyAmount, address penaltyWallet);

    constructor(
        address initialOwner,
        address _stakingToken,
        address _priceFeed,
        address _daoWallet,
        address _penaltyWallet
    ) Ownable(initialOwner) {
        stakingToken = IERC20(_stakingToken);
        priceFeed = AggregatorV3Interface(_priceFeed);
        daoWallet = _daoWallet;
        penaltyWallet = _penaltyWallet;
    }

    function getLatestPrice() public view returns (int256) {
        (, int256 price,,,) = priceFeed.latestRoundData();
        return price;
    }

    function withdraw(uint256 amount) external nonReentrant {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        uint256 userBalance = stakeInfo.amount;
        require(userBalance >= amount, "Insufficient balance");

        uint256 remainingBalance = userBalance - amount;

        // Get the latest token price in USD
        int256 price = getLatestPrice();
        uint256 valueInDollars = (remainingBalance * uint256(price)) / (10 ** priceFeed.decimals());

        // Check if the remaining balance value is less than the minimum dollar value
        if (valueInDollars < MIN_DOLLAR_VALUE) {
            amount = userBalance; // Withdraw the entire balance
        }

        uint256 penaltyAmount = 0;
        if (block.timestamp < stakeInfo.startTime + stakeInfo.lockupPeriod) {
            penaltyAmount = (amount * getPenaltyRate(stakeInfo.lockupPeriod)) / 100;
            uint256 daoAmount = (penaltyAmount * daoSplit) / 100;
            uint256 penaltyWalletAmount = penaltyAmount - daoAmount;
            stakingToken.transfer(daoWallet, daoAmount);
            stakingToken.transfer(penaltyWallet, penaltyWalletAmount);
            emit PenaltyPaid(msg.sender, penaltyAmount, penaltyWallet);
        }

        stakeInfo.amount -= amount;
        stakingToken.transfer(msg.sender, amount - penaltyAmount);
        updateLeaderboard(msg.sender);

        emit Withdraw(msg.sender, amount - penaltyAmount);
    }

    function updateLeaderboard(address user) internal {
        uint256 walletBalance = stakingToken.balanceOf(user);
        uint256 stakedAmount = stakes[user].amount;
        uint256 combinedBalance = walletBalance + stakedAmount;

        // Update leaderboard entry
        leaderboard[user] = LeaderboardEntry({user: user, combinedBalance: combinedBalance});

        bool userExists = false;
        for (uint256 i = 0; i < users.length; i++) {
            if (users[i] == user) {
                userExists = true;
                break;
            }
        }

        if (!userExists) {
            users.push(user);
        }

        updateRankings();
    }

    function updateRankings() private {
        LeaderboardEntry[] memory entries = new LeaderboardEntry[](users.length);

        for (uint256 i = 0; i < users.length; i++) {
            entries[i] = leaderboard[users[i]];
        }

        sort(entries);

        delete topStakers;

        for (uint256 i = 0; i < entries.length && i < 20; i++) {
            topStakers.push(entries[i]);
        }
    }

    function sort(LeaderboardEntry[] memory entries) private pure {
        uint256 length = entries.length;
        for (uint256 i = 0; i < length; i++) {
            for (uint256 j = i + 1; j < length; j++) {
                if (entries[i].combinedBalance < entries[j].combinedBalance) {
                    LeaderboardEntry memory temp = entries[i];
                    entries[i] = entries[j];
                    entries[j] = temp;
                }
            }
        }
    }

    function stake(uint256 amount, uint256 lockupPeriod, uint256 apy) external nonReentrant {
        require(amount > 0, "Cannot stake 0");
        require(lockupPeriod >= MIN_LOCKUP_PERIOD, "Lockup period too short");

        uint256 userBalance = stakes[msg.sender].amount;
        uint256 newBalance = userBalance + amount;

        // Get the latest token price in USD
        int256 price = getLatestPrice();
        uint256 valueInDollars = (newBalance * uint256(price)) / (10 ** priceFeed.decimals());

        // Allow staking if the new balance value is greater than or equal to the minimum dollar value
        require(valueInDollars >= MIN_DOLLAR_VALUE, "New balance is below the minimum threshold");
        require(stakingToken.allowance(msg.sender, address(this)) >= amount, "Allowance not enough");
        stakingToken.transferFrom(msg.sender, address(this), amount);
        stakes[msg.sender] = StakeInfo({
            amount: newBalance,
            startTime: block.timestamp,
            lockupPeriod: lockupPeriod,
            endTime: block.timestamp + lockupPeriod,
            apy: apy
        });
        updateLeaderboard(msg.sender);

        emit Stake(msg.sender, amount);
    }

    function getPenaltyRate(uint256 lockupPeriod) internal pure returns (uint256) {
        if (lockupPeriod == 10 days) return 2;
        if (lockupPeriod == 20 days) return 3;
        if (lockupPeriod == 30 days) return 5;
        return 1; // Default penalty for 5 days lockup period
    }

    // Function to set the DAO wallet (if needed)
    function setDaoWallet(address _daoWallet) external onlyOwner {
        daoWallet = _daoWallet;
    }

    // Function to set the penalty wallet (if needed)
    function setPenaltyWallet(address _penaltyWallet) external onlyOwner {
        penaltyWallet = _penaltyWallet;
    }

    // Function to set the DAO split (if needed)
    function setDaoSplit(uint8 _daoSplit) external view onlyOwner {
        require(_daoSplit <= 100, "Invalid DAO split");
    }

    function getStakingDetails(address user)
        external
        view
        returns (uint256 amount, uint256 startTime, uint256 endTime, uint256 timeLeft, uint256 apy)
    {
        StakeInfo storage stakeInfo = stakes[user];
        amount = stakeInfo.amount;
        startTime = stakeInfo.startTime;
        endTime = stakeInfo.endTime;
        if (block.timestamp >= endTime) {
            timeLeft = 0;
        } else {
            timeLeft = endTime - block.timestamp;
        }
        apy = stakeInfo.apy;
    }

    function getLeaderboardEntry(address user)
        external
        view
        returns (uint256 stakedAmount, uint256 walletBalance, uint256 combinedBalance)
    {
        LeaderboardEntry storage entry = leaderboard[user];
        return (stakes[user].amount, stakingToken.balanceOf(user), entry.combinedBalance);
    }

    function getTopStakers(uint256 count) external view returns (address[] memory, uint256[] memory) {
        address[] memory addresses = new address[](count);
        uint256[] memory combinedBalances = new uint256[](count);

        for (uint256 i = 0; i < count && i < topStakers.length; i++) {
            addresses[i] = topStakers[i].user;
            combinedBalances[i] = topStakers[i].combinedBalance;
        }

        return (addresses, combinedBalances);
    }
}
