// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8;

import "../ONFT721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

/// @title Interface of the AdvancedONFT721 standard
contract AdvancedONFT721 is ERC721Enumerable, ONFT721,Ownable  {
    using Strings for uint256;
    // the limit number that can mint everytime
    uint256 public constant MAX_TOKENS_PER_MINT = 5;
    //Token price
    uint256 internal _price = 0;
    // ** Address for withdrawing money, separate from owner
    address payable beneficiary;
    // address for receiving royalties and royalty fee in basis points (i.e. 100% = 10000, 1% = 100)
    address royaltyReceiver;
    uint256 royaltyBasisPoints = 500;

    uint gasForDestinationLzReceive = 350000;

    string private baseURI;
    string private uriSuffix = ".json";
    string private hiddenMetadataUri;

    mapping(address => uint256) public _allowList;

    bool public _publicSaleStarted;
    bool public _saleStarted;
    bool revealed;

    modifier whenSaleStarted() {
        require(_saleStarted, "Sale not started");
        _;
    }

    uint public nextMintId;
    uint public maxMintId;

    /// @notice Constructor for the AdvancedONFT721
    /// @param _name the name of the token
    /// @param _symbol the token symbol
    /// @param _layerZeroEndpoint handles message transmission across chains
    /// @param _startMintId the starting mint number on this chain
    /// @param _endMintId the max number of mints on this chain
    constructor(string memory _name, string memory _symbol, address _layerZeroEndpoint, uint _startMintId, uint _endMintId) ONFT721(_name, _symbol, _layerZeroEndpoint) {
        nextMintId = _startMintId;
        maxMintId = _endMintId;
        beneficiary = payable(msg.sender);
        royaltyReceiver = msg.sender;
        baseURI = baseURI_;
        hiddenMetadataUri = "https://gateway.pinata.cloud/ipfs/QmdKa2BDar2Gws866ENUgXojmKXBSdyNm4KKfWHsRE4hrv";
    }

    /// @notice Mint your ONFT (WL mint)
    function mint(uint256 _nbTokens) whenSaleStarted external payable {
        require(_nbTokens != 0, "Cannot mint 0 tokens!");
        require(_nbTokens <= MAX_TOKENS_PER_MINT, "You cannot mint more than MAX_TOKENS_PER_MINT tokens at once!");
        require(nextMintId + _nbTokens <= maxMintId, "AdvancedONFT721: max mint limit reached");
        require(_nbTokens * _price <= msg.value, "Inconsistent amount sent!");
        require(_allowList[msg.sender] >= _nbTokens, "You exceeded the token limit.");

        _allowList[msg.sender] -= _nbTokens;

        uint256 local_nextTokenId = nextTokenId;
        for (uint256 i; i < _nbTokens; i++) {
            _safeMint(msg.sender, ++local_nextTokenId);
        }
        nextTokenId = local_nextTokenId;
    }
    /// @notice Public mint
    function publicMint(uint256 _nbTokens) whenSaleStarted external payable  {
        require(_publicSaleStarted == true, "Public sale has not started yet!");
        require(_nbTokens != 0, "Cannot mint 0 tokens!");
        require(_nbTokens <= MAX_TOKENS_PER_MINT, "You cannot mint more than MAX_TOKENS_PER_MINT tokens at once!");
        require(nextTokenId + _nbTokens <= maxMintId, "Not enough Tokens left.");
        require(_nbTokens * _price <= msg.value, "Inconsistent amount sent!");

        uint256 local_nextTokenId = nextTokenId;
        for (uint256 i; i < _nbTokens; i++) {
            _safeMint(msg.sender, ++local_nextTokenId);
        }
        nextTokenId = local_nextTokenId;
    }

    /// @notice calculate the gas fee to send NFT to another chain
    function estimateFeesSendNFT(uint16 _chainId, uint _id) public view returns (uint fees) {
        require(trustedRemoteLookup[_chainId].length > 0, "This chain is currently unavailable for transfer");
        // abi.encode() the payload with the values to send
        bytes memory payload = abi.encode(msg.sender, _id);
        //abi encode a higher gas limit to pass to tx parameters
        bytes memory parameters = abi.encodePacked(uint16(1),gasForDestinationLzReceive);
        (uint nativeFee, ) = estimateSendFee(_chainId, address(this), payload, false, parameters);
        return nativeFee;
    }

    // send NFTs to another chain.    
    // this function sends NFTs from your address to the same address on the destination.
    function sendNFT(address _from, uint16 _chainId, bytes memory _toAddress, uint _id) public payable {
        require(_isApprovedOrOwner(msg.sender, _id), "You need to approve or be owner of the token to send your NFTs!");
        require(trustedRemoteLookup[_chainId].length > 0, "This chain is currently unavailable for transfer");

        // abi.encode() the payload with the values to send
        bytes memory payload = abi.encode(msg.sender, _id);
        //abi encode a higher gas limit to pass to tx parameters
        bytes memory parameters = abi.encodePacked(uint16(1),gasForDestinationLzReceive);

        (uint nativeFee, ) = estimateSendFee(_chainId, address(this), payload, false, parameters);
        require(msg.value >= nativeFee, "Not enough for a cross-chain fee!");

        sendFrom(_from, _chainId,_toAddress,_id, payable(msg.sender),address(0x0),parameters)
    }

    // just in case this fixed variable limits us from future integrations
    function setGasForDestinationLzReceive(uint newGas) external onlyOwner {
        gasForDestinationLzReceive = newGas;
    }

    function withdraw() public virtual onlyOwner {
        require(beneficiary != address(0), "Beneficiary not set");

        uint256 _balance = address(this).balance;

        require(payable(beneficiary).send(_balance));
    }

    function flipSaleStarted() external onlyOwner {
        _saleStarted = !_saleStarted;
    }

    function flipPublicSaleStarted() external onlyOwner {
        _publicSaleStarted = !_publicSaleStarted;
    }
    
    function royaltyInfo(uint256, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount) {
        receiver = royaltyReceiver;
        royaltyAmount = salePrice * royaltyBasisPoints / 10000;
    }

    function setRoyaltyFee(uint256 _royaltyBasisPoints) external onlyOwner {
        royaltyBasisPoints = _royaltyBasisPoints;
    }

    function setRoyaltyReceiver(address _receiver) external onlyOwner {
        royaltyReceiver = _receiver;
    } 

    function setAllowList(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            _allowList[addresses[i]] = MAX_TOKENS_PER_MINT;
        }
    }

    function setBeneficiary(address payable _beneficiary) public virtual onlyOwner {
        beneficiary = _beneficiary;
    }

    function setHiddenMetadataUri(string memory _hiddenMetadataUri) external onlyOwner {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    function flipRevealed() external onlyOwner {
        revealed = !revealed;
    }

    function setPrice(uint256 newPrice) external onlyOwner {
        _price = newPrice;
    }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721) {
        super._burn(tokenId);
    }
    
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function contractURI() public view returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string calldata uri) public onlyOwner {
        baseURI = uri;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721)
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (revealed == false) {
            return hiddenMetadataUri;
        }
        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0
            ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), uriSuffix))
            : "";
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }


}
