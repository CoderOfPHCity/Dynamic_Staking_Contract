// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {RogueStaking} from "../src/RogueStaking.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/MockRouguetoken.sol";

contract CounterTest is Test {
    RogueStaking public rogueStaking;
    MockERC20 mockERC20;

     IERC20 rougueERC;

    address initialOwner = 0xd1B99D610E0B540045a7FEa744551973329996d6;
    address rougueToken = 0xa3bb956C5F8Ce6Fb8386e0EBBE82Cba12bBe6EBD;
    address dai_usd = 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19;
    address daoWallet = 0x107Ff7900F4dA6BFa4eB41dBD6f2953ffb41b2B1;
    address penaltyAddress = address(0);

    address A = address(0xA);

    function setUp() public {
         A = mkaddr("signer A");
        rogueStaking = new RogueStaking(
            initialOwner, 
            rougueToken, 
            dai_usd, 
            daoWallet, 
            penaltyAddress);

        rougueERC = IERC20(rougueToken);
        mockERC20 = new MockERC20(A);
    }

    function testMIN_LOCKUP_PERIOD() public {
        uint256 amount = 1;
        uint256 lockupPeriod = 1 days;
        uint256 apy = 1;

        vm.expectRevert("Lockup period too short");
        rogueStaking.stake(amount, lockupPeriod, apy);
    }

    function teststake() public {
       switchSigner(initialOwner);
        uint256 amount = 10000000;
        uint256 lockupPeriod = 5 days;
        uint256 apy = 1;
              uint256 balanceBefore = rougueERC.balanceOf(0xd1B99D610E0B540045a7FEa744551973329996d6);
              rougueERC.approve(address(rogueStaking), amount);

        rogueStaking.stake(100, lockupPeriod, apy);
             uint256 balanceAfter = rougueERC.balanceOf(0xd1B99D610E0B540045a7FEa744551973329996d6);
         assertGt(balanceBefore, balanceAfter);
    }

    function mkaddr(string memory name) public returns (address) {
        address addr = address(uint160(uint256(keccak256(abi.encodePacked(name)))));
        vm.label(addr, name);
        return addr;
    }

    function switchSigner(address _newSigner) public {
        address foundrySigner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        if (msg.sender == foundrySigner) {
            vm.startPrank(_newSigner);
        } else {
            vm.stopPrank();
            vm.startPrank(_newSigner);
        }
    }

    //forge test --rpc-url https://eth-sepolia.g.alchemy.com/v2/bHwDnavMydGw59bzw1Btshdvhgex3Vb6 --evm-version cancun -vvvvv
}
