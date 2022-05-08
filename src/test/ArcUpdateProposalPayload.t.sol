// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;
pragma abicoder v2;

// testing libraries
import "ds-test/test.sol";
import "forge-std/console.sol";
import {stdCheats} from "forge-std/stdlib.sol";

// contract dependencies
import "./interfaces/Vm.sol";
import "../interfaces/IArcTimelock.sol";
import "../interfaces/IAaveGovernanceV2.sol";
import "../interfaces/IExecutorWithTimelock.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IProtocolDataProvider.sol";
import "../ArcUpdateProposalPayload.sol";

contract ProposalPayloadTest is DSTest, stdCheats {
    Vm vm = Vm(HEVM_ADDRESS);

    address aaveTokenAddress = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;

    address aaveGovernanceAddress = 0xEC568fffba86c094cf06b22134B23074DFE2252c;
    address aaveGovernanceShortExecutor = 0xEE56e2B3D491590B5b31738cC34d5232F378a8D5;
    
    IArcTimelock arcTimelock = IArcTimelock(0xAce1d11d836cb3F51Ef658FD4D353fFb3c301218);
    IAaveGovernanceV2 aaveGovernanceV2 = IAaveGovernanceV2(aaveGovernanceAddress);
    IExecutorWithTimelock shortExecutor = IExecutorWithTimelock(aaveGovernanceShortExecutor);
    IProtocolDataProvider dataProvider = IProtocolDataProvider(0x71B53fC437cCD988b1b89B1D4605c3c3d0C810ea);

    address[] private aaveWhales;

    address private proposalPayloadAddress;
    address private tokenDistributorAddress;
    address private ecosystemReserveAddress;

    address[] private targets;
    uint256[] private values;
    string[] private signatures;
    bytes[] private calldatas;
    bool[] private withDelegatecalls;
    bytes32 private ipfsHash = 0x0;

    uint256 proposalId;

    // tokens
    address constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant aave = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;

    address govHouse = 0x82cD339Fa7d6f22242B31d5f7ea37c1B721dB9C3;

    function setUp() public {
        // aave whales may need to be updated based on the block being used
        // these are sometimes exchange accounts or whale who move their funds

        // select large holders here: https://etherscan.io/token/0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9#balances
        aaveWhales.push(0xBE0eB53F46cd790Cd13851d5EFf43D12404d33E8);
        aaveWhales.push(0x26a78D5b6d7a7acEEDD1e6eE3229b372A624d8b7);
        aaveWhales.push(0x2FAF487A4414Fe77e2327F0bf4AE2a264a776AD2);

        // create proposal is configured to deploy a Payload contract and call execute() as a delegatecall
        // most proposals can use this format - you likely will not have to update this
        _createProposal();

        // these are generic steps for all proposals - no updates required
        _voteOnProposal();
        _skipVotingPeriod();
        _queueProposal();
        _skipQueuePeriod();
    }

    function testExecuteLtv() public {
        _executeProposal();

        uint256 ltv;
        uint256 liqThresh;
        uint256 liqBonus;
        uint256 reserveFactor;

        (, ltv, liqThresh, liqBonus, reserveFactor,,,,,) = dataProvider.getReserveConfigurationData(usdc);
        assertEq(ltv, 8550);
        assertEq(liqThresh, 8600);
        assertEq(liqBonus, 10450);
        assertEq(reserveFactor, 1000);

        (, ltv, liqThresh, liqBonus, reserveFactor,,,,,) = dataProvider.getReserveConfigurationData(weth);
        assertEq(ltv, 8300);
        assertEq(liqThresh, 8500);
        assertEq(liqBonus, 10500);
        assertEq(reserveFactor, 1000);

        (, ltv, liqThresh, liqBonus, reserveFactor,,,,,) = dataProvider.getReserveConfigurationData(wbtc);
        assertEq(ltv, 7000);
        assertEq(liqThresh, 7500);
        assertEq(liqBonus, 10700);
        assertEq(reserveFactor, 2000);

        (, ltv, liqThresh, liqBonus, reserveFactor,,,,,) = dataProvider.getReserveConfigurationData(aave);
        assertEq(ltv, 6000);
        assertEq(liqThresh, 7000);
        assertEq(liqBonus, 10800);
        assertEq(reserveFactor, 0);
    }

    function testExecuteAaveRefund() public {
        uint256 initAave = IERC20(aave).balanceOf(govHouse);
        _executeProposal();
        uint256 finalAave = IERC20(aave).balanceOf(govHouse);

        assertEq(finalAave - initAave, 10 ether);
    }

    function _executeProposal() public {
        // execute proposal
        aaveGovernanceV2.execute(proposalId);

        // confirm state after
        IAaveGovernanceV2.ProposalState state = aaveGovernanceV2.getProposalState(proposalId);
        assertEq(uint256(state), uint256(IAaveGovernanceV2.ProposalState.Executed), "PROPOSAL_NOT_IN_EXPECTED_STATE");

        // execute arc timelock
        vm.warp(block.timestamp + 172800);
        uint actionNum = arcTimelock.getActionsSetCount() - 1;
        arcTimelock.execute(actionNum);
    }

    /*******************************************************************************/
    /******************     Aave Gov Process - Create Proposal     *****************/
    /*******************************************************************************/

    function _createProposal() public {
        // Uncomment to deploy new implementation contracts for testing
        // tokenDistributorAddress = deployCode("TokenDistributor.sol:TokenDistributor");
        // ecosystemReserveAddress = deployCode("AaveEcosystemReserve.sol:AaveEcosystemReserve");

        ArcUpdateProposalPayload proposalPayload = new ArcUpdateProposalPayload();
        proposalPayloadAddress = address(proposalPayload);

        bytes memory emptyBytes;

        targets.push(proposalPayloadAddress);
        values.push(0);
        signatures.push("executeQueueTimelock()");
        calldatas.push(emptyBytes);
        withDelegatecalls.push(true);

        vm.prank(aaveWhales[0]);
        aaveGovernanceV2.create(shortExecutor, targets, values, signatures, calldatas, withDelegatecalls, ipfsHash);
        proposalId = aaveGovernanceV2.getProposalsCount() - 1;
    }

    /*******************************************************************************/
    /***************     Aave Gov Process - No Updates Required      ***************/
    /*******************************************************************************/

    function _voteOnProposal() public {
        IAaveGovernanceV2.ProposalWithoutVotes memory proposal = aaveGovernanceV2.getProposalById(proposalId);
        vm.roll(proposal.startBlock + 1);
        for (uint256 i; i < aaveWhales.length; i++) {
            vm.prank(aaveWhales[i]);
            aaveGovernanceV2.submitVote(proposalId, true);
        }
    }

    function _skipVotingPeriod() public {
        IAaveGovernanceV2.ProposalWithoutVotes memory proposal = aaveGovernanceV2.getProposalById(proposalId);
        vm.roll(proposal.endBlock + 1);
    }

    function _queueProposal() public {
        aaveGovernanceV2.queue(proposalId);
    }

    function _skipQueuePeriod() public {
        IAaveGovernanceV2.ProposalWithoutVotes memory proposal = aaveGovernanceV2.getProposalById(proposalId);
        vm.warp(proposal.executionTime + 1);
    }

    function testSetup() public {
        IAaveGovernanceV2.ProposalWithoutVotes memory proposal = aaveGovernanceV2.getProposalById(proposalId);
        assertEq(proposalPayloadAddress, proposal.targets[0], "TARGET_IS_NOT_PAYLOAD");

        IAaveGovernanceV2.ProposalState state = aaveGovernanceV2.getProposalState(proposalId);
        assertEq(uint256(state), uint256(IAaveGovernanceV2.ProposalState.Queued), "PROPOSAL_NOT_IN_EXPECTED_STATE");
    }
}
