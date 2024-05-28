// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Library/BaseDao.sol";

contract Governance is BaseDao {
    // Define specific parameters or methods for this DAO

    constructor(string memory name, TimelockController timelock, IVotes votesToken, address admin)
        BaseDao(name, timelock, votesToken, admin)
    {}

    // Additional functionality specific to DAO
}
