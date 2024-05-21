// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {RogueStaking} from "../src/RogueStaking.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/MockDAGoracle.sol";
import "../src/MockDAGtoken.sol";

contract CounterTest is Test {
    RogueStaking public rogueStaking;
    MockDAGoracle public mockDAGoracle;
    MockDAGtoken mockDAGtoken;

    IERC20 rougueERC;

    address initialOwner = 0xd1B99D610E0B540045a7FEa744551973329996d6;
    address rougueToken = 0xa3bb956C5F8Ce6Fb8386e0EBBE82Cba12bBe6EBD;
    address dai_usd = 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19;
    address daoWallet = 0x107Ff7900F4dA6BFa4eB41dBD6f2953ffb41b2B1;
    address penaltyAddress = address(0);

    address A = address(0xA);

    function setUp() public {
        //  vm.createSelectFork("https://eth-sepolia.g.alchemy.com/v2/bHwDnavMydGw59bzw1Btshdvhgex3Vb6");
        A = mkaddr("signer A");
        mockDAGtoken = new MockDAGtoken(1000000000000);
        mockDAGoracle = new MockDAGoracle(1, 1);
        rogueStaking =
            new RogueStaking(initialOwner, address(mockDAGtoken), address(mockDAGoracle), daoWallet, penaltyAddress);

        // rougueERC = IERC20(mockDAGtoken);
    }

    function testMIN_LOCKUP_PERIOD() public {
        uint256 amount = 0;
        uint256 lockupPeriod = 1 days;
        uint256 apy = 1;

        vm.expectRevert("Cannot stake 0");
        rogueStaking.stake(amount, 1);
    }

    // function teststake() public {
    //     switchSigner(initialOwner);
    //     uint256 amount = 10000000;
    //     uint256 lockupPeriod = 5 days;
    //     uint256 apy = 1;
    //     uint256 balanceBefore = rougueERC.balanceOf(0xd1B99D610E0B540045a7FEa744551973329996d6);
    //     rougueERC.approve(address(rogueStaking), amount);

    //     rogueStaking.stake(100, 1);
    //     uint256 balanceAfter = rougueERC.balanceOf(0xd1B99D610E0B540045a7FEa744551973329996d6);
    //     assertGt(balanceBefore, balanceAfter);
    // }

    function teststake() public {
        switchSigner(address(this));
        uint256 amount = 10000000;
        uint256 lockupPeriod = 5 days;
        uint256 apy = 1;
        uint256 balanceBefore = mockDAGtoken.balanceOf(address(this));
        mockDAGtoken.approve(address(rogueStaking), amount);

        rogueStaking.stake(10000000, 1);
        uint256 balanceAfter = mockDAGtoken.balanceOf(address(this));
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
