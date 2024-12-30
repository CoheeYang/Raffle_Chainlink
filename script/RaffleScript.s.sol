// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {console} from "forge-std/console.sol";
contract RaffleScript is HelperConfig {
    uint256 public constant fundSub_Amount = 10 ether;
    // address public recentRaffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);

    ///1.a run function to create a new raffle and choose the right network
    function run() public returns (Raffle, NetworkConfig memory) {
        //1. get the Networkconfig struct
        NetworkConfig memory config = networkConfigs[block.chainid];

        //2. Complete the config, by creating a subscription,if there is no subscription
        if (config.subscriptionId == 0) {
            config.subscriptionId = createSubscription(config);
            console.log("the subscriptionId is ", config.subscriptionId);
        }

        ///@notice  remember to distinguish the msg.sender and the contract address
        ///         this scriptAddress will deploy the contracts,and the owner of subscription
        ///         while msg.sender is the DefaultSender for (forge script),and the address of
        ///         the test contract if you are using forge test
        console.log("msg.sender is ", msg.sender);
        console.log("the contract address is ", address(this));

        //3. fund the subscription
        fundSubscription(config, fundSub_Amount);

        //4. deploy the contract with complete config
        Raffle newRaffle = deployContract(config);

        //5. add the consumer to the subscription
        addConsumer(config, address(newRaffle));

        //return the complete raffle contract and the config
        return (newRaffle, config);
    }

    /**
     * @notice  Deploy a new Raffle contract, and return a struct of NetworkConfig.
     *
     * @return  Raffle,NetworkConfig
     *
     */
    function deployContract(NetworkConfig memory config) public returns (Raffle) {
        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.keyHash,
            config.subscriptionId
        );
        vm.stopBroadcast();
        return (raffle);
    }

    ///如果是本地部署的，需要mock合约给一个subscriptionId来创建订单
    function createSubscription(NetworkConfig memory config) public returns (uint256) {
        vm.startBroadcast(config.account);
        VRFCoordinatorV2_5Mock vrfInstance = VRFCoordinatorV2_5Mock(config.vrfCoordinator);
        vm.stopBroadcast();
        uint256 subId = vrfInstance.createSubscription();
        return subId;
    }

    function fundSubscription(NetworkConfig memory config, uint256 amount) public {
        console.log("the vrfAddress is ", config.vrfCoordinator);
        console.log("the subId is ", config.subscriptionId);
        console.log("the linkaddress is ", config.link);
        console.log("the chainId is", block.chainid);
        if (block.chainid == LOCAL_CHAIN_ID) {
            ///
            ///@notice  如果只是本地部署，直接调用fundSubscription
            ///         就可以完成fund
            vm.startBroadcast(config.account);
            VRFCoordinatorV2_5Mock(config.vrfCoordinator).fundSubscription(config.subscriptionId, amount);
            vm.stopBroadcast();
        } else {
            ///
            ///@notice  如果是在测试链上，需要调用link的transferAndCall
            ///
            vm.startBroadcast(config.account);
            LinkToken(config.link).transferAndCall(config.vrfCoordinator, amount, abi.encode(config.subscriptionId));
            vm.stopBroadcast();
        }
    }

    /**
     * @notice  .To add a consumer, msg.sender must be the owner of the subscription.
     */
    function addConsumer(NetworkConfig memory config, address consumer) public {
        vm.startBroadcast(config.account);
        VRFCoordinatorV2_5Mock(config.vrfCoordinator).addConsumer(config.subscriptionId, consumer);
        vm.stopBroadcast();
    }
}
