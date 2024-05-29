// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {LightAccountFactory} from "../src/LightAccountFactory.sol";

// @notice Deploys LightAccountFactory to the address `0x000000893A26168158fbeaDD9335Be5bC96592E2`
// @dev Note: Script uses EntryPoint at address 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
// @dev To run: `forge script script/Deploy_LightAccountFactory.s.sol:Deploy_LightAccountFactory --broadcast --rpc-url ${RPC_URL} --verify -vvvv`
contract Deploy_LightAccountFactory is Script {
    using stdJson for string;

    error InitCodeHashMismatch(bytes32 initCodeHash);
    error DeployedAddressMismatch(address deployed);

    address entryPoint;
    address expectedAddress;
    bytes32 expectedInitCodeHash;
    uint256 salt;

    function readInputsFromPath() internal {
        string memory json = vm.readFile("input.json");
        entryPoint = json.readAddress("$.entryPoint");
        expectedAddress = json.readAddress("$.address");
        expectedInitCodeHash = json.readBytes32("$.initCodeHash");
        salt = json.readUint("$.salt");
    }

    function run() public {

        readInputsFromPath();
        vm.startBroadcast();

        IEntryPoint entryPointContract = IEntryPoint(payable(entryPoint));

        // Init code hash check
        bytes32 initCodeHash = keccak256(
            abi.encodePacked(type(LightAccountFactory).creationCode, bytes32(uint256(uint160(address(entryPointContract)))))
        );

        if (initCodeHash != expectedInitCodeHash) {
            revert InitCodeHashMismatch(initCodeHash);
        }

        console.log("********************************");
        console.log("******** Deploy Inputs *********");
        console.log("********************************");
        console.log("Entrypoint Address is:");
        console.logAddress(address(entryPointContract));
        console.log("********************************");
        console.log("******** Deploy ...... *********");
        console.log("********************************");

        LightAccountFactory factory =
        new LightAccountFactory{salt: bytes32(salt)}(entryPointContract);

        // Deployed address check
        if (address(factory) != expectedAddress) {
            revert DeployedAddressMismatch(address(factory));
        }

        console.log("LightAccountFactory address:");
        console.logAddress(address(factory));

        console.log("Implementation address:");
        console.logAddress(address(factory.accountImplementation()));
        vm.stopBroadcast();
    }
}
