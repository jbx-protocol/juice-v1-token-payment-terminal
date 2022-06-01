// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBPaymentTerminal.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBRedemptionTerminal.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBController/1.sol';
import '@jbx-protocol/contracts-v2/contracts/abstract/JBOperatable.sol';
import '@jbx-protocol/contracts-v2/contracts/libraries/JBOperations.sol';
import './interfaces/IJBV1V2MigrationTerminal.sol';

contract JBV1V2Terminal is IJBV1V2MigrationTerminal, IJBPaymentTerminal, JBOperatable {
  //*********************************************************************//
  // --------------------------- custom errors ------------------------- //
  //*********************************************************************//
  error INSUFFICIENT_FUNDS();
  error INVALID_AMOUNT();
  error NO_MSG_VALUE_ALLOWED();
  error NOT_ALLOWED();
  error NOT_SUPPORTED();
  error UNEXPECTED_AMOUNT();
  error V1_PROJECT_NOT_SET();

  //*********************************************************************//
  // ---------------- public immutable stored properties --------------- //
  //*********************************************************************//

  /**
    @notice
    The V1 contract where tokens are stored.
  */
  ITicketBooth public immutable override ticketBooth;

  /**
    @notice
    The directory of terminals and controllers for projects.
  */
  IJBDirectory public immutable override directory;

  /**
    @notice
    Mints ERC-721's that represent project ownership and transfers.
  */
  IJBProjects public immutable override projects;

  //*********************************************************************//
  // --------------------- public stored properties -------------------- //
  //*********************************************************************//

  /** 
    @notice 
    The v1 project ID for a project.

    _projectId The ID of the project to accept migrations for.
  */
  mapping(uint256 => uint256) public override v1ProjectIdOf;

  /** 
    @notice 
    Unused - for interface completion
  */
  mapping(uint256 => mapping(uint256 => uint256)) public override balanceOf;

  /** 
    @notice
    A flag indicating if this terminal accepts the specified token.

    @param _token The token to check if this terminal accepts or not.
    @param _projectId The project ID to check for token acceptance.

    @return The flag.
  */
  function acceptsToken(address _token, uint256 _projectId) external view override returns (bool) {
    return address(ticketBooth.ticketsOf(_projectId)) == _token;
  }

  /** 
    @notice
    The decimals that should be used in fixed number accounting for the specified token.

    @param _token The token to check for the decimals of.

    @return The number of decimals for the token.
  */
  function decimalsForToken(address _token) external pure override returns (uint256) {
    _token; // Prevents unused var compiler and natspec complaints.

    // V1 tokens are always 18 decimals.
    return 18;
  }

  /** 
    @notice
    The currency that should be used for the specified token.

    @param _token The token to check for the currency of.

    @return The currency index.
  */
  function currencyForToken(address _token) external pure override returns (uint256) {
    _token; // Prevents unused var compiler and natspec complaints.

    // There's no currency for the token.
    return 0;
  }

  function currentEthOverflowOf(uint256 _projectId) external pure override returns (uint256) {
    _projectId; // Prevents unused var compiler and natspec complaints.

    // This terminal has no overflow.
    return 0;
  }

  function supportsInterface(bytes4 _interfaceId) external pure override returns (bool) {
    return
      _interfaceId == type(IJBPaymentTerminal).interfaceId ||
      _interfaceId == type(IJBV1V2MigrationTerminal).interfaceId;
  }

  //*********************************************************************//
  // -------------------------- constructor ---------------------------- //
  //*********************************************************************//

  /**
    @param _operatorStore A contract storing operator assignments.
    @param _projects A contract which mints ERC-721's that represent project ownership and transfers.
    @param _directory A contract storing directories of terminals and controllers for each project.
    @param _ticketBooth The V1 contract where tokens are stored.
  */
  constructor(
    IJBOperatorStore _operatorStore,
    IJBProjects _projects,
    IJBDirectory _directory,
    ITicketBooth _ticketBooth
  ) JBOperatable(_operatorStore) {
    projects = _projects;
    directory = _directory;
    ticketBooth = _ticketBooth;
  }

  //*********************************************************************//
  // ---------------------- external transactions ---------------------- //
  //*********************************************************************//

  /** 
    @notice 
    Allows a project owner to initialize the acceptance of a v1 project's tokens in exchange for it's v2 project token.

    @dev
    Only a project owner can initiate token migration.
  */
  function setV1ProjectId(uint256 _projectId, uint256 _v1ProjectId) external override {
    if (
      msg.sender != projects.ownerOf(_projectId) ||
      msg.sender != ticketBooth.projects().ownerOf(_v1ProjectId)
    ) revert NOT_ALLOWED();

    // Store the mapping.
    v1ProjectIdOf[_projectId] = _v1ProjectId;

    emit SetV1ProjectId(_projectId, _v1ProjectId, msg.sender);
  }

  function pay(
    uint256 _projectId,
    uint256 _amount,
    address _token,
    address _beneficiary,
    uint256 _minReturnedTokens,
    bool _preferClaimedTokens,
    string calldata _memo,
    bytes calldata _metadata
  ) external payable override returns (uint256 beneficiaryTokenCount) {
    _token; // Prevents unused var compiler and natspec complaints.
    _minReturnedTokens; // Prevents unused var compiler and natspec complaints.
    _metadata; // Prevents unused var compiler and natspec complaints.

    // Make sure an amount is specified.
    if (_amount == 0) revert INVALID_AMOUNT();

    // Make sure no ETH was sent.
    if (msg.value > 0) revert NO_MSG_VALUE_ALLOWED();

    return _pay(_projectId, _amount, _beneficiary, _preferClaimedTokens, _memo);
  }

  function addToBalanceOf(
    uint256 _projectId,
    uint256 _amount,
    address _token,
    string calldata _memo,
    bytes calldata _metadata
  ) external payable override {
    _projectId; // Prevents unused var compiler and natspec complaints.
    _amount; // Prevents unused var compiler and natspec complaints.
    _token; // Prevents unused var compiler and natspec complaints.
    _memo; // Prevents unused var compiler and natspec complaints.
    _metadata; // Prevents unused var compiler and natspec complaints.

    revert NOT_SUPPORTED();
  }

  function _pay(
    uint256 _projectId,
    uint256 _amount,
    address _beneficiary,
    bool _preferClaimedTokens,
    string calldata _memo
  ) private returns (uint256 beneficiaryTokenCount) {
    // Get the v1 project.
    uint256 _v1ProjectId = v1ProjectIdOf[_projectId];

    // Make sure the v1 project has been set.
    if (_v1ProjectId == 0) revert V1_PROJECT_NOT_SET();

    // Get a reference to the v1 project's ERC20 tokens.
    ITickets _v1Token = ticketBooth.ticketsOf(_v1ProjectId);

    // The amount of tokens to migrate.
    uint256 _claimedTokensToMigrate;

    {
      // Get a reference to the migrator's unclaimed balance.
      uint256 _unclaimedBalance = ticketBooth.stakedBalanceOf(msg.sender, _v1ProjectId);

      // Get a reference to the migrator's erc20 balance.
      uint256 _claimedBalance = _v1Token == ITickets(address(0))
        ? 0
        : _v1Token.balanceOf(msg.sender);

      // There must be enough v1 tokens to migrate.
      if (_amount > _claimedBalance + _unclaimedBalance) revert INSUFFICIENT_FUNDS();

      // If there's no balance, migrate no tokens.
      if (_claimedBalance == 0)
        _claimedTokensToMigrate = 0;
        // If prefer claimed tokens, migrate tokens before redeeming unclaimed tokens.
      else if (_preferClaimedTokens)
        _claimedTokensToMigrate = _claimedBalance < _amount ? _claimedBalance : _amount;
        // Otherwise, migrate unclaimed tokens before claimed tokens.
      else _claimedTokensToMigrate = _unclaimedBalance < _amount ? _amount - _unclaimedBalance : 0;
    }

    // The amount of unclaimed tokens to migrate.
    uint256 _unclaimedTokensToMigrate = _amount - _claimedTokensToMigrate;

    address _projectOwner = projects.ownerOf(_projectId);

    if (_claimedTokensToMigrate > 0)
      // Transfer tokens to the project owner from the msg sender.
      IERC20(_v1Token).transferFrom(msg.sender, _projectOwner, _claimedTokensToMigrate);

    if (_unclaimedTokensToMigrate > 0)
      // Transfer tokens to the project owner from the msg sender.
      ticketBooth.transfer(msg.sender, _v1ProjectId, _unclaimedTokensToMigrate, _projectOwner);

    // Mint the tokens for the beneficary.
    beneficiaryTokenCount = IJBController(directory.controllerOf(_projectId)).mintTokensOf(
      _projectId,
      _amount,
      _beneficiary,
      '',
      _preferClaimedTokens,
      false
    );

    // Make sure the token amount is the same as the v1 token amount.
    if (beneficiaryTokenCount != _amount) revert UNEXPECTED_AMOUNT();

    emit Pay(
      _projectId,
      msg.sender,
      _beneficiary,
      _amount,
      beneficiaryTokenCount,
      _memo,
      msg.sender
    );
  }
}
