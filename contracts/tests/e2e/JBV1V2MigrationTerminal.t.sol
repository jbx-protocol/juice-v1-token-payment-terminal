// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBPaymentTerminal.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBRedemptionTerminal.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBController/1.sol';
import '@jbx-protocol/contracts-v2/contracts/abstract/JBOperatable.sol';
import '@jbx-protocol/contracts-v2/contracts/libraries/JBOperations.sol';
import '../../interfaces/IJBV1V2MigrationTerminal.sol';
import '../../JBV1V2MigrationTerminal.sol';

import './helpers/TestBaseWorkflow.sol';

contract TestE2EJBV1V2Terminal is TestBaseWorkflow {
  function setUp() public override {
    super.setUp();
  }

  function testMigration_PassIfCallerIsOwner() public {}
}
