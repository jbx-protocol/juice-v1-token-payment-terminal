// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol/contracts-v1/contracts/Projects.sol';
import '@jbx-protocol/contracts-v1/contracts/FundingCycles.sol';
import '@jbx-protocol/contracts-v1/contracts/TicketBooth.sol';
import '@jbx-protocol/contracts-v1/contracts/OperatorStore.sol';
import '@jbx-protocol/contracts-v1/contracts/TerminalDirectory.sol';
import '@jbx-protocol/contracts-v1/contracts/TerminalV1_1.sol';
import '@jbx-protocol/contracts-v1/contracts/ModStore.sol';
import '@jbx-protocol/contracts-v1/contracts/Prices.sol';
import '@jbx-protocol/contracts-v1/contracts/interfaces/IFundingCycles.sol';
import '@jbx-protocol/contracts-v1/contracts/interfaces/ITerminalV1_1.sol';
import '@jbx-protocol/contracts-v1/contracts/interfaces/IModStore.sol';
import '@jbx-protocol/contracts-v1/contracts/interfaces/IFundingCycleBallot.sol';
import '@jbx-protocol/contracts-v1/contracts/interfaces/ITreasuryExtension.sol';
import '@jbx-protocol/contracts-v1/contracts/interfaces/ITickets.sol';
import '@jbx-protocol/contracts-v1/contracts/libraries/Operations.sol';

import '@jbx-protocol/contracts-v2/contracts/JBController.sol';
import '@jbx-protocol/contracts-v2/contracts/JBDirectory.sol';
import '@jbx-protocol/contracts-v2/contracts/JBETHPaymentTerminal.sol';
import '@jbx-protocol/contracts-v2/contracts/JBERC20PaymentTerminal.sol';
import '@jbx-protocol/contracts-v2/contracts/JBSingleTokenPaymentTerminalStore.sol';
import '@jbx-protocol/contracts-v2/contracts/JBFundingCycleStore.sol';
import '@jbx-protocol/contracts-v2/contracts/JBOperatorStore.sol';
import '@jbx-protocol/contracts-v2/contracts/JBPrices.sol';
import '@jbx-protocol/contracts-v2/contracts/JBProjects.sol';
import '@jbx-protocol/contracts-v2/contracts/JBSplitsStore.sol';
import '@jbx-protocol/contracts-v2/contracts/JBToken.sol';
import '@jbx-protocol/contracts-v2/contracts/JBTokenStore.sol';

import '@jbx-protocol/contracts-v2/contracts/structs/JBDidPayData.sol';
import '@jbx-protocol/contracts-v2/contracts/structs/JBDidRedeemData.sol';
import '@jbx-protocol/contracts-v2/contracts/structs/JBFee.sol';
import '@jbx-protocol/contracts-v2/contracts/structs/JBFundAccessConstraints.sol';
import '@jbx-protocol/contracts-v2/contracts/structs/JBFundingCycle.sol';
import '@jbx-protocol/contracts-v2/contracts/structs/JBFundingCycleData.sol';
import '@jbx-protocol/contracts-v2/contracts/structs/JBFundingCycleMetadata.sol';
import '@jbx-protocol/contracts-v2/contracts/structs/JBGroupedSplits.sol';
import '@jbx-protocol/contracts-v2/contracts/structs/JBOperatorData.sol';
import '@jbx-protocol/contracts-v2/contracts/structs/JBPayParamsData.sol';
import '@jbx-protocol/contracts-v2/contracts/structs/JBProjectMetadata.sol';
import '@jbx-protocol/contracts-v2/contracts/structs/JBRedeemParamsData.sol';
import '@jbx-protocol/contracts-v2/contracts/structs/JBSplit.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBPaymentTerminal.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBToken.sol';
import '@jbx-protocol/contracts-v2/contracts/libraries/JBOperations.sol';

import '@paulrberg/contracts/math/PRBMath.sol';

import 'forge-std/Test.sol';

import './AccessJBLib.sol';

