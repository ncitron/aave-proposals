// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import { IArcTimelock } from  "./interfaces/IArcTimelock.sol";
import { ILendingPoolConfigurator } from "./interfaces/ILendingPoolConfigurator.sol";

/// @title ArcUpdateProposalPayload
/// @author Governance House
/// @notice Aave ARC parameter update proposal
contract ArcUpdateProposalPayload {

    /*///////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice AAVE ARC LendingPoolConfigurator
    ILendingPoolConfigurator constant configurator = ILendingPoolConfigurator(0x4e1c7865e7BE78A7748724Fa0409e88dc14E67aA);

    /// @notice AAVE ARC timelock
    IArcTimelock arcTimelock = IArcTimelock(0xAce1d11d836cb3F51Ef658FD4D353fFb3c301218);

    /// @notice usdc token
    address constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    /// @notice weth token
    address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @notice wbtc token
    address constant wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    /// @notice aave token
    address constant aave = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
    
    /// @notice The AAVE governance contract calls this to queue up an
    /// @notice action to the AAVE ARC timelock
    function executeQueueTimelock() external {
        
    }

    /// @notice The AAVE ARC timelock delegateCalls this
    function execute() external {
        // address, ltv, liqthresh, bonus
        configurator.configureReserveAsCollateral(usdc, 8300, 8500, 10400);
        configurator.setReserveFactor(usdc, 1000);

        configurator.configureReserveAsCollateral(weth, 8300, 8500, 10500);
        configurator.setReserveFactor(weth, 1000);

        configurator.configureReserveAsCollateral(wbtc, 7000, 7500, 10700);
        configurator.setReserveFactor(wbtc, 2000);

        configurator.configureReserveAsCollateral(aave, 6000, 7000, 10800);
        configurator.setReserveFactor(aave, 0);
    }
}
