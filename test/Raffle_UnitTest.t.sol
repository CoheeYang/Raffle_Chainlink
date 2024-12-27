// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Test} from "forge-std/Test.sol";
import {Raffle} from "../src/Raffle.sol";
import {RaffleScript} from "../script/RaffleScript.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
contract RaffleUnitTest is Test, HelperConfig {
    Raffle public raffle;
    NetworkConfig public config;
    address public user = makeAddr("user");

    function setUp() public {
        RaffleScript raffleScript = new RaffleScript();
        (raffle, config) = raffleScript.deployContract();
    }

    function test_joinRaffle() public {
        hoax(user, 100 ether);
        raffle.joinRaffle{value: 10 ether}();
        assertEq(raffle.players(0), user);
    }
}
