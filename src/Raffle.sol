// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
// /**
//  * @author CoheeYang .
//  * @title  Raffle Contract .
//  * @dev    Chainlik VRF:v2.5 .
//  * @notice  .
//  */

contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    /**
     * Type Declaration *
     */
    enum RaffleState {
        OPEN,
        CLOSED
    }
    RaffleState private raffleState = RaffleState.OPEN;

    /**
     * State Variables *
     */
    uint256 entranceFee;
    address[] public players;
    uint256 private winnerIndex;
    uint256 private interval;
    uint256 private lastTimeStamp;
    // Chainlink VRF Variables
    address private immutable vrfCoordinator;
    uint256 private immutable subscriptionId;
    bytes32 private immutable keyHash;
    uint32 private constant callback_GasLimit = 100000;
    uint16 private constant request_Confirmations = 3;
    uint32 private constant numberOfWords = 1;

    event RaffleEnter(address indexed player, uint256 indexed value);
    event WinnerPicked(address winner);
    event ReturnedRandomness(uint256[] randomWords);

    error notEnough_EntranceFee();
    error payment_fail(address player);
    error raffleClosed();
    error upkeep_notNeeded(
        bool e_raffleIsOpen,
        bool e_intervalPassed,
        bool e_hasPlayers,
        bool e_hasBalance
    );

    constructor(
        uint256 _entranceFee,
        uint256 _interval,
        // Chainlink VRF Variables
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint256 _subscriptionId
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        entranceFee = _entranceFee;
        interval = _interval;
        lastTimeStamp = block.timestamp;

        // Chainlink VRF Variables
        vrfCoordinator = _vrfCoordinator;
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
    }

    function joinRaffle() external payable {
        if (msg.value <= entranceFee) {
            revert notEnough_EntranceFee();
        }
        if (raffleState == RaffleState.CLOSED) {
            revert raffleClosed();
        }
        players.push(msg.sender);
        emit RaffleEnter(msg.sender, msg.value);
    }

    ////上chainlink VRF
    function requestRandomWords() external onlyOwner {
        // Will revert if subscription is not set and funded.
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 randomNumber = randomWords[0];
        require(
            block.timestamp >= lastTimeStamp + interval,
            "The interval has not passed yet"
        );
        ///1.Reset the state
        raffleState == RaffleState.CLOSED;
        lastTimeStamp = block.timestamp;
        uint256 playerLength = players.length;
        players = new address[](0);

        ///2.Pick the winner
        winnerIndex = randomNumber % playerLength;
        address payable winner = payable(players[winnerIndex]);
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert payment_fail(winner);
        } else {
            emit WinnerPicked(winner);
        }
    }

    ////////automation

    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = players.length > 0;
        bool intervalPassed = block.timestamp >= lastTimeStamp + interval;
        bool raffleIsOpen = raffleState == RaffleState.OPEN;

        upkeepNeeded = (hasBalance &&
            hasPlayers &&
            intervalPassed &&
            raffleIsOpen);

        return (upkeepNeeded, "");
    }

    /**
     * @notice  这个函数谁都能用，得保证安全性.
     * @dev this function is called when the upkeep is needed. and it needs to change the value of
     * raffleState to make sure no double calls are made.
     */
    function performUpkeep(bytes calldata /* performData */) external override {
        ///检查upkeep变量
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert upkeep_notNeeded(
                raffleState == RaffleState.OPEN,
                block.timestamp >= lastTimeStamp + interval,
                players.length > 0,
                address(this).balance > 0
            );
        }
        ///关闭raffle避免重入
        raffleState = RaffleState.CLOSED;

        ///请求随机数
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subscriptionId,
                requestConfirmations: request_Confirmations,
                callbackGasLimit: callback_GasLimit,
                numWords: numberOfWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }
}
