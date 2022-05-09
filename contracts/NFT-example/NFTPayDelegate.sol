pragma solidity ^0.8.0;

//import "@manifoldxyz/creator-core-solidity/contracts/ERC721Creator.sol";
import '@jbx-protocol-v2/contracts/interfaces/IJBPayDelegate.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/utils/Counters.sol';

contract NFTRewards is ERC721URIStorage, IJBPayDelegate {
  error unAuth();

  address terminal;

  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  constructor(address _terminal) ERC721('NFTRewards', 'JBX-NFT') {
    terminal = _terminal;
  }

  function didPay(JBDidPayData calldata _param) public override {
    if (msg.sender != terminal) revert unAuth();

    _tokenIds.increment();

    uint256 newItemId = _tokenIds.current();
    _mint(_param.payer, newItemId);
    _setTokenURI(
      newItemId,
      'https://gateway.pinata.cloud/ipfs/QmXMLNsz7LNHA2JViLuUiCoGGVmnhnE3Vc76f2a5EtoGE6'
    );
  }
}
