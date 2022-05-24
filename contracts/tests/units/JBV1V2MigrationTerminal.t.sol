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
  IJBController mockController;
  ITicketBooth mockTicketBooth;
  IERC20 mockV1JBToken;

  address projectOwner;
  address caller;
  uint256 projectId = 420;
  uint256 projectIdV1 = 69;

  JBV1V2Terminal migrationTerminal;

  function setUp() public {
    mockOperatorStore = IJBOperatorStore(address(10));
    mockProjects = IJBProjects(address(20));
    mockDirectory = IJBDirectory(address(30));
    mockTicketBooth = ITicketBooth(address(40));
    mockV1JBToken = IERC20(address(50));
    mockController = IJBController(address(60));
    projectOwner = address(69);
    caller = address(420);

    vm.etch(address(mockOperatorStore), new bytes(0x69));
    vm.etch(address(mockProjects), new bytes(0x69));
    vm.etch(address(mockDirectory), new bytes(0x69));
    vm.etch(address(mockTicketBooth), new bytes(0x69));
    vm.etch(address(mockV1JBToken), new bytes(0x69));
    vm.etch(address(mockController), new bytes(0x69));

    vm.label(address(mockOperatorStore), 'mockOperatorStore');
    vm.label(address(mockProjects), 'mockProjects');
    vm.label(address(mockDirectory), 'mockDirectory');
    vm.label(address(mockTicketBooth), 'mockTicketBooth');
    vm.label(address(mockV1JBToken), 'mockV1JBToken');
    vm.label(address(mockController), 'mockController');
    vm.label(projectOwner, 'projectOwner');
    vm.label(caller, 'caller');

    migrationTerminal = new JBV1V2Terminal(
      mockOperatorStore,
      mockProjects,
      mockDirectory,
      mockTicketBooth
    );
  }

  // ----------- setV1ProjectId(..) ---------------

  function testSetV1ProjectId_PassIfCallerIsOwner(uint256 _projectId, uint256 _projectIdV1) public {
    vm.mockCall(
      address(mockProjects),
      abi.encodeWithSelector(IERC721.ownerOf.selector, _projectId),
      abi.encode(projectOwner)
    );

    vm.prank(projectOwner);
    migrationTerminal.setV1ProjectId(_projectId, _projectIdV1);

    assertEq(migrationTerminal.v1ProjectIdOf(_projectId), _projectIdV1);
  }

  function testSetV1ProjectId_RevertIfCallerIsNotOwner(
    uint256 _projectId,
    uint256 _projectIdV1,
    address _caller
  ) public {
    vm.assume(_caller != projectOwner);
    vm.mockCall(
      address(mockProjects),
      abi.encodeWithSelector(IERC721.ownerOf.selector, _projectId),
      abi.encode(projectOwner)
    );

    vm.prank(_caller);
    vm.expectRevert(abi.encodeWithSignature('NOT_ALLOWED()'));
    migrationTerminal.setV1ProjectId(_projectId, _projectIdV1);
  }

  // --------------- pay(..) ---------------------

  function testPay_passIfTokenHolder() public {
    uint256 _unclaimedBalance = 5 ether;
    uint256 _claimedBalance = 5 ether;
    uint256 _amount = _unclaimedBalance + _claimedBalance;

    // Set the V1-V2 Id's
    vm.mockCall(
      address(mockProjects),
      abi.encodeWithSelector(IERC721.ownerOf.selector, projectId),
      abi.encode(projectOwner)
    );

    vm.prank(projectOwner);
    migrationTerminal.setV1ProjectId(projectId, projectIdV1);

    // Mock the call to retrieve the correspoding V1 ERC20
    vm.mockCall(
      address(mockTicketBooth),
      abi.encodeWithSelector(ITicketBooth.ticketsOf.selector, projectIdV1),
      abi.encode(mockV1JBToken)
    );

    // Mock the call to get the V1 staked balance
    vm.mockCall(
      address(mockTicketBooth),
      abi.encodeWithSelector(ITicketBooth.stakedBalanceOf.selector, caller, projectIdV1),
      abi.encode(_unclaimedBalance)
    );

    // Mock the call to the V1 ERC20 balance
    vm.mockCall(
      address(mockV1JBToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, caller),
      abi.encode(_claimedBalance)
    );

    // Mock the transferFrom of V1 token, between caller and project owner
    vm.mockCall(
      address(mockV1JBToken),
      abi.encodeWithSelector(IERC20.transferFrom.selector, caller, projectOwner, _claimedBalance), // projectOwner is mocked supra
      abi.encode(true)
    );

    // Mock the transfer of the staked token
    vm.mockCall(
      address(mockTicketBooth),
      abi.encodeWithSelector(
        ITicketBooth.transfer.selector,
        caller,
        projectIdV1,
        _unclaimedBalance,
        projectOwner
      ), // projectOwner is mocked supra
      abi.encode(true)
    );

    // Mock the controller call to mint the V2 token
    vm.mockCall(
      address(mockDirectory),
      abi.encodeWithSelector(IJBDirectory.controllerOf.selector, projectId), // projectOwner is mocked supra
      abi.encode(mockController)
    );

    vm.mockCall(
      address(mockController),
      abi.encodeWithSelector(
        IJBController.mintTokensOf.selector,
        projectId,
        _amount,
        caller,
        '',
        /*preferClaimed*/
        false,
        false
      ),
      abi.encode(_amount)
    );

    vm.prank(caller);
    migrationTerminal.pay(
      projectId,
      _amount,
      /*token*/
      address(0),
      /*beneficiary*/
      caller,
      /*minReturnedToken*/
      1,
      /*preferClaimed*/
      false,
      /*memo*/
      '',
      /*metadata*/
      new bytes(0x69)
    );
  }

  function testPay_revertIfMsgValue(uint96 _value) public {
    vm.assume(_value > 0);

    vm.expectRevert(abi.encodeWithSignature('NO_MSG_VALUE_ALLOWED()'));
    migrationTerminal.pay{value: _value}(
      projectId,
      /*amount*/
      1,
      /*token*/
      address(0),
      /*beneficiary*/
      projectOwner,
      /*minReturnedToken*/
      1,
      /*preferClaimed*/
      false,
      /*memo*/
      '',
      /*metadata*/
      new bytes(0x69)
    );
  }

  function testPay_revertIfAmount0() public {
    vm.expectRevert(abi.encodeWithSignature('INVALID_AMOUNT()'));
    migrationTerminal.pay(
      projectId,
      /*amount*/
      0,
      /*token*/
      address(0),
      /*beneficiary*/
      projectOwner,
      /*minReturnedToken*/
      1,
      /*preferClaimed*/
      false,
      /*memo*/
      '',
      /*metadata*/
      new bytes(0x69)
    );
  }

  function testPay_revertIfProjectIdV1NotSet() public {
    uint256 _unclaimedBalance = 5 ether;
    uint256 _claimedBalance = 5 ether;
    uint256 _amount = _unclaimedBalance + _claimedBalance;

    vm.prank(caller);
    vm.expectRevert(abi.encodeWithSignature('V1_PROJECT_NOT_SET()'));
    migrationTerminal.pay(
      projectId,
      _amount,
      /*token*/
      address(0),
      /*beneficiary*/
      caller,
      /*minReturnedToken*/
      1,
      /*preferClaimed*/
      false,
      /*memo*/
      '',
      /*metadata*/
      new bytes(0x69)
    );
  }

  function testPay_revertIfV1tokenBalanceTooLow() public {
    uint256 _unclaimedBalance = 5 ether;
    uint256 _claimedBalance = 5 ether;
    uint256 _amount = _unclaimedBalance + _claimedBalance;

    // Set the V1-V2 Id's
    vm.mockCall(
      address(mockProjects),
      abi.encodeWithSelector(IERC721.ownerOf.selector, projectId),
      abi.encode(projectOwner)
    );

    vm.prank(projectOwner);
    migrationTerminal.setV1ProjectId(projectId, projectIdV1);

    // Mock the call to retrieve the correspoding V1 ERC20
    vm.mockCall(
      address(mockTicketBooth),
      abi.encodeWithSelector(ITicketBooth.ticketsOf.selector, projectIdV1),
      abi.encode(mockV1JBToken)
    );

    // Mock the call to get the V1 staked balance
    vm.mockCall(
      address(mockTicketBooth),
      abi.encodeWithSelector(ITicketBooth.stakedBalanceOf.selector, caller, projectIdV1),
      abi.encode(_unclaimedBalance)
    );

    // Mock the call to the V1 ERC20 balance
    vm.mockCall(
      address(mockV1JBToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, caller),
      abi.encode(_claimedBalance - 1)
    );

    vm.prank(caller);
    vm.expectRevert(abi.encodeWithSignature('INSUFFICIENT_FUNDS()'));
    migrationTerminal.pay(
      projectId,
      _amount,
      /*token*/
      address(0),
      /*beneficiary*/
      caller,
      /*minReturnedToken*/
      1,
      /*preferClaimed*/
      false,
      /*memo*/
      '',
      /*metadata*/
      new bytes(0x69)
    );
  }

  function testPay_revertIfV1BalanceV2MintedAmountDifference() public {
    uint256 _unclaimedBalance = 5 ether;
    uint256 _claimedBalance = 5 ether;
    uint256 _amount = _unclaimedBalance + _claimedBalance;

    // Set the V1-V2 Id's
    vm.mockCall(
      address(mockProjects),
      abi.encodeWithSelector(IERC721.ownerOf.selector, projectId),
      abi.encode(projectOwner)
    );

    vm.prank(projectOwner);
    migrationTerminal.setV1ProjectId(projectId, projectIdV1);

    // Mock the call to retrieve the correspoding V1 ERC20
    vm.mockCall(
      address(mockTicketBooth),
      abi.encodeWithSelector(ITicketBooth.ticketsOf.selector, projectIdV1),
      abi.encode(mockV1JBToken)
    );

    // Mock the call to get the V1 staked balance
    vm.mockCall(
      address(mockTicketBooth),
      abi.encodeWithSelector(ITicketBooth.stakedBalanceOf.selector, caller, projectIdV1),
      abi.encode(_unclaimedBalance)
    );

    // Mock the call to the V1 ERC20 balance
    vm.mockCall(
      address(mockV1JBToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, caller),
      abi.encode(_claimedBalance)
    );

    // Mock the transferFrom of V1 token, between caller and project owner
    vm.mockCall(
      address(mockV1JBToken),
      abi.encodeWithSelector(IERC20.transferFrom.selector, caller, projectOwner, _claimedBalance), // projectOwner is mocked supra
      abi.encode(true)
    );

    // Mock the transfer of the staked token
    vm.mockCall(
      address(mockTicketBooth),
      abi.encodeWithSelector(
        ITicketBooth.transfer.selector,
        caller,
        projectIdV1,
        _unclaimedBalance,
        projectOwner
      ), // projectOwner is mocked supra
      abi.encode(true)
    );

    // Mock the controller call to mint the V2 token
    vm.mockCall(
      address(mockDirectory),
      abi.encodeWithSelector(IJBDirectory.controllerOf.selector, projectId), // projectOwner is mocked supra
      abi.encode(mockController)
    );

    vm.mockCall(
      address(mockController),
      abi.encodeWithSelector(
        IJBController.mintTokensOf.selector,
        projectId,
        _amount,
        caller,
        '',
        /*preferClaimed*/
        false,
        false
      ),
      abi.encode(_amount - 1)
    );

    vm.prank(caller);
    vm.expectRevert(abi.encodeWithSignature('UNEXPECTED_AMOUNT()'));
    migrationTerminal.pay(
      projectId,
      _amount,
      /*token*/
      address(0),
      /*beneficiary*/
      caller,
      /*minReturnedToken*/
      1,
      /*preferClaimed*/
      false,
      /*memo*/
      '',
      /*metadata*/
      new bytes(0x69)
    );
  }

  // ----------- addToBalance(..) -----------------

  function testAddToBalance_Reverts(
    uint256 _projectId,
    uint256 _amount,
    address _token
  ) public {
    vm.expectRevert(abi.encodeWithSignature('NOT_SUPPORTED()'));
    migrationTerminal.addToBalanceOf(_projectId, _amount, _token, '', '0x');
  }
}
