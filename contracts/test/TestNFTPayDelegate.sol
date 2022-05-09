// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './helpers/TestBaseWorkflow.sol';
import '../NFT-example/NFTPayDelegate.sol';
import '../NFT-example/NFTFundingCycleDataSource.sol';

import '@jbx-protocol-v2/contracts/interfaces/IJBPayDelegate.sol';
import '@jbx-protocol-v2/contracts/interfaces/IJBRedemptionDelegate.sol';
import '@jbx-protocol-v2/contracts/interfaces/IJBFundingCycleDataSource.sol';

contract TestNFTPayDelegate is TestBaseWorkflow {
  JBController private _controller;
  JBETHPaymentTerminal private _terminal;
  JBTokenStore private _tokenStore;

  JBProjectMetadata private _projectMetadata;
  JBFundingCycleData private _data;
  JBFundingCycleMetadata private _metadata;
  JBGroupedSplits[] private _groupedSplits; // Default empty
  JBFundAccessConstraints[] private _fundAccessConstraints; // Default empty
  IJBPaymentTerminal[] private _terminals; // Default empty

  uint256 private _projectId;
  address private _projectOwner;
  uint256 private _weight = 1000 * 10**18;
  uint256 private _targetInWei = 10 * 10**18;

  IJBPayDelegate payDelegate;

  function setUp() public override {
    super.setUp();

    payDelegate = new NFTRewards(address(jbETHPaymentTerminal()));

    IJBFundingCycleDataSource dataSource = new NFTFundingCycleDataSource(payDelegate);

    _controller = jbController();

    _terminal = jbETHPaymentTerminal();

    _tokenStore = jbTokenStore();

    _projectMetadata = JBProjectMetadata({content: 'myIPFSHash', domain: 1});

    _data = JBFundingCycleData({
      duration: 14,
      weight: _weight,
      discountRate: 450000000,
      ballot: IJBFundingCycleBallot(address(0))
    });

    _metadata = JBFundingCycleMetadata({
      reservedRate: 0,
      redemptionRate: 10000, //100%
      ballotRedemptionRate: 0,
      pausePay: false,
      pauseDistributions: false,
      pauseRedeem: false,
      pauseBurn: false,
      allowMinting: false,
      allowChangeToken: false,
      allowTerminalMigration: false,
      allowControllerMigration: false,
      allowSetTerminals: false,
      allowSetController: false,
      holdFees: false,
      useTotalOverflowForRedemptions: false,
      useDataSourceForPay: true,
      useDataSourceForRedeem: true,
      dataSource: dataSource
    });

    _terminals.push(_terminal);

    _fundAccessConstraints.push(
      JBFundAccessConstraints({
        terminal: _terminal,
        token: jbLibraries().ETHToken(),
        distributionLimit: _targetInWei, // 10 ETH target
        overflowAllowance: 5 ether,
        distributionLimitCurrency: 1, // Currency = ETH
        overflowAllowanceCurrency: 1
      })
    );

    _projectOwner = multisig();

    _projectId = _controller.launchProjectFor(
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
  }

  /// @notice will test the NFT minting triggered by a call to pay()
  function testMint() public {
    address caller = address(69420);
    evm.startPrank(caller);
    evm.deal(caller, 100 ether);

    _terminal.pay{value: 20 ether}(
      _projectId,
      20 ether,
      address(0),
      caller,
      0,
      false,
      'Take my money',
      new bytes(0)
    );

    assertEq(NFTRewards(address(payDelegate)).balanceOf(caller), 1);
  }

  /// @notice test the variable redeem weight if the caller is either an NFT holder or not
  function testRedeem() public {
    address callerOne = address(69420);
    address callerTwo = address(42069);

    // pay to the project, caller One will then receive the NFT (via the pay delegate)
    evm.startPrank(callerOne);
    evm.deal(callerOne, 100 ether);

    _terminal.pay{value: 20 ether}(
      _projectId,
      20 ether,
      address(0),
      callerOne,
      0,
      false,
      'Take my money',
      new bytes(0)
    );

    // split the token received -> caller one has an NFT while caller two not
    uint256 tokenBalance = jbTokenStore().balanceOf(callerOne, _projectId);
    jbTokenStore().transferFrom(callerOne, _projectId, callerTwo, tokenBalance / 2);

    uint256 balanceBeforeCallerOne = callerOne.balance;

    _terminal.redeemTokensOf(
      callerOne,
      _projectId,
      tokenBalance / 2,
      jbLibraries().ETHToken(),
      1,
      payable(callerOne),
      '',
      '0x'
    );

    uint256 transferedCallerOne = callerOne.balance - balanceBeforeCallerOne;

    evm.stopPrank();
    evm.startPrank(callerTwo);
    uint256 balanceBeforeCallerTwo = callerTwo.balance;

    _terminal.redeemTokensOf(
      callerTwo,
      _projectId,
      tokenBalance / 2,
      jbLibraries().ETHToken(),
      0,
      payable(callerTwo),
      '',
      '0x'
    );

    uint256 transferedCallerTwo = callerTwo.balance - balanceBeforeCallerTwo;

    // One should have received more eth than two
    assertGt(transferedCallerOne, transferedCallerTwo);
  }
}
