// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {LightAccountFactory} from "../src/LightAccountFactory.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

// @notice Deploys LightAccountFactory to the address `0x000000893A26168158fbeaDD9335Be5bC96592E2`
// @dev Note: Script uses EntryPoint at address 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
// @dev To run: `forge script script/Deploy_LightAccountFactory.s.sol:Deploy_LightAccountFactory --broadcast --rpc-url ${RPC_URL} --verify -vvvv`
contract Deploy_LightAccountFactory is Script {
    using stdJson for string;

    error InitCodeHashMismatch(bytes32 initCodeHash);
    error DeployedAddressMismatch(address deployed);

    address entryPoint;
    address expectedAddress;
    uint256 salt;

    function readInputsFromPath() internal {
        string memory json = vm.readFile("input.json");
        entryPoint = json.readAddress("$.entryPoint");
        expectedAddress = json.readAddress("$.address");
        salt = json.readUint("$.salt");
    }

    function run() public {

        readInputsFromPath();
        vm.startBroadcast();

        IEntryPoint entryPointContract = IEntryPoint(payable(entryPoint));

        console.log("********************************");
        console.log("******** Deploy Inputs *********");
        console.log("********************************");
        console.log("Entrypoint Address is:");
        console.logAddress(address(entryPointContract));
        console.log("********************************");
        console.log("******** Deploy ...... *********");
        console.log("********************************");

        LightAccountFactory factory = deployImpl(bytes32(salt), expectedAddress, entryPointContract);

        console.log("LightAccountFactory address:");
        console.logAddress(address(factory));

        console.log("Implementation address:");
        console.logAddress(address(factory.accountImplementation()));
        vm.stopBroadcast();
    }

    function deployImpl(bytes32 saltBytes, address expected, IEntryPoint ep) private returns (LightAccountFactory) {
        address addr = Create2.computeAddress(
            saltBytes, keccak256(abi.encodePacked(type(LightAccountFactory).creationCode, abi.encode(ep))), CREATE2_FACTORY
        );
        console.logAddress(addr);
        require(addr == expected, "Expected address is not the same as computed for impl");
        if (addr.code.length > 0) {
            console.log("VerifyingPaymaster impl already deployed. Skipping");
            return LightAccountFactory(payable(addr));
        }

        LightAccountFactory impl = new LightAccountFactory{salt: saltBytes}(ep);
        require(address(impl) == addr, "Impl address did not match predicted");
        return impl;
    }

}
