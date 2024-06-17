// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {LightAccountFactory} from "../src/LightAccountFactory.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

contract Deploy_LightAccountFactory is Script {
    using stdJson for string;

    IEntryPoint entryPoint;
    address entryPointAddr;
    address expectedAddress;
    address owner;
    uint256 salt;
    uint256 stakeAmount;
    uint256 unstakeDelay;

    error InitCodeHashMismatch(bytes32 initCodeHash);
    error DeployedAddressMismatch(address deployed);

    function readInputsFromPath() internal {
        string memory json = vm.readFile("input.json");
        entryPointAddr = json.readAddress("$.entryPoint");
        entryPoint = IEntryPoint(payable(entryPointAddr));
        expectedAddress = json.readAddress("$.address");
        owner = json.readAddress("$.owner");
        salt = json.readUint("$.salt");
        stakeAmount = json.readUint("$.stakeAmount");
        unstakeDelay = json.readUint("$.unstakeDelay");
    }


    function run() public {
        readInputsFromPath();
        vm.startBroadcast();

        console.log("********************************");
        console.log("******** Deploy Inputs *********");
        console.log("********************************");
        console.log("Owner:", owner);
        console.log("Entrypoint:", address(entryPoint));
        console.log();
        console.log("********************************");
        console.log("******** Deploying.... *********");
        console.log("********************************");

        LightAccountFactory factory = deployImpl(bytes32(salt), expectedAddress, owner, entryPoint);

        _addStakeForFactory(address(factory));
        console.log("LightAccountFactory:", address(factory));
        console.log("LightAccount:", address(factory.ACCOUNT_IMPLEMENTATION()));
        console.log();

        vm.stopBroadcast();
    }


    function deployImpl(bytes32 saltBytes, address expected, address ownerAddr, IEntryPoint ep) private returns (LightAccountFactory) {
        address addr = Create2.computeAddress(
            saltBytes, keccak256(abi.encodePacked(type(LightAccountFactory).creationCode, abi.encode(ownerAddr, ep))), CREATE2_FACTORY
        );
        console.logAddress(addr);
        require(addr == expected, "Expected address is not the same as computed for impl");
        if (addr.code.length > 0) {
            console.log("VerifyingPaymaster impl already deployed. Skipping");
            return LightAccountFactory(payable(addr));
        }

        LightAccountFactory impl = new LightAccountFactory{salt: saltBytes}(ownerAddr, ep);
        require(address(impl) == addr, "Impl address did not match predicted");
        return impl;
    }


    function _addStakeForFactory(address factoryAddr) internal {
        uint256 currentStakedAmount = entryPoint.getDepositInfo(factoryAddr).stake;
        uint256 stakeRequired = stakeAmount - currentStakedAmount;
        if (stakeRequired > 0) {
            LightAccountFactory(payable(factoryAddr)).addStake{value: stakeRequired}(uint32(unstakeDelay), stakeRequired);
            console.log("******** Add Stake Verify *********");
            console.log("Staked factory: ", factoryAddr);
            console.log("Stake amount: ", entryPoint.getDepositInfo(factoryAddr).stake);
            console.log("Unstake delay: ", entryPoint.getDepositInfo(factoryAddr).unstakeDelaySec);
            console.log("******** Stake Verify Done *********");
        } else {
            console.log("Contract already staked");
        }
    }
}
