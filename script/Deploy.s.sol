// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {Orderbook} from "../src/contracts/Orderbook.sol";
import {Escrow} from "../src/contracts/Escrow.sol";
import {SettlementEngine} from "../src/contracts/SettlementEngine.sol";
import {UUPSProxy} from "../src/contracts/UUPSProxy.sol";

contract Deployer is Script {
    Orderbook public orderbook;
    Orderbook public orderbookImplementation;

    UUPSProxy public orderbookProxy;

    Escrow public escrow;
    Escrow public escrowImplementation;

    UUPSProxy public escrowProxy;

    SettlementEngine public settlementEngine;

    function run(
        address _owner
    ) public returns (Orderbook, Escrow, SettlementEngine) {
        vm.startBroadcast(_owner);

        escrow = _deployEscrow();
        settlementEngine = _deploySettlementEngine();
        orderbook = _deployOrderbook();

        _initContracts(
            address(orderbook),
            address(settlementEngine),
            address(escrow)
        );

        settlementEngine.setOrderbook(address(orderbook));

        vm.stopBroadcast();

        return (orderbook, escrow, settlementEngine);
    }

    function deployOrderbook(address _owner) public returns (Orderbook) {
        vm.startBroadcast(_owner);
        orderbook = _deployOrderbook();
        vm.stopBroadcast();
        return orderbook;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _deployEscrow() internal returns (Escrow) {
        escrowImplementation = new Escrow();
        escrowProxy = new UUPSProxy(address(escrowImplementation), "");
        escrow = Escrow(payable(address(escrowProxy)));
        return escrow;
    }

    function _deploySettlementEngine() internal returns (SettlementEngine) {
        settlementEngine = new SettlementEngine();
        return settlementEngine;
    }

    function _deployOrderbook() internal returns (Orderbook) {
        orderbookImplementation = new Orderbook();
        orderbookProxy = new UUPSProxy(address(orderbookImplementation), "");
        orderbook = Orderbook(address(orderbookProxy));
        return orderbook;
    }

    function _initContracts(
        address _orderbook,
        address _settlementEngine,
        address _escrow
    ) internal {
        orderbook.initialize(_settlementEngine, _escrow);
        escrow.initialize();
        escrow.setOrderbook(_orderbook);
    }
}
