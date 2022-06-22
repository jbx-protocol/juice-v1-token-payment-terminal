// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbox/sol/contracts/TicketBooth.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBDirectory.sol';
import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBProjects.sol';

interface IJBV1TokenPaymentTerminal {
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

  function ticketBooth() external view returns (ITicketBooth);

  function directory() external view returns (IJBDirectory);

  function projects() external view returns (IJBProjects);

  function v1ProjectIdOf(uint256 _projectId) external view returns (uint256);

  function finalized(uint256 _projectId) external view returns (bool);

  function setV1ProjectId(uint256 _projectId, uint256 _v1ProjectId) external;

  function releaseV1TokensOf(uint256 _projectId, address _beneficiary) external;
}
