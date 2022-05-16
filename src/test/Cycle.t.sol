// SPDX-License-Identifier: AGPL-2.0-only
pragma solidity 0.8.10;

import "ds-test/test.sol";

import { Cycle } from "./utils/Cycle.sol";
import { IERC20 } from "../interfaces/IERC20.sol";
import { ILendingPool } from "../interfaces/ILendingPool.sol";

contract CycleTest is DSTest {
   
    IERC20 constant dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    ILendingPool constant lendingPool = ILendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);

    Cycle public cycle;

    function setUp() public {
        cycle = new Cycle();
    }

    function testCycle() public {
        cycle.fullCycle(dai, lendingPool);

    }
}
