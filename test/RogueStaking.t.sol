// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
 import {RogueStaking} from "../src/RogueStaking.sol";
 import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CounterTest is Test {
     RogueStaking public rogueStaking;

     IERC20 rougueToken;

    address initialOwner = 0x107Ff7900F4dA6BFa4eB41dBD6f2953ffb41b2B1;
    address rougeERC = address(0xb);
    address dai_usd = 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19;
    address daoWallet = 0x107Ff7900F4dA6BFa4eB41dBD6f2953ffb41b2B1;
    address penaltyAddress = address(0);



    function setUp() public {
         rogueStaking = new RogueStaking(initialOwner,rougeERC,dai_usd,daoWallet,penaltyAddress);
         rougueToken =  IERC20(initialOwner);

    }

    function testMIN_LOCKUP_PERIOD() public {
        uint amount = 1;
        uint lockupPeriod = 1 days;
        uint apy = 1;
      
        vm.expectRevert("Lockup period too short");
        rogueStaking.stake(amount, lockupPeriod, apy);

    }
    function teststake() public {
        //switchSigner(initialOwner);
        uint amount = 100;
        uint lockupPeriod = 5 days;
        uint apy = 1;
    //      uint256 balanceBefore = rougueToken.balanceOf(A);
    //       rougueToken.approve(address(rogueStaking), amount);
      
    rogueStaking.stake(amount, lockupPeriod, apy);
    //     uint256 balanceAfter = rougueToken.balanceOf(A);
       // assertEq(balanceAfter, balanceBefore);



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

}
