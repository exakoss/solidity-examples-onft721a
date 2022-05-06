// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ONFT721Core.sol";
import "erc721a/contracts/ERC721A.sol";

contract ONFT721A is ONFT721Core, ERC721A {

    constructor(string memory _name, string memory _symbol, address _lzEndpoint) ERC721A(_name, _symbol) ONFT721Core(_lzEndpoint) {}
    

    function mint(uint256 quantity) external payable {
        // _safeMint's second argument now takes in a quantity, not a tokenId.
        _safeMint(msg.sender, quantity);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ONFT721Core, ERC721A) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _debitFrom(address _from, uint16, bytes memory, uint _tokenId) internal virtual override {
        bool isApprovedOrOwner = (_msgSender() == _from ||
            isApprovedForAll(_from, _msgSender()) ||
            getApproved(_tokenId) == _msgSender());

        require(isApprovedOrOwner, "ONFT721A: send caller is not owner nor approved");
        require(ERC721A.ownerOf(_tokenId) == _from, "ONFT721A: send from incorrect owner");
        _burn(_tokenId);
    }

    function _creditTo(uint16, address _toAddress, uint _tokenId) internal virtual override {
        require(_toAddress != address(0), "ERC721A: mint to the zero address");
        require(!_exists(_tokenId), "ERC721A: token already minted");

        _beforeTokenTransfers(address(0), _toAddress, _tokenId, 1);

        _ownerships[_tokenId].addr = _toAddress;
        _ownerships[_tokenId].startTimestamp = uint64(block.timestamp);
        // Can't update the _addressData because it is private
        // _addressData[_toAddress].balance += 1;

        emit Transfer(address(0), _toAddress, _tokenId);

        _afterTokenTransfers(address(0), _toAddress, _tokenId, 1);
    }
}