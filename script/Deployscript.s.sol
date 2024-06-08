// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {Governance} from "../src/Governance.sol";
import {RogueToken} from "../src/RougeToken.sol";
import {TimeLock} from "../src/Timelock.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract DeployScript is Script {
    uint256 internal constant QUORUM_PERCENTAGE = 4; // Need 4% of voters to pass
    uint256 internal constant MIN_DELAY = 3600; // 1 hour - after a vote passes, you have 1 hour before you can enact
    uint256 internal constant VOTING_PERIOD = 5; // blocks
    uint256 internal constant VOTING_DELAY = 1; // 1 Block - How many blocks till a proposal vote becomes active

    Governance internal governor;
    RogueToken internal governanceToken;
    TimeLock internal timeLock;

    // use deployerPrivateKey if private key is used
    // uint256 internal deployerPrivateKey;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);
        // use deployerPrivateKey if private key is used

        /// 01-deploy-rougetoken-token ///
        console2.log("----------------------------------------------------");
        console2.log("Deploying GovernanceToken and waiting for confirmations...");
        string memory name = "RougeToken";
        string memory symbol = "RTN";

        governanceToken = new RogueToken(name, symbol, 100000, msg.sender);

        console2.log("GovernanceToken at", address(governanceToken));

        console2.log("Delegating to", deployer);

        governanceToken.delegate(deployer);
        console2.log("Checkpoints: ", governanceToken.numCheckpoints(deployer));

        console2.log("Delegated!");

        /// 02-deploy-time-lock ///
        console2.log("----------------------------------------------------");
        console2.log("Deploying TimeLock and waiting for confirmations...");

        uint256 minDelay = MIN_DELAY;
        address[] memory proposers;
        address[] memory executors;
        address admin = deployer;
        timeLock = new TimeLock(minDelay, proposers, executors, admin);

        console2.log("GovernanceToken at", address(timeLock));

        /// 03-deploy-governor-contract ///
        console2.log("----------------------------------------------------");
        console2.log("Deploying GovernorContract and waiting for confirmations...");

        IVotes token = governanceToken;
        TimelockController timelock = timeLock;

        governor = new Governance(name, timeLock, governanceToken, admin);

        console2.log("GovernorContract at", address(governor));

        console2.log("----------------------------------------------------");
        console2.log("Setting up contracts for roles...");

        // would be great to use multicall here.lol...
        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.CANCELLER_ROLE();

        timeLock.grantRole(proposerRole, address(governor));
        timeLock.grantRole(executorRole, address(0));
        timeLock.grantRole(adminRole, deployer);

        console2.log("----------------------------------------------------");

        vm.stopBroadcast();
    }
}
//source .env
//forge script --chain sepolia script/Deployscript.s.sol:DeployScript --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv
