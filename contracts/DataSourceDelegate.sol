// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol-v2/contracts/interfaces/IJBFundingCycleDataSource.sol';
import '@jbx-protocol-v2/contracts/interfaces/IJBPayDelegate.sol';
import '@jbx-protocol-v2/contracts/interfaces/IJBRedemptionDelegate.sol';

contract DataSourceDelegate is IJBFundingCycleDataSource, IJBPayDelegate, IJBRedemptionDelegate {
  function payParams(JBPayParamsData calldata _data)
    external
    view
    override
    returns (
      uint256 weight,
      string memory memo,
      IJBPayDelegate delegate
    )
  {
    return (0, _data.memo, IJBPayDelegate(address(this)));
  }

  function redeemParams(JBRedeemParamsData calldata)
    external
    view
    override
    returns (
      uint256 reclaimAmount,
      string memory memo,
      IJBRedemptionDelegate delegate
    )
  {
    return (0, '', IJBRedemptionDelegate(address(this)));
  }

  function didPay(JBDidPayData calldata _data) external override {}

  function didRedeem(JBDidRedeemData calldata _data) external override {}

  function supportsInterface(bytes4 _interfaceId) external pure override returns (bool) {
    return
      _interfaceId == type(IJBFundingCycleDataSource).interfaceId ||
      _interfaceId == type(IJBPayDelegate).interfaceId ||
      _interfaceId == type(IJBRedemptionDelegate).interfaceId;
  }
}
