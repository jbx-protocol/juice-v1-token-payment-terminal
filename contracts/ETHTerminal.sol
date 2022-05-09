// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol-v2/contracts/interfaces/IJBPaymentTerminal.sol';
import '@jbx-protocol-v2/contracts/interfaces/IJBRedemptionTerminal.sol';
import '@jbx-protocol-v2/contracts/libraries/JBCurrency.sol';
import '@jbx-protocol-v2/contracts/libraries/JBToken.sol';

contract ETHTerminal is IJBPaymentTerminal, IJBRedemptionTerminal {
  function acceptsToken(address _token, uint256 _projectId) external view override returns (bool) {
    projectId;

    return _tokan == JBToken.ETH;
  }

  function currencyForToken(address _token) external view override returns (uint256) {
    _token;
    return JBCurrency.ETH;
  }

  function decimalsForToken(address _token) external view override returns (uint256) {
    _token;
    return 18;
  }

  // Return value must be a fixed point number with 18 decimals.
  function currentEthOverflowOf(uint256 _projectId) external view override returns (uint256) {
    return 0;
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
    // Do somethings when paid.
  }

  function addToBalanceOf(
    uint256 _projectId,
    uint256 _amount,
    address _token,
    string calldata _memo,
    bytes calldata _metadata
  ) external payable override {
    // Do something when tokens are added to balance.
  }

  function redeemTokensOf(
    address _holder,
    uint256 _projectId,
    uint256 _count,
    address _token,
    uint256 _minReturnedTokens,
    address payable _beneficiary,
    string calldata _memo,
    bytes calldata _metadata
  ) external override returns (uint256 reclaimAmount) {
    // Do something on redeem.
  }

  function supportsInterface(bytes4 _interfaceId) external pure override returns (bool) {
    return
      _interfaceId == type(IJBPaymentTerminal).interfaceId ||
      _interfaceId == type(IJBRedemptionTerminal).interfaceId;
  }
}
