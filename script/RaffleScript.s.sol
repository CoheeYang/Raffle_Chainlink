paragma// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
contract RaffleScript is HelperConfig {
    ///1.a run function to create a new raffle and choose the right network
    function run() public {
       
       
        vm.startBroadcast();
        NetworkConfig memory config = networkConfigs[block.chainid];
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.keyHash,
            config.subscriptionId
        );
        vm.stopBroadcast();
        return raffle;
    }

}

