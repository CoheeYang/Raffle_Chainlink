// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Test} from "forge-std/Test.sol";
import {Raffle} from "../src/Raffle.sol";
import {RaffleScript} from "../script/RaffleScript.s.sol";
import {console} from "forge-std/console.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleUnitTest is Test {
    Raffle public raffle;
    HelperConfig.NetworkConfig public config;
    address public user = makeAddr("user");
    uint256 entranceFee;
    uint256 interval;
    // Chainlink VRF Variables
    address vrfCoordinator;
    bytes32 keyHash;
    uint256 subscriptionId;

    function setUp() public {
        RaffleScript raffleScript = new RaffleScript();
        (raffle, config) = raffleScript.run();
        ///补充raffle的构造函数参数
        entranceFee = config.entranceFee;
        interval = config.interval;
        // Chainlink VRF Variables
        vrfCoordinator = config.vrfCoordinator;
        keyHash = config.keyHash;
        subscriptionId = config.subscriptionId;

        vm.deal(user, 100 ether);
    }

    /**
     * @notice  several test you should know
     *          1.assertEq to test certain output
     *          2.expectRever(raffle.error().selector)
     *          3.eventEmit
     *          4.vm.warp() to set the block.timestamp and vm.roll() to roll the block
     *
     */

    function test_joinRaffle() public {
        vm.prank(user);
        raffle.joinRaffle{value: 10 ether}();
        assertEq(raffle.players(0), user);
    }

    /**
     * @notice  test the raffle when the raffle is closed,
     *          this should revert
     *
     * @dev     .
     */
    function test_performUpkeep() public {
        vm.startPrank(user);
        ///1.check the value is changed properly
        console.log("the raffleState is ", uint256(raffle.raffleState()));
        raffle.joinRaffle{value: 10 ether}();
        vm.warp(block.timestamp + interval + 1); ///the interval is defined in the HelperConfig,but we dnk if this can get it
        raffle.performUpkeep("");
        console.log("the new raffleState is ", uint256(raffle.raffleState()));

        ///2.check the revert when the raffle is closed
        // vm.expectRevert(abi.encodeWithSelector(Raffle.upkeep_notNeeded.selector, 1, 2));
        vm.expectRevert();
        raffle.performUpkeep("");
    }

    modifier setTest() {
        vm.startPrank(user);
        raffle.joinRaffle{value: 10 ether}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function test_performUpkeep_eventEmit() public setTest {
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        console.log("requestId is ", uint(requestId));
        assert(requestId > 0);
    }

    function test_fullfillRandomWords(uint256 randomRequest) public setTest {
        vm.expectRevert();
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequest, address(raffle));
    }
}
