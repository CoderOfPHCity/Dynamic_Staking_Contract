// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

import "../Interface/IDAGToken.sol";

library SafeDAGToken {
    function safeTransfer(IDAGToken token, address to, uint256 value) internal {
        require(token.transfer(to, value), "SafeDAGToken: transfer failed");
    }

    function safeTransferFrom(IDAGToken token, address from, address to, uint256 value) internal {
        require(token.transferFrom(from, to, value), "SafeDAGToken: transferFrom failed");
    }
}
