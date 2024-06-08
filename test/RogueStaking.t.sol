// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console, console2} from "forge-std/Test.sol";
import {RogueStaking} from "../src/RogueStaking.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/MockDAGoracle.sol";
import "../src/MockDAGtoken.sol";
import {Governance} from "../src/Governance.sol";
import {RogueToken} from "../src/RougeToken.sol";
import {TimeLock} from "../src/Timelock.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {Vm} from "forge-std/Vm.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

contract CounterTest is Test {
    RogueStaking public rogueStaking;
    MockDAGoracle public mockDAGoracle;
    MockDAGtoken mockDAGtoken;

    IERC20 rougueERC;
    Governance internal governor;
    RogueToken internal governanceToken;
    TimeLock internal timeLock;

    uint8 internal voteWay = 1;
    string internal reason = "we build the next gen decentralized ecosystem";

     // Constants for the proposal
    uint256 internal constant NEW_INDEX = 1;
    uint256 internal constant NEW_APY = 80; // APY in basis points
    uint256 internal constant NEW_LOCKUP_PERIOD = 30 days;
    uint256 internal constant NEW_PENALTY = 5; // penalty in percentage

    uint256 internal constant MIN_DELAY = 3600;
 
  
    string internal constant FUNC_SIG =  "updateStakingOption(uint256,uint256,uint256,uint256)";
    string internal constant PROPOSAL_DESCRIPTION = "Build on ChainFi!";

    // address initialOwner = 0xd1B99D610E0B540045a7FEa744551973329996d6;
    address rougueToken = 0xa3bb956C5F8Ce6Fb8386e0EBBE82Cba12bBe6EBD;
    address dai_usd = 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19;
    address daoWallet = 0x107Ff7900F4dA6BFa4eB41dBD6f2953ffb41b2B1;
    address penaltyAddress = address(0);
    address deployer = address(this);

    address A = address(0xA);

    function setUp() public {
        //  vm.createSelectFork("https://eth-sepolia.g.alchemy.com/v2/bHwDnavMydGw59bzw1Btshdvhgex3Vb6");
        A = mkaddr("signer A");
        mockDAGtoken = new MockDAGtoken(1000000000000);
        mockDAGoracle = new MockDAGoracle(1, 1);

        string memory name = "RougeToken";
        string memory symbol = "RTN";

        governanceToken = new RogueToken(name, symbol, 100000, deployer);

        governanceToken.delegate(deployer);

        console2.log("Deploying TimeLock and waiting for confirmations...");

        uint256 minDelay = MIN_DELAY;
        address[] memory proposers;
        address[] memory executors;
        address admin = deployer;
        timeLock = new TimeLock(minDelay, proposers, executors, admin);
        IVotes token = governanceToken;
        TimelockController timelock = timeLock;

        governor = new Governance(name, timeLock, governanceToken, admin);

        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.CANCELLER_ROLE();

        timeLock.grantRole(proposerRole, address(governor));
        timeLock.grantRole(executorRole, address(0));
        timeLock.grantRole(adminRole, deployer);

        rogueStaking =
            new RogueStaking((address(timeLock)), 
            address(governanceToken), 
            address(mockDAGoracle), 
            daoWallet, 
            penaltyAddress);
    }

    function testMIN_LOCKUP_PERIOD() public {
        uint256 amount = 0;
        uint256 lockupPeriod = 1 days;
        uint256 apy = 1;

        vm.expectRevert("Cannot stake 0");
        rogueStaking.stake(amount, 1);
    }

    function teststake() public {
        switchSigner(address(this));
        uint256 amount = 1000;
        uint256 lockupPeriod = 5 days;
        uint256 apy = 1;
        uint256 balanceBefore = governanceToken.balanceOf(address(this));
        governanceToken.approve(address(rogueStaking), amount);

        rogueStaking.stake(1000, 1);
        uint256 balanceAfter = governanceToken.balanceOf(address(this));
        assertGt(balanceBefore, balanceAfter);
    }

    function testMultipleStakeOption() public {
        switchSigner(address(this));
        uint256 amount = 10000000;
        governanceToken.approve(address(rogueStaking), amount);
        rogueStaking.stake(1000, 1);
        rogueStaking.stake(1000, 2);
    }

    function testMultipleStakeOptionStakeAmont() public {
        switchSigner(address(this));
        uint256 amount = 10000000;
        governanceToken.approve(address(rogueStaking), amount);
        rogueStaking.stake(1000, 1);
        vm.expectRevert("Allowance not enough");
        rogueStaking.stake(10000000, 2);
    }

    function testINVALIDSTAKEOPTION() public {
        switchSigner(address(this));
        uint256 amount = 10000000;
        governanceToken.approve(address(rogueStaking), amount);
        vm.expectRevert("Invalid staking option");
        rogueStaking.stake(10000000, 10);
    }

    function testWithdraw() public {
        switchSigner(address(this));
        uint256 amount = 1000;
        governanceToken.approve(address(rogueStaking), amount);
        rogueStaking.stake(1000, 1);
        vm.warp(block.timestamp + 10 days);
        rogueStaking.withdraw(1, 100);
    }

    function testMultipleWithdraw() public {
        switchSigner(address(this));
        uint256 amount = 1000;
        governanceToken.approve(address(rogueStaking), amount);
        rogueStaking.stake(1000, 1);
        vm.warp(block.timestamp + 10 days);
        rogueStaking.withdraw(1, 100);
        rogueStaking.withdraw(1, 100);
    }
    function test_ProposesVotesWaitsQueuesAndThenExecutes() external {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        // propose
        bytes memory encodedFunctionCall = abi.encodeWithSignature(
            FUNC_SIG, 
            NEW_INDEX,
            NEW_APY,
            NEW_LOCKUP_PERIOD,
            NEW_PENALTY);

        targets[0] = address(rogueStaking);
        values[0] = 0;
        calldatas[0] = encodedFunctionCall;
        string memory description = PROPOSAL_DESCRIPTION;

        vm.recordLogs();
        governor.propose(targets, values, calldatas, description);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        Governance.ProposalState proposalState;
        uint256 proposalId = abi.decode(entries[0].data, (uint256));
        console2.log("entries data is: ", proposalId);
        proposalState = governor.state(proposalId);
        console2.log("First Current Proposal State: ", uint256(proposalState));
        assertEq(uint256(proposalState), 0);
        assert(proposalState == IGovernor.ProposalState.Pending);

        vm.roll(block.number + 2);

        // vote
        governor.castVoteWithReason(proposalId, voteWay, reason);

        proposalState = governor.state(proposalId);
        console2.log("second Current Proposal State: ", uint256(proposalState));
        assertEq(uint256(proposalState), 1);
        assert(proposalState == IGovernor.ProposalState.Active);

        vm.roll(block.number + 2);

        // queue & execute
        bytes32 descriptionHash = keccak256(bytes(PROPOSAL_DESCRIPTION));

        targets[0] = address(rogueStaking);
        values[0] = 0;
        calldatas[0] = encodedFunctionCall;

        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp +  1 days );
        vm.roll(block.number + 1);

        proposalState = governor.state(proposalId);
        console2.log("Current Proposal State: ", uint256(proposalState));
        assertEq(uint256(proposalState), 5);
        assert(proposalState == IGovernor.ProposalState.Queued);

        console2.log("Executing...");

        targets[0] = address(rogueStaking);
        values[0] = 0;
        calldatas[0] = encodedFunctionCall;
        governor.execute(targets, values, calldatas, descriptionHash);
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
