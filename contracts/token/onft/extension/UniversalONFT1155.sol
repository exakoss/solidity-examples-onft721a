// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8;

import ".././ONFT1155.sol";

/// @title Interface of the UniversalONFT standard
contract UniversalONFT1155 is ONFT1155 {
    /// @notice Constructor for the UniversalONFT
    /// @param _uri the base uri of the token meta
    /// @param _layerZeroEndpoint handles message transmission across chains
    constructor(string memory _uri, address _layerZeroEndpoint) ONFT1155(_uri, _layerZeroEndpoint) {}

    // this is an example of a mint function, and should be used for demonstration purposes only
    function mint(uint256 _tokenId, uint256 _amount) external payable {
        _mint(msg.sender, _tokenId, _amount, bytes(""));
    }
}