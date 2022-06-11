pragma solidity 0.8.6;

import 'forge-std/Test.sol';
import '../../contracts/JBV1V2MigrationTerminal.sol';

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBOperatorStore.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBProjects.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBDirectory.sol';
import '@jbx-protocol/contracts-v1/contracts/interfaces/ITicketBooth.sol';

contract Deploy is Test {
  IJBOperatorStore _operatorStore = IJBOperatorStore(0xEDB2db4b82A4D4956C3B4aA474F7ddf3Ac73c5AB);
  IJBProjects _projects = IJBProjects(0x2d8e361f8F1B5daF33fDb2C99971b33503E60EEE);
  IJBDirectory _directory = IJBDirectory(0x1A9b04A9617ba5C9b7EBfF9668C30F41db6fC21a);
  ITicketBooth _ticketBooth = ITicketBooth(0x0d038636a670E8bd8cF7D56BC4626f2a6446cF11);

  JBV1V2MigrationTerminal migrationTerminal;

  event TestDecimals(uint256);

  function run() external {
    vm.startBroadcast();

    migrationTerminal = new JBV1V2MigrationTerminal(
      _operatorStore,
      _projects,
      _directory,
      _ticketBooth
    );

    emit TestDecimals(migrationTerminal.decimalsForToken(address(69)));
  }
}