// Base contract for Juicebox system tests.
//
// Provides common functionality, such as deploying contracts on test setup.
contract TestBaseWorkflow is Test {
  //*********************************************************************//
  // --------------------- internal stored properties ------------------- //
  //*********************************************************************//

  address internal _projectOwner = address(123);
  address internal _beneficiary = address(69420);

  // ---- V1 variables ----
  Projects internal _projectsV1;
  FundingCycles internal _fundingCyclesV1;
  TicketBooth internal _ticketBoothV1;
  OperatorStore internal _operatorStoreV1;
  TerminalDirectory internal _terminalDirectoryV1;
  TerminalV1_1 internal _terminalV1_1;
  ModStore internal _modStoreV1;
  Prices internal _pricesV1;
  ITickets internal _ticketsV1;

  // ---- V2 variables ----
  JBOperatorStore internal _jbOperatorStore;
  JBProjects internal _jbProjects;
  JBPrices internal _jbPrices;
  JBDirectory internal _jbDirectory;
  JBFundingCycleStore internal _jbFundingCycleStore;
  JBTokenStore internal _jbTokenStore;
  JBSplitsStore internal _jbSplitsStore;
  JBController internal _jbController;
  JBSingleTokenPaymentTerminalStore internal _jbPaymentTerminalStore;
  JBETHPaymentTerminal internal _jbETHPaymentTerminal;
  JBProjectMetadata internal _projectMetadata;
  JBFundingCycleData internal _data;
  JBFundingCycleMetadata internal _metadata;
  JBGroupedSplits[] internal _groupedSplits;
  JBFundAccessConstraints[] internal _fundAccessConstraints;
  IJBPaymentTerminal[] internal _terminals;
  IJBToken internal _tokenV2;

  AccessJBLib internal _accessJBLib;

  uint256 internal _projectId;
  uint256 internal _projectIdV1;

  //*********************************************************************//
  // --------------------------- test setup ---------------------------- //
  //*********************************************************************//

  // Deploys and initializes contracts for testing.
  function setUp() public virtual {
    // ---- Set up V1 project ----

    _operatorStoreV1 = new OperatorStore();
    vm.label(address(_operatorStoreV1), '_operatorStoreV1');

    _projectsV1 = new Projects(_operatorStoreV1);
    vm.label(address(_projectsV1), '_projectsV1');

    _terminalDirectoryV1 = new TerminalDirectory(_projectsV1, _operatorStoreV1);
    vm.label(address(_terminalDirectoryV1), '_terminalDirectoryV1');

    _fundingCyclesV1 = new FundingCycles(_terminalDirectoryV1);
    vm.label(address(_fundingCyclesV1), '_fundingCyclesV1');

    _ticketBoothV1 = new TicketBooth(_projectsV1, _operatorStoreV1, _terminalDirectoryV1);
    vm.label(address(_ticketBoothV1), '_ticketBoothV1');

    _modStoreV1 = new ModStore(_projectsV1, _operatorStoreV1, _terminalDirectoryV1);
    vm.label(address(_modStoreV1), '_modStoreV1');

    _pricesV1 = new Prices();
    vm.label(address(_pricesV1), '_pricesV1');

    _terminalV1_1 = new TerminalV1_1(
      _projectsV1,
      _fundingCyclesV1,
      _ticketBoothV1,
      _operatorStoreV1,
      _modStoreV1,
      _pricesV1,
      _terminalDirectoryV1,
      _projectOwner
    );
    vm.label(address(_terminalV1_1), '_terminalV1_1');

    FundingCycleProperties memory _propertiesV1 = FundingCycleProperties({
      target: 10,
      currency: 1,
      duration: 60,
      cycleLimit: 10,
      discountRate: 0,
      ballot: IFundingCycleBallot(address(0))
    });

    FundingCycleMetadata2 memory _metadataV1 = FundingCycleMetadata2({
      reservedRate: 10,
      bondingCurveRate: 10,
      reconfigurationBondingCurveRate: 0,
      payIsPaused: false,
      ticketPrintingIsAllowed: true,
      treasuryExtension: ITreasuryExtension(address(0))
    });

    PayoutMod[] memory _payoutModsV1;
    TicketMod[] memory _ticketModsV1;

    _terminalV1_1.deploy(
      _projectOwner,
      bytes32('handle'),
      'myURI',
      _propertiesV1,
      _metadataV1,
      _payoutModsV1,
      _ticketModsV1
    );

    _projectIdV1 = 1;
    // Sanity check: correct project id
    assert(_projectsV1.ownerOf(_projectIdV1) == _projectOwner);

    vm.prank(_projectOwner);
    _ticketBoothV1.issue(_projectIdV1, 'V1 Ticket', 'V1');

    _ticketsV1 = _ticketBoothV1.ticketsOf(1);

    // ---- Set up V2 project ----
    _jbOperatorStore = new JBOperatorStore();
    vm.label(address(_jbOperatorStore), 'JBOperatorStore');

    _jbProjects = new JBProjects(_jbOperatorStore);
    vm.label(address(_jbProjects), 'JBProjects');

    _jbPrices = new JBPrices(_projectOwner);
    vm.label(address(_jbPrices), 'JBPrices');

    address contractAtNoncePlusOne = addressFrom(address(this), 13);

    _jbFundingCycleStore = new JBFundingCycleStore(IJBDirectory(contractAtNoncePlusOne));
    vm.label(address(_jbFundingCycleStore), 'JBFundingCycleStore');

    _jbDirectory = new JBDirectory(
      _jbOperatorStore,
      _jbProjects,
      _jbFundingCycleStore,
      _projectOwner
    );
    vm.label(address(_jbDirectory), 'JBDirectory');

    _jbTokenStore = new JBTokenStore(_jbOperatorStore, _jbProjects, _jbDirectory);
    vm.label(address(_jbTokenStore), 'JBTokenStore');

    _jbSplitsStore = new JBSplitsStore(_jbOperatorStore, _jbProjects, _jbDirectory);
    vm.label(address(_jbSplitsStore), 'JBSplitsStore');

    _jbController = new JBController(
      _jbOperatorStore,
      _jbProjects,
      _jbDirectory,
      _jbFundingCycleStore,
      _jbTokenStore,
      _jbSplitsStore
    );
    vm.label(address(_jbController), 'JBController');

    vm.prank(_projectOwner);
    _jbDirectory.setIsAllowedToSetFirstController(address(_jbController), true);

    _jbPaymentTerminalStore = new JBSingleTokenPaymentTerminalStore(
      _jbDirectory,
      _jbFundingCycleStore,
      _jbPrices
    );
    vm.label(address(_jbPaymentTerminalStore), 'JBSingleTokenPaymentTerminalStore');

    _accessJBLib = new AccessJBLib();

    _jbETHPaymentTerminal = new JBETHPaymentTerminal(
      _accessJBLib.ETH(),
      _jbOperatorStore,
      _jbProjects,
      _jbDirectory,
      _jbSplitsStore,
      _jbPrices,
      _jbPaymentTerminalStore,
      _projectOwner
    );
    vm.label(address(_jbETHPaymentTerminal), 'JBETHPaymentTerminal');

    _terminals.push(_jbETHPaymentTerminal);

    _projectMetadata = JBProjectMetadata({content: 'myIPFSHash', domain: 1});

    _data = JBFundingCycleData({
      duration: 14,
      weight: 1000 * 10**18,
      discountRate: 450000000,
      ballot: IJBFundingCycleBallot(address(0))
    });

    _metadata = JBFundingCycleMetadata({
      global: JBGlobalFundingCycleMetadata({allowSetTerminals: false, allowSetController: false}),
      reservedRate: 5000,
      redemptionRate: 5000, //50%
      ballotRedemptionRate: 0,
      pausePay: false,
      pauseDistributions: false,
      pauseRedeem: false,
      pauseBurn: false,
      allowMinting: true,
      allowChangeToken: true,
      allowTerminalMigration: false,
      allowControllerMigration: false,
      holdFees: false,
      useTotalOverflowForRedemptions: false,
      useDataSourceForPay: false,
      useDataSourceForRedeem: false,
      dataSource: address(0)
    });

    // Launch a first one, to have different project Id V1-V2
    _jbController.launchProjectFor(
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

    // ---- general setup ----
    vm.deal(_beneficiary, 100 ether);
    vm.deal(_projectOwner, 100 ether);

    vm.label(_projectOwner, 'projectOwner');
    vm.label(_beneficiary, 'beneficiary');
  }

  //https://ethereum.stackexchange.com/questions/24248/how-to-calculate-an-ethereum-contracts-address-during-its-creation-using-the-so
  function addressFrom(address _origin, uint256 _nonce) internal pure returns (address _address) {
    bytes memory data;
    if (_nonce == 0x00) data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, bytes1(0x80));
    else if (_nonce <= 0x7f)
      data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, uint8(_nonce));
    else if (_nonce <= 0xff)
      data = abi.encodePacked(bytes1(0xd7), bytes1(0x94), _origin, bytes1(0x81), uint8(_nonce));
    else if (_nonce <= 0xffff)
      data = abi.encodePacked(bytes1(0xd8), bytes1(0x94), _origin, bytes1(0x82), uint16(_nonce));
    else if (_nonce <= 0xffffff)
      data = abi.encodePacked(bytes1(0xd9), bytes1(0x94), _origin, bytes1(0x83), uint24(_nonce));
    else data = abi.encodePacked(bytes1(0xda), bytes1(0x94), _origin, bytes1(0x84), uint32(_nonce));
    bytes32 hash = keccak256(data);
    assembly {
      mstore(0, hash)
      _address := mload(0)
    }
  }
}
