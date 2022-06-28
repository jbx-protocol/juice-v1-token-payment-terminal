// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '../../interfaces/IJBV1TokenPaymentTerminal.sol';
import '../../JBV1TokenPaymentTerminal.sol';

import './helpers/TestBaseWorkflow.sol';

contract TestE2EJBV1TokenPaymentTerminal is TestBaseWorkflow {
  JBV1TokenPaymentTerminal migrationTerminal;

  function setUp() public override {
    super.setUp();

    // Create new migration terminal
    migrationTerminal = new JBV1TokenPaymentTerminal(_jbProjects, _jbDirectory, _ticketBoothV1);

    // Add it as a project terminal
    _terminals.push(migrationTerminal);

    _projectId = _jbController.launchProjectFor(
      _projectOwner,
      _projectMetadata,
      _data,
      _metadata,
      block.timestamp,
      _groupedSplits,
      _fundAccessConstraints,
      _terminals,
      ''
    );

    // Deploy an ERC20 for this project, to test both issued and unissued token migration
    vm.prank(_projectOwner);
    _tokenV2 = _jbController.issueTokenFor(_projectId, 'TokenV2', 'LfG');
  }

  /**
   @dev this test tests the flow to exchange all unclaimed V1 token for unclaimed V2 token
  */
  function testMigration_PassWithUnclaimedToUnclaimedToken() public {
    vm.prank(_beneficiary);
    _terminalV1_1.pay{value: 1 ether}(
      _projectIdV1,
      _beneficiary,
      'lfg',
      /*_preferUnstakedTickets*/
      false
    );

    // Balance before the token migration
    uint256 totalBalanceV1 = _ticketBoothV1.balanceOf(_beneficiary, _projectIdV1);
    uint256 unclaimedBalanceV1 = _ticketBoothV1.stakedBalanceOf(_beneficiary, _projectIdV1);
    assertEq(_jbTokenStore.balanceOf(_beneficiary, _projectId), 0);
    assertEq(_jbTokenStore.unclaimedBalanceOf(_beneficiary, _projectId), 0);

    // Sanity check: we're not testing a 0 token migration
    assertGt(totalBalanceV1, 0);
    assertGt(unclaimedBalanceV1, 0);

    // Set V1-V2 project equivalence
    vm.prank(_projectOwner);
    migrationTerminal.setV1ProjectIdOf(_projectId, _projectIdV1);

    // Authorize the migration terminal to transfer the unclaimed V1 token
    uint256[] memory _index = new uint256[](1);
    _index[0] = Operations.Transfer;

    vm.prank(_beneficiary);
    _operatorStoreV1.setOperator(address(migrationTerminal), _projectIdV1, _index);

    // Authorize the migration terminal to mint the V2 token
    _index[0] = JBOperations.MINT;

    vm.prank(_projectOwner);
    _jbOperatorStore.setOperator(
      JBOperatorData({
        operator: address(migrationTerminal),
        domain: _projectId,
        permissionIndexes: _index
      })
    );

    // Migrate
    vm.prank(_beneficiary);
    migrationTerminal.pay(
      _projectId,
      totalBalanceV1,
      address(0), //token
      _beneficiary,
      0, //_minReturnedTokens
      false, //_preferClaimedTokens
      'brah',
      new bytes(0)
    );

    // Check the new balances:
    // V2 token
    assertEq(_jbTokenStore.balanceOf(_beneficiary, _projectId), totalBalanceV1);
    assertEq(_jbTokenStore.unclaimedBalanceOf(_beneficiary, _projectId), unclaimedBalanceV1);
    assertEq(_tokenV2.balanceOf(_beneficiary, _projectId), 0);

    // V1 beneficiary token are now gone
    assertEq(_ticketBoothV1.balanceOf(_beneficiary, _projectIdV1), 0);
    assertEq(_ticketBoothV1.stakedBalanceOf(_beneficiary, _projectIdV1), 0);
    assertEq(_ticketsV1.balanceOf(_beneficiary), 0);

    // V1 token are now in the migration terminal
    assertEq(_ticketBoothV1.balanceOf(address(migrationTerminal), _projectIdV1), totalBalanceV1);
    assertEq(
      _ticketBoothV1.stakedBalanceOf(address(migrationTerminal), _projectIdV1),
      unclaimedBalanceV1
    );
    assertEq(_ticketsV1.balanceOf(address(migrationTerminal)), 0);

    vm.prank(_projectOwner);
    migrationTerminal.releaseV1TokensOf(_projectIdV1, _projectOwner);

    // V1 token are now with the project owner...
    assertEq(_ticketBoothV1.balanceOf(_projectOwner, _projectIdV1), totalBalanceV1);
    assertEq(_ticketBoothV1.stakedBalanceOf(_projectOwner, _projectIdV1), unclaimedBalanceV1);
    assertEq(_ticketsV1.balanceOf(_projectOwner), 0);

    // ... And not in the terminal anymore
    assertEq(_ticketBoothV1.balanceOf(address(migrationTerminal), _projectIdV1), 0);
    assertEq(_ticketBoothV1.stakedBalanceOf(address(migrationTerminal), _projectIdV1), 0);
    assertEq(_ticketsV1.balanceOf(address(migrationTerminal)), 0);

    // No further migration is possible
    vm.expectRevert(abi.encodeWithSignature('MIGRATION_TERMINATED()'));
    vm.prank(_projectOwner);
    migrationTerminal.releaseV1TokensOf(_projectIdV1, _projectOwner);
  }

  /**
   @dev this test tests the flow to exchange all claimed V1 token for claimed V2 token
  */
  function testMigration_PassWithClaimedToClaimedToken() public {
    vm.prank(_beneficiary);
    _terminalV1_1.pay{value: 1 ether}(
      _projectIdV1,
      _beneficiary,
      'lfg',
      /*_preferUnstakedTickets*/
      true
    );

    // Balance before the token migration
    uint256 totalBalanceV1 = _ticketBoothV1.balanceOf(_beneficiary, _projectIdV1);
    uint256 unclaimedBalanceV1 = _ticketBoothV1.stakedBalanceOf(_beneficiary, _projectIdV1);
    uint256 claimedBalanceV1 = _ticketsV1.balanceOf(_beneficiary);

    assertEq(_jbTokenStore.balanceOf(_beneficiary, _projectId), 0);
    assertEq(_jbTokenStore.unclaimedBalanceOf(_beneficiary, _projectId), 0);

    // Sanity check: we're not testing a 0 token migration and non are unclaimed
    assertGt(totalBalanceV1, 0);
    assertEq(unclaimedBalanceV1, 0);

    // Set V1-V2 project
    vm.prank(_projectOwner);
    migrationTerminal.setV1ProjectIdOf(_projectId, _projectIdV1);

    // Approve the V1 claimed token transfer
    vm.prank(_beneficiary);
    _ticketsV1.approve(address(migrationTerminal), claimedBalanceV1);

    // Authorize the migration terminal to mint the V2 token
    uint256[] memory _index = new uint256[](1);
    _index[0] = JBOperations.MINT;

    vm.prank(_projectOwner);
    _jbOperatorStore.setOperator(
      JBOperatorData({
        operator: address(migrationTerminal),
        domain: _projectId,
        permissionIndexes: _index
      })
    );

    // Migrate
    vm.prank(_beneficiary);
    migrationTerminal.pay(
      _projectId,
      totalBalanceV1,
      address(0), //token
      _beneficiary,
      0, //_minReturnedTokens
      true, //_preferClaimedTokens
      'brah',
      new bytes(0)
    );

    // Check the new balances (unclaimedV1 is 0, tested supra)
    // V2 token
    assertEq(_jbTokenStore.balanceOf(_beneficiary, _projectId), totalBalanceV1);
    assertEq(_jbTokenStore.unclaimedBalanceOf(_beneficiary, _projectId), unclaimedBalanceV1);
    assertEq(_tokenV2.balanceOf(_beneficiary, _projectId), claimedBalanceV1);

    // V1 beneficiary token
    assertEq(_ticketBoothV1.balanceOf(_beneficiary, _projectIdV1), 0);
    assertEq(_ticketBoothV1.stakedBalanceOf(_beneficiary, _projectIdV1), 0);
    assertEq(_ticketsV1.balanceOf(_beneficiary), 0);

    // V1 token are now in the terminal
    assertEq(_ticketBoothV1.balanceOf(address(migrationTerminal), _projectIdV1), totalBalanceV1);
    assertEq(
      _ticketBoothV1.stakedBalanceOf(address(migrationTerminal), _projectIdV1),
      unclaimedBalanceV1
    );
    assertEq(_ticketsV1.balanceOf(address(migrationTerminal)), claimedBalanceV1);

    vm.prank(_projectOwner);
    migrationTerminal.releaseV1TokensOf(_projectIdV1, _projectOwner);

    // V1 token are now with the project owner...
    assertEq(_ticketBoothV1.balanceOf(_projectOwner, _projectIdV1), totalBalanceV1);
    assertEq(_ticketBoothV1.stakedBalanceOf(_projectOwner, _projectIdV1), unclaimedBalanceV1);
    assertEq(_ticketsV1.balanceOf(_projectOwner), claimedBalanceV1);

    // ... And not in the terminal anymore
    assertEq(_ticketBoothV1.balanceOf(address(migrationTerminal), _projectIdV1), 0);
    assertEq(_ticketBoothV1.stakedBalanceOf(address(migrationTerminal), _projectIdV1), 0);
    assertEq(_ticketsV1.balanceOf(address(migrationTerminal)), 0);

    // No further migration is possible
    vm.expectRevert(abi.encodeWithSignature('MIGRATION_TERMINATED()'));
    vm.prank(_projectOwner);
    migrationTerminal.releaseV1TokensOf(_projectIdV1, _projectOwner);
  }

  /**
   @dev this test tests the flow to exchange a mix of claimed and unclaimed V1 token for
        an equivalent mix of V2 token
  */
  function testMigration_PassWithBothClaimedAndUnclaimedToken() public {
    vm.prank(_beneficiary);
    _terminalV1_1.pay{value: 1 ether}(
      _projectIdV1,
      _beneficiary,
      'lfg',
      /*_preferUnstakedTickets*/
      true
    );

    _terminalV1_1.pay{value: 2 ether}(
      _projectIdV1,
      _beneficiary,
      'lfg',
      /*_preferUnstakedTickets*/
      false
    );

    // Balance before the token migration
    uint256 totalBalanceV1 = _ticketBoothV1.balanceOf(_beneficiary, _projectIdV1);
    uint256 unclaimedBalanceV1 = _ticketBoothV1.stakedBalanceOf(_beneficiary, _projectIdV1);
    uint256 claimedBalanceV1 = _ticketsV1.balanceOf(_beneficiary);
    assertEq(_jbTokenStore.balanceOf(_beneficiary, _projectId), 0);
    assertEq(_jbTokenStore.unclaimedBalanceOf(_beneficiary, _projectId), 0);

    // Sanity check: we're not testing a 0 token migration
    assertGt(totalBalanceV1, 0);
    assertGt(unclaimedBalanceV1, 0);
    assertGt(claimedBalanceV1, 0);

    // Set V1-V2 project
    vm.prank(_projectOwner);
    migrationTerminal.setV1ProjectIdOf(_projectId, _projectIdV1);

    // Approve the V1 claimed token transfer
    vm.prank(_beneficiary);
    _ticketsV1.approve(address(migrationTerminal), claimedBalanceV1);

    // Authorize the migration terminal to transfer the unclaimed V1 token
    uint256[] memory _index = new uint256[](1);
    _index[0] = Operations.Transfer;

    vm.prank(_beneficiary);
    _operatorStoreV1.setOperator(address(migrationTerminal), _projectIdV1, _index);

    // Authorize the migration terminal to mint the V2 token
    _index[0] = JBOperations.MINT;

    vm.prank(_projectOwner);
    _jbOperatorStore.setOperator(
      JBOperatorData({
        operator: address(migrationTerminal),
        domain: _projectId,
        permissionIndexes: _index
      })
    );

    // Migrate
    vm.prank(_beneficiary);
    migrationTerminal.pay(
      _projectId,
      unclaimedBalanceV1,
      address(0), //token
      _beneficiary,
      0, //_minReturnedTokens
      false, //_preferClaimedTokens
      'brah',
      new bytes(0)
    );

    // Migrate
    vm.prank(_beneficiary);
    migrationTerminal.pay(
      _projectId,
      claimedBalanceV1,
      address(0), //token
      _beneficiary,
      0, //_minReturnedTokens
      true, //_preferClaimedTokens
      'brah',
      new bytes(0)
    );

    // Check the new balances:
    // V2 token
    assertEq(_jbTokenStore.balanceOf(_beneficiary, _projectId), totalBalanceV1);
    assertEq(_jbTokenStore.unclaimedBalanceOf(_beneficiary, _projectId), unclaimedBalanceV1);
    assertEq(_tokenV2.balanceOf(_beneficiary, _projectId), claimedBalanceV1);

    // V1 beneficiary token
    assertEq(_ticketBoothV1.balanceOf(_beneficiary, _projectIdV1), 0);
    assertEq(_ticketBoothV1.stakedBalanceOf(_beneficiary, _projectIdV1), 0);
    assertEq(_ticketsV1.balanceOf(_beneficiary), 0);

    // V1 token are now in the migration terminal
    assertEq(_ticketBoothV1.balanceOf(address(migrationTerminal), _projectIdV1), totalBalanceV1);
    assertEq(
      _ticketBoothV1.stakedBalanceOf(address(migrationTerminal), _projectIdV1),
      unclaimedBalanceV1
    );
    assertEq(_ticketsV1.balanceOf(address(migrationTerminal)), claimedBalanceV1);

    // Release with the project owner as beneficiary of v1 token
    vm.prank(_projectOwner);
    migrationTerminal.releaseV1TokensOf(_projectIdV1, _projectOwner);

    // V1 token are now with the project owner...
    assertEq(_ticketBoothV1.balanceOf(_projectOwner, _projectIdV1), totalBalanceV1);
    assertEq(_ticketBoothV1.stakedBalanceOf(_projectOwner, _projectIdV1), unclaimedBalanceV1);
    assertEq(_ticketsV1.balanceOf(_projectOwner), claimedBalanceV1);

    // ... And not in the terminal anymore
    assertEq(_ticketBoothV1.balanceOf(address(migrationTerminal), _projectIdV1), 0);
    assertEq(_ticketBoothV1.stakedBalanceOf(address(migrationTerminal), _projectIdV1), 0);
    assertEq(_ticketsV1.balanceOf(address(migrationTerminal)), 0);

    // No further migration is possible
    vm.expectRevert(abi.encodeWithSignature('MIGRATION_TERMINATED()'));
    vm.prank(_projectOwner);
    migrationTerminal.releaseV1TokensOf(_projectIdV1, _projectOwner);
  }

  /**
   @dev this test tests the flow to exchange a mix of claimed and unclaimed V1 token for
        unclaimed V2 token
  */
  function testMigration_PassWithBothClaimedAndUnclaimedToUnclaimedToken(
    uint96 claimed,
    uint96 unclaimed
  ) public {
    // Overflow check
    unchecked {
      vm.assume(claimed + unclaimed > claimed && claimed + unclaimed > unclaimed);
    }

    uint256 totalAmountIn = claimed + unclaimed;
    vm.deal(_beneficiary, totalAmountIn);

    vm.prank(_beneficiary);
    _terminalV1_1.pay{value: claimed}(
      _projectIdV1,
      _beneficiary,
      'lfg',
      /*_preferUnstakedTickets*/
      true
    );

    _terminalV1_1.pay{value: unclaimed}(
      _projectIdV1,
      _beneficiary,
      'lfg',
      /*_preferUnstakedTickets*/
      false
    );

    // Balance before the token migration
    uint256 totalBalanceV1 = _ticketBoothV1.balanceOf(_beneficiary, _projectIdV1);
    uint256 unclaimedBalanceV1 = _ticketBoothV1.stakedBalanceOf(_beneficiary, _projectIdV1);
    uint256 claimedBalanceV1 = _ticketsV1.balanceOf(_beneficiary);
    assertEq(_jbTokenStore.balanceOf(_beneficiary, _projectId), 0);
    assertEq(_jbTokenStore.unclaimedBalanceOf(_beneficiary, _projectId), 0);

    // Set V1-V2 project
    vm.prank(_projectOwner);
    migrationTerminal.setV1ProjectIdOf(_projectId, _projectIdV1);

    // Approve the V1 claimed token transfer
    vm.prank(_beneficiary);
    _ticketsV1.approve(address(migrationTerminal), claimedBalanceV1);

    // Authorize the migration terminal to transfer the unclaimed V1 token
    uint256[] memory _index = new uint256[](1);
    _index[0] = Operations.Transfer;

    vm.prank(_beneficiary);
    _operatorStoreV1.setOperator(address(migrationTerminal), _projectIdV1, _index);

    // Authorize the migration terminal to mint the V2 token
    _index[0] = JBOperations.MINT;

    vm.prank(_projectOwner);
    _jbOperatorStore.setOperator(
      JBOperatorData({
        operator: address(migrationTerminal),
        domain: _projectId,
        permissionIndexes: _index
      })
    );

    // Migrate
    vm.prank(_beneficiary);
    migrationTerminal.pay(
      _projectId,
      unclaimedBalanceV1,
      address(0), //token
      _beneficiary,
      0, //_minReturnedTokens
      false, //_preferClaimedTokens
      'brah',
      new bytes(0)
    );

    vm.prank(_beneficiary);
    migrationTerminal.pay(
      _projectId,
      claimedBalanceV1,
      address(0), //token
      _beneficiary,
      0, //_minReturnedTokens
      true, //_preferClaimedTokens
      'brah',
      new bytes(0)
    );

    // Check the new balances:
    // V2 token
    assertEq(_jbTokenStore.balanceOf(_beneficiary, _projectId), totalBalanceV1);
    assertEq(_jbTokenStore.unclaimedBalanceOf(_beneficiary, _projectId), unclaimedBalanceV1);
    assertEq(_tokenV2.balanceOf(_beneficiary, _projectId), claimedBalanceV1);

    // V1 beneficiary token
    assertEq(_ticketBoothV1.balanceOf(_beneficiary, _projectIdV1), 0);
    assertEq(_ticketBoothV1.stakedBalanceOf(_beneficiary, _projectIdV1), 0);
    assertEq(_ticketsV1.balanceOf(_beneficiary), 0);

    // V1 token are now in the migration terminal
    assertEq(_ticketBoothV1.balanceOf(address(migrationTerminal), _projectIdV1), totalBalanceV1);
    assertEq(
      _ticketBoothV1.stakedBalanceOf(address(migrationTerminal), _projectIdV1),
      unclaimedBalanceV1
    );
    assertEq(_ticketsV1.balanceOf(address(migrationTerminal)), claimedBalanceV1);

    // Release with the project owner as beneficiary of v1 token
    vm.prank(_projectOwner);
    migrationTerminal.releaseV1TokensOf(_projectIdV1, _projectOwner);

    // V1 token are now with the project owner...
    assertEq(_ticketBoothV1.balanceOf(_projectOwner, _projectIdV1), totalBalanceV1);
    assertEq(_ticketBoothV1.stakedBalanceOf(_projectOwner, _projectIdV1), unclaimedBalanceV1);
    assertEq(_ticketsV1.balanceOf(_projectOwner), claimedBalanceV1);

    // ... And not in the terminal anymore
    assertEq(_ticketBoothV1.balanceOf(address(migrationTerminal), _projectIdV1), 0);
    assertEq(_ticketBoothV1.stakedBalanceOf(address(migrationTerminal), _projectIdV1), 0);
    assertEq(_ticketsV1.balanceOf(address(migrationTerminal)), 0);

    // No further migration is possible
    vm.expectRevert(abi.encodeWithSignature('MIGRATION_TERMINATED()'));
    vm.prank(_projectOwner);
    migrationTerminal.releaseV1TokensOf(_projectIdV1, _projectOwner);
  }

  /**
   @dev this test tests the flow to exchange a partial balance of unclaimed V1 token for unclaimed V2 token
  */
  function testMigration_PassWithPartialUnclaimedToUnclaimedToken() public {
    vm.prank(_beneficiary);
    _terminalV1_1.pay{value: 1 ether}(
      _projectIdV1,
      _beneficiary,
      'lfg',
      /*_preferUnstakedTickets*/
      false
    );

    // Balance before the token migration
    uint256 totalBalanceV1 = _ticketBoothV1.balanceOf(_beneficiary, _projectIdV1);
    uint256 unclaimedBalanceV1 = _ticketBoothV1.stakedBalanceOf(_beneficiary, _projectIdV1);
    assertEq(_jbTokenStore.balanceOf(_beneficiary, _projectId), 0);
    assertEq(_jbTokenStore.unclaimedBalanceOf(_beneficiary, _projectId), 0);

    // Sanity check: we're not testing a 0 token migration
    assertGt(totalBalanceV1, 0);
    assertGt(unclaimedBalanceV1, 0);

    // Set V1-V2 project equivalence
    vm.prank(_projectOwner);
    migrationTerminal.setV1ProjectIdOf(_projectId, _projectIdV1);

    // Authorize the migration terminal to transfer the unclaimed V1 token
    uint256[] memory _index = new uint256[](1);
    _index[0] = Operations.Transfer;

    vm.prank(_beneficiary);
    _operatorStoreV1.setOperator(address(migrationTerminal), _projectIdV1, _index);

    // Authorize the migration terminal to mint the V2 token
    _index[0] = JBOperations.MINT;

    vm.prank(_projectOwner);
    _jbOperatorStore.setOperator(
      JBOperatorData({
        operator: address(migrationTerminal),
        domain: _projectId,
        permissionIndexes: _index
      })
    );

    // Migrate
    vm.prank(_beneficiary);
    migrationTerminal.pay(
      _projectId,
      totalBalanceV1 / 2,
      address(0), //token
      _beneficiary,
      0, //_minReturnedTokens
      false, //_preferClaimedTokens
      'brah',
      new bytes(0)
    );

    // Check the new balances:
    // V2 token
    assertEq(_jbTokenStore.balanceOf(_beneficiary, _projectId), totalBalanceV1 / 2);
    assertEq(_jbTokenStore.unclaimedBalanceOf(_beneficiary, _projectId), unclaimedBalanceV1 / 2);
    assertEq(_tokenV2.balanceOf(_beneficiary, _projectId), 0);

    // V1 beneficiary token
    assertEq(_ticketBoothV1.balanceOf(_beneficiary, _projectIdV1), totalBalanceV1 / 2);
    assertEq(_ticketBoothV1.stakedBalanceOf(_beneficiary, _projectIdV1), unclaimedBalanceV1 / 2);
    assertEq(_ticketsV1.balanceOf(_beneficiary), 0);

    // V1 project token in migration terminal
    assertEq(
      _ticketBoothV1.balanceOf(address(migrationTerminal), _projectIdV1),
      totalBalanceV1 / 2
    );
    assertEq(
      _ticketBoothV1.stakedBalanceOf(address(migrationTerminal), _projectIdV1),
      unclaimedBalanceV1 / 2
    );
    assertEq(_ticketsV1.balanceOf(address(migrationTerminal)), 0);

    // Release with the project owner as beneficiary of v1 token
    vm.prank(_projectOwner);
    migrationTerminal.releaseV1TokensOf(_projectIdV1, _projectOwner);

    // V1 token are now with the project owner...
    assertEq(_ticketBoothV1.balanceOf(_projectOwner, _projectIdV1), totalBalanceV1 / 2);
    assertEq(_ticketBoothV1.stakedBalanceOf(_projectOwner, _projectIdV1), unclaimedBalanceV1 / 2);
    assertEq(_ticketsV1.balanceOf(_projectOwner), 0);

    // ... And not in the terminal anymore
    assertEq(_ticketBoothV1.balanceOf(address(migrationTerminal), _projectIdV1), 0);
    assertEq(_ticketBoothV1.stakedBalanceOf(address(migrationTerminal), _projectIdV1), 0);
    assertEq(_ticketsV1.balanceOf(address(migrationTerminal)), 0);

    // No further migration is possible
    vm.expectRevert(abi.encodeWithSignature('MIGRATION_TERMINATED()'));
    vm.prank(_projectOwner);
    migrationTerminal.releaseV1TokensOf(_projectIdV1, _projectOwner);
  }

  /**
   @dev this test tests the reverting flow when trying to exchange a V2 amount bigger than the V1 balance held 
  */
  function testMigration_FailsIfBalanceTooLow() public {
    vm.prank(_beneficiary);
    _terminalV1_1.pay{value: 1 ether}(
      _projectIdV1,
      _beneficiary,
      'lfg',
      /*_preferUnstakedTickets*/
      false
    );

    // Balance before the token migration
    uint256 totalBalanceV1 = _ticketBoothV1.balanceOf(_beneficiary, _projectIdV1);
    uint256 unclaimedBalanceV1 = _ticketBoothV1.stakedBalanceOf(_beneficiary, _projectIdV1);

    // Sanity check: we're not testing a 0 token migration
    assertGt(totalBalanceV1, 0);
    assertGt(unclaimedBalanceV1, 0);

    // Set V1-V2 project equivalence
    vm.prank(_projectOwner);
    migrationTerminal.setV1ProjectIdOf(_projectId, _projectIdV1);

    // Authorize the migration terminal to transfer the unclaimed V1 token
    uint256[] memory _index = new uint256[](1);
    _index[0] = Operations.Transfer;

    vm.prank(_beneficiary);
    _operatorStoreV1.setOperator(address(migrationTerminal), _projectIdV1, _index);

    // Authorize the migration terminal to mint the V2 token
    _index[0] = JBOperations.MINT;

    vm.prank(_projectOwner);
    _jbOperatorStore.setOperator(
      JBOperatorData({
        operator: address(migrationTerminal),
        domain: _projectId,
        permissionIndexes: _index
      })
    );

    // Migrate (try to)
    vm.expectRevert(abi.encodeWithSignature('INSUFFICIENT_FUNDS()'));
    vm.prank(_beneficiary);
    migrationTerminal.pay(
      _projectId,
      totalBalanceV1 + 1,
      address(0), //token
      _beneficiary,
      0, //_minReturnedTokens
      false, //_preferClaimedTokens
      'brah',
      new bytes(0)
    );
  }
}
