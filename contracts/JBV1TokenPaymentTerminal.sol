// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBController.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBPaymentTerminal.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/introspection/ERC165.sol';
import './interfaces/IJBV1TokenPaymentTerminal.sol';

/** 
  @title 
  JBV1TokenPaymentTerminal

  @notice 
  Allows project owners to specify the v1 project token that they are willing to accept from holders in exchange for their v2 project token. 

  @dev
  Project owners must add this terminal to their list of set terminals in the JBDirectory so that it can mint tokens on the project's behalf.

  @dev
  Project owners must initialize their v1 token they are willing to swap at a rate of 1:1.

  @dev
  Project owners can finalize and stop v1 to v2 token swaps at any time, at which point they can withdraw the v1 tokens locked in this contract.

  @dev
  Adheres to -
  IJBV1TokenPaymentTerminal: General interface for the methods in this contract that interact with the blockchain's state according to the protocol's rules.
  IJBPaymentTerminal: Standardized interface for project to receive payments.

  @dev
  Inherits from -
  ERC165: Introspection on interface adherance. 
*/
contract JBV1TokenPaymentTerminal is IJBV1TokenPaymentTerminal, IJBPaymentTerminal, ERC165 {
  //*********************************************************************//
  // --------------------------- custom errors ------------------------- //
  //*********************************************************************//
  error INSUFFICIENT_FUNDS();
  error INVALID_AMOUNT();
  error MIGRATION_TERMINATED();
  error NO_MSG_VALUE_ALLOWED();
  error NOT_ALLOWED();
  error NOT_SUPPORTED();
  error PROJECT_TERMINAL_MISMATCH();
  error UNEXPECTED_AMOUNT();
  error V1_PROJECT_NOT_SET();

  //*********************************************************************//
  // ---------------------------- modifiers ---------------------------- //
  //*********************************************************************//

  /** 
    @notice 
    A modifier that verifies this terminal is a terminal of provided project ID.
  */
  modifier isTerminalOf(uint256 _projectId) {
    if (!directory.isTerminalOf(_projectId, this)) revert PROJECT_TERMINAL_MISMATCH();
    _;
  }

  //*********************************************************************//
  // ---------------- public immutable stored properties --------------- //
  //*********************************************************************//

  /**
    @notice
    Mints ERC-721's that represent project ownership and transfers.
  */
  IJBProjects public immutable override projects;

  /**
    @notice
    The directory of terminals and controllers for projects.
  */
  IJBDirectory public immutable override directory;

  /**
    @notice
    The V1 contract where token balances are stored.
  */
  ITicketBooth public immutable override ticketBooth;

  //*********************************************************************//
  // --------------------- public stored properties -------------------- //
  //*********************************************************************//

  /** 
    @notice 
    The v1 project ID for a v2 project.

    _projectId The ID of the v2 project to exchange tokens for. 
  */
  mapping(uint256 => uint256) public override v1ProjectIdOf;

  /** 
    @notice 
    A flag indicating if a project's migration has finished.

    _projectId The ID of the project to check the migration status.
  */
  mapping(uint256 => bool) public override finalized;

  /** 
    @notice
    A flag indicating if this terminal accepts the specified token.

    @param _token The token to check if this terminal accepts or not.
    @param _projectId The project ID to check for token acceptance.

    @return The flag.
  */
  function acceptsToken(address _token, uint256 _projectId) external view override returns (bool) {
    _token; // Prevents unused var compiler and natspec complaints.
    _projectId; // Prevents unused var compiler and natspec complaints.

    // Get a reference to the V1 project for the provided project ID.
    uint256 _v1ProjectId = v1ProjectIdOf[_projectId];

    // Accept the token if it has been set and the exchange hasn't yet finalized.
    return address(ticketBooth.ticketsOf(_v1ProjectId)) == _token && !finalized[_v1ProjectId];
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

  /**
    @notice
    Gets the current overflowed amount in this terminal for a specified project, in terms of ETH.

    @dev
    The current overflow is represented as a fixed point number with 18 decimals.

    @param _projectId The ID of the project to get overflow for.

    @return The current amount of ETH overflow that project has in this terminal, as a fixed point number with 18 decimals.
  */
  function currentEthOverflowOf(uint256 _projectId) external pure override returns (uint256) {
    _projectId; // Prevents unused var compiler and natspec complaints.

    // This terminal has no overflow.
    return 0;
  }

  /**
    @notice
    Indicates if this contract adheres to the specified interface.

    @dev 
    See {IERC165-supportsInterface}.

    @param _interfaceId The ID of the interface to check for adherance to.
  */
  function supportsInterface(bytes4 _interfaceId)
    public
    view
    override(ERC165, IERC165)
    returns (bool)
  {
    return
      _interfaceId == type(IJBPaymentTerminal).interfaceId ||
      _interfaceId == type(IJBV1TokenPaymentTerminal).interfaceId ||
      super.supportsInterface(_interfaceId);
  }

  //*********************************************************************//
  // -------------------------- constructor ---------------------------- //
  //*********************************************************************//

  /**
    @param _projects A contract which mints ERC-721's that represent project ownership and transfers.
    @param _directory A contract storing directories of terminals and controllers for each project.
    @param _ticketBooth The V1 contract where tokens are stored.
  */
  constructor(
    IJBProjects _projects,
    IJBDirectory _directory,
    ITicketBooth _ticketBooth
  ) {
    projects = _projects;
    directory = _directory;
    ticketBooth = _ticketBooth;
  }

  //*********************************************************************//
  // ---------------------- external transactions ---------------------- //
  //*********************************************************************//

  /** 
    @notice 
    Allows a project owner to initialize the acceptance of a v1 project's tokens in exchange for its v2 project token.

    @dev
    Only a project owner can initiate token migration.

    @param _projectId The ID of the v2 project to set a v1 project ID for.
    @param _v1ProjectId The ID of the v1 project to set.
  */
  function setV1ProjectIdOf(uint256 _projectId, uint256 _v1ProjectId) external override {
    // Can't set the v1 project ID if it isn't owned by the same address who owns the v2 project.
    if (
      msg.sender != projects.ownerOf(_projectId) ||
      msg.sender != ticketBooth.projects().ownerOf(_v1ProjectId)
    ) revert NOT_ALLOWED();

    // Store the mapping.
    v1ProjectIdOf[_projectId] = _v1ProjectId;

    emit SetV1ProjectId(_projectId, _v1ProjectId, msg.sender);
  }

  /** 
    @notice 
    Allows a v1 project token holder to pay into this terminal to get commensurate about of its v2 token.

    @param _projectId The ID of the v2 project to pay towards.
    @param _amount The amount of v1 project tokens being paid, as a fixed point number with the same amount of decimals as this terminal.
    @param _token The token being paid. This terminal ignores this property since it only manages v1 tokens preset by the project being paid. 
    @param _beneficiary The address to mint v2 project tokens for.
    @param _minReturnedTokens The minimum number of v2 project tokens expected in return, as a fixed point number with 18 decimals.
    @param _preferClaimedTokens A flag indicating whether the request prefers to mint v2 project tokens into the beneficiaries wallet rather than leaving them unclaimed. This is only possible if the project has an attached token contract. Leaving them unclaimed saves gas.
    @param _memo A memo to pass along to the emitted event. 
    @param _metadata Bytes to send along to the data source, delegate, and emitted event, if provided. This terminal ignores this property because there's no data source.

    @return beneficiaryTokenCount The number of v2 tokens minted for the beneficiary, as a fixed point number with 18 decimals.
  */
  function pay(
    uint256 _projectId,
    uint256 _amount,
    address _token,
    address _beneficiary,
    uint256 _minReturnedTokens,
    bool _preferClaimedTokens,
    string calldata _memo,
    bytes calldata _metadata
  ) external payable override isTerminalOf(_projectId) returns (uint256 beneficiaryTokenCount) {
    _token; // Prevents unused var compiler and natspec complaints.
    _metadata; // Prevents unused var compiler and natspec complaints.

    // Make sure the migration hasn't already been finalized.
    if (finalized[_projectId]) revert MIGRATION_TERMINATED();

    // Make sure an amount is specified.
    if (_amount == 0) revert INVALID_AMOUNT();

    // Make sure no ETH was sent.
    if (msg.value > 0) revert NO_MSG_VALUE_ALLOWED();

    return _pay(_projectId, _amount, _beneficiary, _minReturnedTokens, _preferClaimedTokens, _memo);
  }

  /** 
    @notice
    Allows a project owner to gain custody of all the v1 tokens that have been paid, after they have finalized the ability for v1 token holders to convert to v2 tokens via this contract.

    @param _v1ProjectId The ID of the v1 project whose tokens are being released.
    @param _beneficiary The address that the tokens are being sent to.
  */
  function releaseV1TokensOf(uint256 _v1ProjectId, address _beneficiary) external override {
    // Make sure only the v1 project owner can retrieve the tokens.
    if (msg.sender != ticketBooth.projects().ownerOf(_v1ProjectId)) revert NOT_ALLOWED();

    // Make sure v1 token conversion has not yet finalized.
    if (finalized[_v1ProjectId]) revert MIGRATION_TERMINATED();

    // Get a reference to the v1 project's ERC20 tokens.
    ITickets _v1Token = ticketBooth.ticketsOf(_v1ProjectId);

    // Get a reference to this terminal's unclaimed balance.
    uint256 _unclaimedBalance = ticketBooth.stakedBalanceOf(address(this), _v1ProjectId);

    // Get a reference to this terminal's ERC20 balance.
    uint256 _erc20Balance = _v1Token == ITickets(address(0))
      ? 0
      : _v1Token.balanceOf(address(this));

    // Store the finalized state.
    finalized[_v1ProjectId] = true;

    // Transfer ERC20 v1 tokens to the beneficiary.
    if (_erc20Balance != 0) _v1Token.transfer(_beneficiary, _erc20Balance);

    // Transfer unclaimed v1 tokens to the beneficiary.
    if (_unclaimedBalance != 0)
      ticketBooth.transfer(address(this), _v1ProjectId, _unclaimedBalance, _beneficiary);

    emit ReleaseV1TokensOf(
      _v1ProjectId,
      _beneficiary,
      _unclaimedBalance,
      _erc20Balance,
      msg.sender
    );
  }

  /**
    @notice
    Receives funds belonging to the specified project.

    @dev 
    This terminal does not allow adding directly to a project's balance.

    @param _projectId The ID of the project to which the funds received belong. This is ignored since this terminal doesn't allow this function.
    @param _amount The amount of tokens to add, as a fixed point number with the same number of decimals as this terminal. This is ignored since this terminal doesn't allow this function.
    @param _token The token being paid. This terminal ignores this property since it only manages one currency. This is ignored since this terminal doesn't allow this function.
    @param _memo A memo to pass along to the emitted event. This is ignored since this terminal doesn't allow this function.
    @param _metadata Extra data to pass along to the emitted event. This is ignored since this terminal doesn't allow this function.
  */
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

  //*********************************************************************//
  // ------------------------ internal functions ----------------------- //
  //*********************************************************************//

  /** 
    @notice 
    Allows a v1 project token holder to pay into this terminal to get commensurate about of its v2 token.

    @param _projectId The ID of the v2 project to pay towards.
    @param _amount The amount of v1 project tokens being paid, as a fixed point number with the same amount of decimals as this terminal.
    @param _beneficiary The address to mint tokens for.
    @param _minReturnedTokens The minimum number of v2 project tokens expected in return, as a fixed point number with the same amount of decimals as this terminal.
    @param _preferClaimedTokens A flag indicating whether the request prefers to mint v2 project tokens into the beneficiaries wallet rather than leaving them unclaimed. This is only possible if the project has an attached token contract. Leaving them unclaimed saves gas.
    @param _memo A memo to pass along to the emitted event. 

    @return beneficiaryTokenCount The number of v2 tokens minted for the beneficiary, as a fixed point number with 18 decimals.
  */
  function _pay(
    uint256 _projectId,
    uint256 _amount,
    address _beneficiary,
    uint256 _minReturnedTokens,
    bool _preferClaimedTokens,
    string calldata _memo
  ) internal returns (uint256 beneficiaryTokenCount) {
    // Get the v1 project for the v2 project being paid.
    uint256 _v1ProjectId = v1ProjectIdOf[_projectId];

    // Make sure the v1 project has been set.
    if (_v1ProjectId == 0) revert V1_PROJECT_NOT_SET();

    // Get a reference to the v1 project's ERC20 tokens.
    ITickets _v1Token = ticketBooth.ticketsOf(_v1ProjectId);

    // Define variables that will be needed outside the scoped section below.
    // Keep a reference to the amount of v2 tokens to mint from the message sender's v1 ERC20 balance.
    uint256 _tokensToMintFromERC20s;

    {
      // Get a reference to the migrator's unclaimed balance.
      uint256 _unclaimedBalance = ticketBooth.stakedBalanceOf(msg.sender, _v1ProjectId);

      // Get a reference to the migrator's ERC20 balance.
      uint256 _erc20Balance = _v1Token == ITickets(address(0)) ? 0 : _v1Token.balanceOf(msg.sender);

      // There must be enough v1 tokens to migrate.
      if (_amount > _erc20Balance + _unclaimedBalance) revert INSUFFICIENT_FUNDS();

      // If there's no ERC20 balance, theres no tokens to mint as a result of the ERC20 balance.
      if (_erc20Balance == 0)
        _tokensToMintFromERC20s = 0;
        // If prefer claimed tokens, exchange ERC20 tokens before exchanging unclaimed tokens.
      else if (_preferClaimedTokens)
        _tokensToMintFromERC20s = _erc20Balance < _amount ? _erc20Balance : _amount;
        // Otherwise, exchange unclaimed tokens before ERC20 tokens.
      else _tokensToMintFromERC20s = _unclaimedBalance < _amount ? _amount - _unclaimedBalance : 0;
    }

    // The amount of unclaimed tokens to migrate.
    uint256 _tokensToMintFromUnclaimedBalance = _amount - _tokensToMintFromERC20s;

    // Transfer v1 ERC20 tokens to this terminal from the msg sender if needed.
    if (_tokensToMintFromERC20s != 0)
      IERC20(_v1Token).transferFrom(msg.sender, address(this), _tokensToMintFromERC20s);

    // Transfer v1 unclaimed tokens to this terminal from the msg sender if needed.
    if (_tokensToMintFromUnclaimedBalance != 0)
      ticketBooth.transfer(
        msg.sender,
        _v1ProjectId,
        _tokensToMintFromUnclaimedBalance,
        address(this)
      );

    // Mint the v2 tokens for the beneficary.
    beneficiaryTokenCount = IJBController(directory.controllerOf(_projectId)).mintTokensOf(
      _projectId,
      _amount,
      _beneficiary,
      '',
      _preferClaimedTokens,
      false
    );

    // Make sure the token amount is the same as the v1 token amount and is at least what is expected.
    if (beneficiaryTokenCount != _amount || beneficiaryTokenCount < _minReturnedTokens)
      revert UNEXPECTED_AMOUNT();

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
