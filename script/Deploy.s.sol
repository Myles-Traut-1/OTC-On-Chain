// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {Orderbook} from "../src/contracts/Orderbook.sol";
import {Escrow} from "../src/contracts/Escrow.sol";
import {SettlementEngine} from "../src/contracts/SettlementEngine.sol";

contract Deployer is Script {
    Orderbook public orderbook;
    Escrow public escrow;
    SettlementEngine public settlementEngine;

    function run(
        address _owner
    ) public returns (Orderbook, Escrow, SettlementEngine) {
        vm.startBroadcast(_owner);

        escrow = _deployEscrow();
        settlementEngine = _deploySettlementEngine();
        orderbook = _deployOrderbook(
            address(settlementEngine),
            address(escrow)
        );

        escrow.setOrderbook(address(orderbook));
        settlementEngine.setOrderbook(address(orderbook));

        vm.stopBroadcast();

        return (orderbook, escrow, settlementEngine);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _deployEscrow() internal returns (Escrow) {
        escrow = new Escrow();
        return escrow;
    }

    function _deploySettlementEngine() internal returns (SettlementEngine) {
        settlementEngine = new SettlementEngine();
        return settlementEngine;
    }

    function _deployOrderbook(
        address _escrow,
        address _settlementEngine
    ) internal returns (Orderbook) {
        orderbook = new Orderbook(_escrow, _settlementEngine);
        return orderbook;
    }
}
