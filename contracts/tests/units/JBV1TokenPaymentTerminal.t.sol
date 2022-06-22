// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBPaymentTerminal.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBRedemptionTerminal.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBController.sol';
import '@jbx-protocol/contracts-v2/contracts/abstract/JBOperatable.sol';
import '@jbx-protocol/contracts-v2/contracts/libraries/JBOperations.sol';
import '../../interfaces/IJBV1TokenPaymentTerminal.sol';
import '../../JBV1TokenPaymentTerminal.sol';
import 'forge-std/Test.sol';

contract TestUnitJBV1TokenPaymentTerminal is Test {
  event SetV1ProjectId(uint256 indexed _projectId, uint256 indexed _v1ProjectId, address caller);

  event Pay(
    uint256 indexed projectId,
    address payer,
    address beneficiary,
    uint256 amount,
    uint256 beneficiaryTokenCount,
    string memo,
    address caller
  );

  event ReleaseV1TokensOf(
    uint256 indexed projectId,
    address indexed beneficiary,
    uint256 unclaimedBalance,
    uint256 claimedBalance,
    address caller
  );

  IJBOperatorStore mockOperatorStore;
  IJBProjects mockProjects;
  IJBDirectory mockDirectory;
  IJBController mockController;
  ITicketBooth mockTicketBooth;
  IProjects mockProjectsV1;
  IERC20 mockV1JBToken;

  address projectOwner;
  address caller;
  address beneficiary;
  uint256 projectId = 420;
  uint256 projectIdV1 = 69;

  JBV1TokenPaymentTerminal migrationTerminal;

  function setUp() public {
    mockProjects = IJBProjects(address(20));
    mockDirectory = IJBDirectory(address(30));
    mockTicketBooth = ITicketBooth(address(40));
    mockV1JBToken = IERC20(address(50));
    mockController = IJBController(address(60));
    mockProjectsV1 = IProjects(address(70));
    projectOwner = address(69);
    caller = address(420);
    beneficiary = address(6942069);

    vm.etch(address(mockProjects), new bytes(0x69));
    vm.etch(address(mockProjectsV1), new bytes(0x69));
    vm.etch(address(mockDirectory), new bytes(0x69));
    vm.etch(address(mockTicketBooth), new bytes(0x69));
    vm.etch(address(mockV1JBToken), new bytes(0x69));
    vm.etch(address(mockController), new bytes(0x69));

    vm.label(address(mockProjects), 'mockProjects');
    vm.label(address(mockProjectsV1), 'mockProjectsV1');
    vm.label(address(mockDirectory), 'mockDirectory');
    vm.label(address(mockTicketBooth), 'mockTicketBooth');
    vm.label(address(mockV1JBToken), 'mockV1JBToken');
    vm.label(address(mockController), 'mockController');
    vm.label(projectOwner, 'projectOwner');
    vm.label(caller, 'caller');
    vm.label(beneficiary, 'beneficiary');

    migrationTerminal = new JBV1TokenPaymentTerminal(
      mockProjects,
      mockDirectory,
      mockTicketBooth
    );

    vm.mockCall(
      address(mockTicketBooth),
      abi.encodeWithSelector(ITicketBooth.projects.selector),
      abi.encode(mockProjectsV1)
    );
  }

  // ----------- setV1ProjectId(..) ---------------

  function testSetV1ProjectId_PassIfCallerIsOwner(uint256 _projectId, uint256 _projectIdV1) public {
    vm.mockCall(
      address(mockProjects),
      abi.encodeWithSelector(IERC721.ownerOf.selector, _projectId),
      abi.encode(projectOwner)
    );

    vm.mockCall(
      address(mockProjectsV1),
      abi.encodeWithSelector(IERC721.ownerOf.selector, _projectIdV1),
      abi.encode(projectOwner)
    );

    vm.expectEmit(true, true, false, true);
    emit SetV1ProjectId(_projectId, _projectIdV1, projectOwner);

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

    vm.mockCall(
      address(mockProjectsV1),
      abi.encodeWithSelector(IERC721.ownerOf.selector, _projectIdV1),
      abi.encode(projectOwner)
    );

    vm.prank(_caller);
    vm.expectRevert(abi.encodeWithSignature('NOT_ALLOWED()'));
    migrationTerminal.setV1ProjectId(_projectId, _projectIdV1);
  }

  function testSetV1ProjectId_RevertIfDifferentV1V2Owners(
    uint256 _projectId,
    uint256 _projectIdV1,
    address _projectOwnerV2,
    address _projectOwnerV1
  ) public {
    vm.assume(_projectOwnerV1 != _projectOwnerV2);

    vm.mockCall(
      address(mockProjects),
      abi.encodeWithSelector(IERC721.ownerOf.selector, _projectId),
      abi.encode(_projectOwnerV2)
    );

    vm.mockCall(
      address(mockProjectsV1),
      abi.encodeWithSelector(IERC721.ownerOf.selector, _projectIdV1),
      abi.encode(_projectOwnerV1)
    );

    // Revert for both projectOwner calling:

    vm.prank(_projectOwnerV1);
    vm.expectRevert(abi.encodeWithSignature('NOT_ALLOWED()'));
    migrationTerminal.setV1ProjectId(_projectId, _projectIdV1);

    vm.prank(_projectOwnerV2);
    vm.expectRevert(abi.encodeWithSignature('NOT_ALLOWED()'));
    migrationTerminal.setV1ProjectId(_projectId, _projectIdV1);
  }

  // --------------- pay(..) ---------------------

  function testPay_passIfTokenHolder(uint96 _unclaimedBalance, uint96 _claimedBalance) public {
    uint256 _amount = uint256(_unclaimedBalance) + uint256(_claimedBalance);
    vm.assume(_amount != 0);

    // Mock the migration terminal as one of the V2 project terminals
    vm.mockCall(
      address(mockDirectory),
      abi.encodeWithSelector(
        IJBDirectory.isTerminalOf.selector,
        projectId,
        address(migrationTerminal)
      ),
      abi.encode(true)
    );

    // Set the V1-V2 Id's
    vm.mockCall(
      address(mockProjects),
      abi.encodeWithSelector(IERC721.ownerOf.selector, projectId),
      abi.encode(projectOwner)
    );

    vm.mockCall(
      address(mockProjectsV1),
      abi.encodeWithSelector(IERC721.ownerOf.selector, projectIdV1),
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

    // Mock the transferFrom of V1 token, between caller and the terminal contract
    vm.mockCall(
      address(mockV1JBToken),
      abi.encodeWithSelector(
        IERC20.transferFrom.selector,
        caller,
        address(migrationTerminal),
        _claimedBalance
      ), // projectOwner is mocked supra
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
        address(migrationTerminal)
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
        beneficiary,
        '',
        /*preferClaimed*/
        false,
        false
      ),
      abi.encode(_amount)
    );

    vm.expectEmit(true, false, false, true);
    emit Pay(projectId, caller, beneficiary, _amount, _amount, '', caller);

    vm.prank(caller);
    migrationTerminal.pay(
      projectId,
      _amount,
      /*token*/
      address(0),
      /*beneficiary*/
      beneficiary,
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

    // Mock the migration terminal as one of the V2 project terminals
    vm.mockCall(
      address(mockDirectory),
      abi.encodeWithSelector(
        IJBDirectory.isTerminalOf.selector,
        projectId,
        address(migrationTerminal)
      ),
      abi.encode(true)
    );

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
    // Mock the migration terminal as one of the V2 project terminals
    vm.mockCall(
      address(mockDirectory),
      abi.encodeWithSelector(
        IJBDirectory.isTerminalOf.selector,
        projectId,
        address(migrationTerminal)
      ),
      abi.encode(true)
    );

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

    // Mock the migration terminal as one of the V2 project terminals
    vm.mockCall(
      address(mockDirectory),
      abi.encodeWithSelector(
        IJBDirectory.isTerminalOf.selector,
        projectId,
        address(migrationTerminal)
      ),
      abi.encode(true)
    );

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

    // Mock the migration terminal as one of the V2 project terminals
    vm.mockCall(
      address(mockDirectory),
      abi.encodeWithSelector(
        IJBDirectory.isTerminalOf.selector,
        projectId,
        address(migrationTerminal)
      ),
      abi.encode(true)
    );

    // Set the V1-V2 Id's
    vm.mockCall(
      address(mockProjects),
      abi.encodeWithSelector(IERC721.ownerOf.selector, projectId),
      abi.encode(projectOwner)
    );

    vm.mockCall(
      address(mockProjectsV1),
      abi.encodeWithSelector(IERC721.ownerOf.selector, projectIdV1),
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

    // Mock the migration terminal as one of the V2 project terminals
    vm.mockCall(
      address(mockDirectory),
      abi.encodeWithSelector(
        IJBDirectory.isTerminalOf.selector,
        projectId,
        address(migrationTerminal)
      ),
      abi.encode(true)
    );

    // Set the V1-V2 Id's
    vm.mockCall(
      address(mockProjects),
      abi.encodeWithSelector(IERC721.ownerOf.selector, projectId),
      abi.encode(projectOwner)
    );

    vm.mockCall(
      address(mockProjectsV1),
      abi.encodeWithSelector(IERC721.ownerOf.selector, projectIdV1),
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
      abi.encodeWithSelector(
        IERC20.transferFrom.selector,
        caller,
        address(migrationTerminal),
        _claimedBalance
      ), // projectOwner is mocked supra
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
        address(migrationTerminal)
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

  function testPay_revertIfNotAProjectTerminal() public {
    uint256 _amount = 1 ether;

    // Mock the migration terminal as not a terminal of the V2 project
    vm.mockCall(
      address(mockDirectory),
      abi.encodeWithSelector(
        IJBDirectory.isTerminalOf.selector,
        projectId,
        address(migrationTerminal)
      ),
      abi.encode(false)
    );

    vm.expectRevert(abi.encodeWithSignature('PROJECT_TERMINAL_MISMATCH()'));
    vm.prank(caller);
    migrationTerminal.pay(
      projectId,
      _amount,
      /*token*/
      address(0),
      /*beneficiary*/
      beneficiary,
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

  // ----------- releaseV1TokensOf(..) -----------------
  function testReleaseV1Token_PassIfCallerIsV1Owner(
    address _v1ProjectOwner,
    address _beneficiary,
    uint256 _claimedBalance,
    uint256 _unclaimedBalance
  ) public {
    // Mock the call to retrieve the v1 project owner
    vm.mockCall(
      address(mockProjectsV1),
      abi.encodeWithSelector(IERC721.ownerOf.selector, projectIdV1),
      abi.encode(_v1ProjectOwner)
    );

    // Mock the call to retrieve the correspoding V1 ERC20
    vm.mockCall(
      address(mockTicketBooth),
      abi.encodeWithSelector(ITicketBooth.ticketsOf.selector, projectIdV1),
      abi.encode(mockV1JBToken)
    );

    // Mock the call to get the migration terminal unclaimed balance
    vm.mockCall(
      address(mockTicketBooth),
      abi.encodeWithSelector(ITicketBooth.stakedBalanceOf.selector, address(migrationTerminal)),
      abi.encode(_unclaimedBalance)
    );

    // Mock the call to get the migration terminal ERC20 balance
    vm.mockCall(
      address(mockV1JBToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(migrationTerminal)),
      abi.encode(_claimedBalance)
    );

    // Mock the call to the ERC20 transfer
    vm.mockCall(
      address(mockV1JBToken),
      abi.encodeWithSelector(IERC20.transfer.selector, _beneficiary, _claimedBalance),
      abi.encode(true)
    );

    // Mock the call to the unclaimed transfer
    vm.mockCall(
      address(mockTicketBooth),
      abi.encodeWithSelector(
        ITicketBooth.transfer.selector,
        address(migrationTerminal),
        projectIdV1,
        _unclaimedBalance,
        _beneficiary
      ),
      abi.encode(true)
    );

    vm.expectEmit(true, true, false, true);
    emit ReleaseV1TokensOf(
      projectIdV1,
      _beneficiary,
      _unclaimedBalance,
      _claimedBalance,
      _v1ProjectOwner
    );

    vm.prank(_v1ProjectOwner);
    migrationTerminal.releaseV1TokensOf(projectIdV1, _beneficiary);
  }

  function testReleaseV1Token_RevertIfCallerIsNotV1Owner(
    address _v1ProjectOwner,
    address _caller,
    address _beneficiary
  ) public {
    vm.assume(_v1ProjectOwner != _caller);

    // Mock the call to retrieve the v1 project owner
    vm.mockCall(
      address(mockProjectsV1),
      abi.encodeWithSelector(IERC721.ownerOf.selector, projectIdV1),
      abi.encode(_v1ProjectOwner)
    );

    vm.prank(_caller);
    vm.expectRevert(abi.encodeWithSignature('NOT_ALLOWED()'));
    migrationTerminal.releaseV1TokensOf(projectIdV1, _beneficiary);
  }

  function testReleaseV1Token_RevertIfCalledASecondTime(
    address _v1ProjectOwner,
    address _beneficiary,
    uint256 _claimedBalance,
    uint256 _unclaimedBalance
  ) public {
    // Mock the call to retrieve the v1 project owner
    vm.mockCall(
      address(mockProjectsV1),
      abi.encodeWithSelector(IERC721.ownerOf.selector, projectIdV1),
      abi.encode(_v1ProjectOwner)
    );

    // Mock the call to retrieve the correspoding V1 ERC20
    vm.mockCall(
      address(mockTicketBooth),
      abi.encodeWithSelector(ITicketBooth.ticketsOf.selector, projectIdV1),
      abi.encode(mockV1JBToken)
    );

    // Mock the call to get the migration terminal unclaimed balance
    vm.mockCall(
      address(mockTicketBooth),
      abi.encodeWithSelector(ITicketBooth.stakedBalanceOf.selector, address(migrationTerminal)),
      abi.encode(_claimedBalance)
    );

    // Mock the call to get the migration terminal ERC20 balance
    vm.mockCall(
      address(mockV1JBToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(migrationTerminal)),
      abi.encode(_unclaimedBalance)
    );

    // Mock the call to the ERC20 transfer
    vm.mockCall(
      address(mockV1JBToken),
      abi.encodeWithSelector(IERC20.transfer.selector, _beneficiary, _unclaimedBalance),
      abi.encode(true)
    );

    // Mock the call to the unclaimed transfer
    vm.mockCall(
      address(mockTicketBooth),
      abi.encodeWithSelector(
        ITicketBooth.transfer.selector,
        address(migrationTerminal),
        projectIdV1,
        _unclaimedBalance,
        _beneficiary
      ),
      abi.encode(true)
    );

    vm.prank(_v1ProjectOwner);
    migrationTerminal.releaseV1TokensOf(projectIdV1, _beneficiary);

    vm.prank(_v1ProjectOwner);
    vm.expectRevert(abi.encodeWithSignature('MIGRATION_TERMINATED()'));
    migrationTerminal.releaseV1TokensOf(projectIdV1, _beneficiary);
  }
}
