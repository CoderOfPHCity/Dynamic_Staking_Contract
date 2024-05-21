// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

interface IDAGOracle {
    function getLatestPrice() external view returns (int256);
    function decimals() external view returns (uint8);
}
