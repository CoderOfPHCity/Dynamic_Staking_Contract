// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./RogueStaking.sol";

interface INFTPriceOracle {
    function getLatestFloorPrice(address nftContract) external view returns (uint256);
    function decimals() external view returns (uint8);
}

abstract contract EnhancedRogueStaking is RogueStaking {
    INFTPriceOracle public nftPriceOracle;

    struct NFTInfo {
        address contractAddress;
        uint256 tokenId;
        uint256 floorPrice;
    }

    mapping(address => NFTInfo[]) public stakedNFTs;

    event NFTStaked(address indexed user, address indexed nftContract, uint256 indexed tokenId, uint256 floorPrice);
    event NFTWithdrawn(address indexed user, address indexed nftContract, uint256 indexed tokenId);

    constructor(address _nftPriceOracle) {
        nftPriceOracle = INFTPriceOracle(_nftPriceOracle);
    }

    function stakeWithNFT(uint256 amount, uint256 stakingOptionIndex, address nftContract, uint256 nftId)
        external
        nonReentrant
    {
        // Original staking logic
        stake(amount, stakingOptionIndex);

        // Additional NFT staking logic
        uint256 nftFloorPrice = nftPriceOracle.getLatestFloorPrice(nftContract);
        require(nftFloorPrice > 0, "Invalid NFT price");

        // Calculate the total value in dollars
        uint256 totalValueInDollars = _calculateTotalValueInDollars(nftContract, amount);

        require(totalValueInDollars >= MIN_DOLLAR_VALUE, "Combined value is below the minimum threshold");
        uint256 apy = calculateAPY(amount, nftContract, nftFloorPrice, stakingOptionIndex);
        // Store NFT staking info
        stakedNFTs[msg.sender].push(NFTInfo({contractAddress: nftContract, tokenId: nftId, floorPrice: nftFloorPrice}));

        emit NFTStaked(msg.sender, nftContract, nftId, nftFloorPrice);
    }

    function withdrawWithNFT(uint256 stakeIndex, uint256 amount, address nftContract, uint256 nftId)
        external
        nonReentrant
    {
        // Original withdrawal logic
        withdraw(stakeIndex, amount);

        // Additional NFT withdrawal logic
        for (uint256 i = 0; i < stakedNFTs[msg.sender].length; i++) {
            if (stakedNFTs[msg.sender][i].contractAddress == nftContract && stakedNFTs[msg.sender][i].tokenId == nftId)
            {
                // Release NFT to the user
                emit NFTWithdrawn(msg.sender, nftContract, nftId);
                // Remove NFT from the staked list
                _removeNFTFromStakedList(msg.sender, i);
                break;
            }
        }
    }

    function _removeNFTFromStakedList(address user, uint256 index) internal {
        require(index < stakedNFTs[user].length, "Invalid index");

        uint256 lastIndex = stakedNFTs[user].length - 1;
        if (index < lastIndex) {
            stakedNFTs[user][index] = stakedNFTs[user][lastIndex];
        }

        // Remove the last element
        stakedNFTs[user].pop();
    }

    function _calculateTotalValueInDollars(address nftContract, uint256 stakedAmount) internal view returns (uint256) {
        // Calculate the total value in dollars
        uint256 latestPrice = nftPriceOracle.getLatestFloorPrice(nftContract);
        uint256 valueInDollars = (stakedAmount * uint256(latestPrice)) / (10 ** nftPriceOracle.decimals());
        return valueInDollars;
    }

    function calculateAPY(uint256 stakedAmount, address nftContract, uint256 nftValue, uint256 stakingOptionIndex)
        internal
        view
        returns (uint256)
    {
        require(stakingOptionIndex < stakingOptions.length, "Invalid staking option index");
        StakingOption memory option = stakingOptions[stakingOptionIndex];
        uint256 baseAPY = option.apy;

        uint256 combinedValue = stakedAmount + nftValue;
        uint256 baseValue = nftPriceOracle.getLatestFloorPrice(nftContract);
        uint256 additionalAPYPercentage = 1;

        // Use combinedValue to determine the APY
        uint256 enhancedAPY = baseAPY + (additionalAPYPercentage * combinedValue / baseValue);

        return enhancedAPY;
    }
}
