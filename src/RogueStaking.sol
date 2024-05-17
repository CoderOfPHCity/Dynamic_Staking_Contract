// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
 
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
 
contract RogueStaking is ReentrancyGuard, Ownable {
    IERC20 public immutable stakingToken;
    AggregatorV3Interface public immutable priceFeed;
    uint256 public constant MIN_DOLLAR_VALUE = 0.01; // $0.01 (adjust decimals as necessary)
    uint256 public constant MIN_LOCKUP_PERIOD = 5 days;
 
    address public daoWallet;
    address public penaltyWallet;
    uint8 public daoSplit = 80; // 80% to DAO
 
    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lockupPeriod;
        uint256 apy;
    }
 
    mapping(address => StakeInfo) public stakes;
    mapping(address => uint256) public rewards;
 
    event Withdraw(address indexed user, uint256 amount);
    event Stake(address indexed user, uint256 amount);
    event PenaltyPaid(address indexed user, uint256 penaltyAmount, address penaltyWallet);
 
    constructor(address _stakingToken, address _priceFeed, address _daoWallet, address _penaltyWallet) {
        stakingToken = IERC20(_stakingToken);
        priceFeed = AggregatorV3Interface(_priceFeed);
        daoWallet = _daoWallet;
        penaltyWallet = _penaltyWallet;
    }
 
    function getLatestPrice() public view returns (int) {
        (, int price,,,) = priceFeed.latestRoundData();
        return price;
    }
 
    function withdraw(uint256 amount) external nonReentrant {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        uint256 userBalance = stakeInfo.amount;
        require(userBalance >= amount, "Insufficient balance");
 
        uint256 remainingBalance = userBalance - amount;
 
        // Get the latest token price in USD
        int price = getLatestPrice();
        uint256 valueInDollars = remainingBalance * uint256(price) / (10 ** priceFeed.decimals());
 
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
 
        emit Withdraw(msg.sender, amount - penaltyAmount);
    }
 
    function stake(uint256 amount, uint256 lockupPeriod, uint256 apy) external nonReentrant {
        require(amount > 0, "Cannot stake 0");
        require(lockupPeriod >= MIN_LOCKUP_PERIOD, "Lockup period too short");
 
        uint256 userBalance = stakes[msg.sender].amount;
        uint256 newBalance = userBalance + amount;
 
        // Get the latest token price in USD
        int price = getLatestPrice();
        uint256 valueInDollars = newBalance * uint256(price) / (10 ** priceFeed.decimals());
 
        // Allow staking if the new balance value is greater than or equal to the minimum dollar value
        require(valueInDollars >= MIN_DOLLAR_VALUE, "New balance is below the minimum threshold");
 
        stakingToken.transferFrom(msg.sender, address(this), amount);
        stakes[msg.sender] = StakeInfo({
            amount: newBalance,
            startTime: block.timestamp,
            lockupPeriod: lockupPeriod,
            apy: apy
        });
 
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
    function setDaoSplit(uint8 _daoSplit) external onlyOwner {
        require(_daoSplit <= 100, "Invalid DAO split");
    }
}  