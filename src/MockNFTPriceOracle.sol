// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface INFTPriceOracle {
    function getLatestFloorPrice(address nftContract) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract MockNFTPriceOracle is INFTPriceOracle {
    mapping(address => uint256) private floorPrices;
    uint8 private _decimals;

    constructor(uint8 initialDecimals) {
        _decimals = initialDecimals;
    }

    function setLatestFloorPrice(address nftContract, uint256 price) external {
        floorPrices[nftContract] = price;
    }

    function getLatestFloorPrice(address nftContract) external view override returns (uint256) {
        return floorPrices[nftContract];
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }
}
