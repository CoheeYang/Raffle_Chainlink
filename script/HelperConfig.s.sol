// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

/**
 * @author  CoheeYang
 * @title   HelperConfig Contract
 *
 * @dev     To use this contract to help you configure the network,you should import the Helpconfig,
 *          and create a instance of it, then use the getter function of networkConfigs(chainId) to get the
 *          NetworkConfig. Like
 *          HelperConfig config = new HelperConfig();
 *          NetworkConfig memory networkConfig = config.networkConfigs(chainId);
 *
 * @notice  this contract helps to configure the network,since the parameters in constructor
 *          are different in different chain.
 */

contract HelperConfig is Script {
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    /* VRF Mock Values */
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 4e15;
    VRFCoordinatorV2_5Mock vrf_Mock;

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        // Chainlink VRF Variables
        address vrfCoordinator;
        bytes32 keyHash;
        uint256 subscriptionId;
    }

    mapping(uint256 => NetworkConfig) public networkConfigs;

    //@dev construct your mapping here
    constructor() {
        networkConfigs[LOCAL_CHAIN_ID] = getAnvilConfig();
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaConfig();
    }

    /**
     * @notice  LocalChain is slightly different from the other chains,
     *          we need to create a mock if there is no Chainlink VRF on the local chain.
     */
    function getAnvilConfig() public returns (NetworkConfig memory) {
        if (networkConfigs[LOCAL_CHAIN_ID].vrfCoordinator == address(0)) {
            ///then we create a mock
            vm.startBroadcast();
            vrf_Mock = new VRFCoordinatorV2_5Mock(
                MOCK_BASE_FEE,
                MOCK_GAS_PRICE_LINK,
                MOCK_WEI_PER_UNIT_LINK
            );
            vm.stopBroadcast();
        }
        return
            NetworkConfig({
                entranceFee: 0.001 ether,
                interval: 30, //30s
                vrfCoordinator: address(vrf_Mock), //just created above
                keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, //gasLane value does not matter in local chain
                subscriptionId: 0
            });
    }

    /**
     * @notice  use functions instead of state variable to save gas
     * @dev     add more NetworkConfig in the same way.
     * @return  NetworkConfig
     */
    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.001 ether,
                interval: 30, //30s
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, //see in https://docs.chain.link/vrf/v2-5/supported-networks
                keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, //see in the same link, this is a 500 gwei Key Hash
                subscriptionId: 97512311815449508538152162602758259522350113148636008968753952815105412830914 //subscriptionId of your own
            });
    }
}
