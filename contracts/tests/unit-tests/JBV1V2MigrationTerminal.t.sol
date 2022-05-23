// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBPaymentTerminal.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBRedemptionTerminal.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBController/1.sol';
import '@jbx-protocol/contracts-v2/contracts/abstract/JBOperatable.sol';
import '@jbx-protocol/contracts-v2/contracts/libraries/JBOperations.sol';

import '../../interfaces/IJBV1V2MigrationTerminal.sol';
import '../../JBV1V2MigrationTerminal.sol';

import 'forge-std/Test.sol';

contract TestJBV1V2Terminal is Test {
  IJBOperatorStore mockOperatorStore;
  IJBProjects mockProjects;
  IJBDirectory mockDirectory;
  ITicketBooth mockTicketBooth;

  JBV1V2Terminal migrationTerminal;

  address projectOwner;

  function setUp() public {
    mockOperatorStore = IJBOperatorStore(address(10));
    mockProjects = IJBProjects(address(20));
    mockDirectory = IJBDirectory(address(30));
    mockTicketBooth = ITicketBooth(address(40));
    projectOwner = address(69);

    vm.etch(address(mockOperatorStore), new bytes(0x69));
    vm.etch(address(mockProjects), new bytes(0x69));
    vm.etch(address(mockDirectory), new bytes(0x69));
    vm.etch(address(mockTicketBooth), new bytes(0x69));

    vm.label(address(mockOperatorStore), 'mockOperatorStore');
    vm.label(address(mockProjects), 'mockProjects');
    vm.label(address(mockDirectory), 'mockDirectory');
    vm.label(address(mockTicketBooth), 'mockTicketBooth');
    vm.label(projectOwner, 'projectOwner');

    migrationTerminal = new JBV1V2Terminal(
      mockOperatorStore,
      mockProjects,
      mockDirectory,
      mockTicketBooth
    );
  }

  function testSetV1ProjectIdPassIfCallerIsOwner(uint256 projectId, uint256 projectIdV1) public {
    vm.mockCall(
      address(mockProjects),
      abi.encodeWithSelector(IERC721.ownerOf.selector, projectId),
      abi.encode(projectOwner)
    );

    vm.prank(projectOwner);
    migrationTerminal.setV1ProjectId(projectId, projectIdV1);

    assertEq(migrationTerminal.v1ProjectIdOf(projectId), projectIdV1);
  }

  function testSetV1ProjectIdRevertIfCallerIsNotOwner(
    uint256 projectId,
    uint256 projectIdV1,
    address caller
  ) public {
    vm.assume(caller != projectOwner);
    vm.mockCall(
      address(mockProjects),
      abi.encodeWithSelector(IERC721.ownerOf.selector, projectId),
      abi.encode(projectOwner)
    );

    vm.prank(caller);
    vm.expectRevert(abi.encodeWithSignature('NOT_ALLOWED()'));
    migrationTerminal.setV1ProjectId(projectId, projectIdV1);
  }

  // function pay(
  //   uint256 _projectId,
  //   uint256 _amount,
  //   address _token,
  //   address _beneficiary,
  //   uint256 _minReturnedTokens,
  //   bool _preferClaimedTokens,
  //   string calldata _memo,
  //   bytes calldata _metadata
  // ) external payable override returns (uint256 beneficiaryTokenCount)

  function testAddToBalanceReverts(
    uint256 _projectId,
    uint256 _amount,
    address _token
  ) public {
    vm.expectRevert(abi.encodeWithSignature('NOT_SUPPORTED()'));
    migrationTerminal.addToBalanceOf(_projectId, _amount, _token, '', '0x');
  }
}
