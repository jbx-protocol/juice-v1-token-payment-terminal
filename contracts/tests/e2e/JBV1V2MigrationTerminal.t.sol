// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '../../interfaces/IJBV1V2MigrationTerminal.sol';
import '../../JBV1V2MigrationTerminal.sol';

import './helpers/TestBaseWorkflow.sol';

contract TestE2EJBV1V2Terminal is TestBaseWorkflow {
  JBV1V2Terminal migrationTerminal;

  function setUp() public override {
    super.setUp();

    migrationTerminal = new JBV1V2Terminal(
      _jbOperatorStore,
      _jbProjects,
      _jbDirectory,
      _ticketBoothV1
    );
  }

  function testMigration_PassWithUnclaimedToken() public {
    vm.prank(_beneficiary);
    _terminalV1_1.pay{value: 1 ether}(
      _projectIdV1,
      _beneficiary,
      'lfg',
      /*_preferUnstakedTickets*/
      false
    );

    uint256 totalBalanceV1 = _ticketBoothV1.balanceOf(_beneficiary, _projectIdV1);
    uint256 unclaimedBalanceV1 = _ticketBoothV1.stakedBalanceOf(_beneficiary, _projectIdV1);

    // Set V1-V2 project

    // Migrate
  }
}
