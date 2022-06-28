pragma solidity 0.8.6;

import 'forge-std/Test.sol';
import '../../contracts/JBV1TokenPaymentTerminal.sol';

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBDirectory.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBOperatorStore.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBProjects.sol';
import '@jbx-protocol/contracts-v1/contracts/interfaces/ITicketBooth.sol';

// Follow this issue https://github.com/foundry-rs/foundry/pull/2038 for the JSON reading support
// and dynamicaly link the addresses in the future.

contract DeployMainnet is Test {
  IJBOperatorStore _operatorStore = IJBOperatorStore(0x6F3C5afCa0c9eDf3926eF2dDF17c8ae6391afEfb);
  IJBProjects _projects = IJBProjects(0xD8B4359143eda5B2d763E127Ed27c77addBc47d3);
  IJBDirectory _directory = IJBDirectory(0xCc8f7a89d89c2AB3559f484E0C656423E979ac9C);
  ITicketBooth _ticketBooth = ITicketBooth(0xee2eBCcB7CDb34a8A822b589F9E8427C24351bfc);

  JBV1TokenPaymentTerminal migrationTerminal;

  event TestDecimals(uint256);

  function run() external {
    vm.startBroadcast();

    migrationTerminal = new JBV1TokenPaymentTerminal(_projects, _directory, _ticketBooth);

    emit TestDecimals(migrationTerminal.decimalsForToken(address(69)));
  }
}

contract DeployRinkeby is Test {
  IJBOperatorStore _operatorStore = IJBOperatorStore(0xEDB2db4b82A4D4956C3B4aA474F7ddf3Ac73c5AB);
  IJBProjects _projects = IJBProjects(0x2d8e361f8F1B5daF33fDb2C99971b33503E60EEE);
  IJBDirectory _directory = IJBDirectory(0x1A9b04A9617ba5C9b7EBfF9668C30F41db6fC21a);
  ITicketBooth _ticketBooth = ITicketBooth(0x0d038636a670E8bd8cF7D56BC4626f2a6446cF11);

  JBV1TokenPaymentTerminal migrationTerminal;

  event TestDecimals(uint256);

  function run() external {
    vm.startBroadcast();

    migrationTerminal = new JBV1TokenPaymentTerminal(_projects, _directory, _ticketBooth);

    emit TestDecimals(migrationTerminal.decimalsForToken(address(69)));
  }
}
