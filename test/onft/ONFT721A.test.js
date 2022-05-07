const { expect } = require("chai")
const { ethers } = require("hardhat")

describe("ONFT721A: ", function () {
    const chainIdSrc = 1
    const chainIdDst = 2
    const name = "OmnichainNonFungibleTokenA"
    const symbol = "ONFTA"

    let owner, lzEndpointSrcMock, lzEndpointDstMock, ONFTSrc, ONFTDst, LZEndpointMock, ONFTA

    before(async function () {
        owner = (await ethers.getSigners())[0]

        LZEndpointMock = await ethers.getContractFactory("LZEndpointMock")
        ONFTA = await ethers.getContractFactory("ONFT721A")
    })

    beforeEach(async function () {
        lzEndpointSrcMock = await LZEndpointMock.deploy(chainIdSrc)
        lzEndpointDstMock = await LZEndpointMock.deploy(chainIdDst)

        // create two ONFT instances
        ONFTASrc = await ONFTA.deploy(name, symbol, lzEndpointSrcMock.address)
        ONFTADst = await ONFTA.deploy(name, symbol, lzEndpointDstMock.address)

        lzEndpointSrcMock.setDestLzEndpoint(ONFTADst.address, lzEndpointDstMock.address)
        lzEndpointDstMock.setDestLzEndpoint(ONFTASrc.address, lzEndpointSrcMock.address)

        // set each contracts source address so it can send to each other
        await ONFTASrc.setTrustedRemote(chainIdDst, ONFTADst.address) // for A, set B
        await ONFTADst.setTrustedRemote(chainIdSrc, ONFTASrc.address) // for B, set A
    })

    it("mints multiple pieces", async function () {
        await ONFTASrc.mint(5)
        balance0 = await ONFTASrc.balanceOf(owner.address)
        expect(balance0).to.equal(5)
    })

    it("mints multiple pieces and sends one to dest chain", async function () {
      //mint a few pieces and grab the id of the first one (_startTokenId defaults to 0)
      await ONFTASrc.mint(5)
      const newId = 0
      // verify the owner of the token is on the source chain
      expect(await ONFTASrc.ownerOf(newId)).to.be.equal(owner.address)
      // approve ONFT
      await ONFTASrc.approve(ONFTASrc.address, newId)
      // v1 adapterParams, encoded for version 1 style, and 300k gas quote
      const adapterParam = ethers.utils.solidityPack(["uint16", "uint256"], [1, 300000])
      // send ONFTA
      await ONFTASrc.sendFrom(owner.address, chainIdDst, owner.address, newId, owner.address, "0x000000000000000000000000000000000000dEaD", adapterParam)
      
      // verify the owner of the token is on the destination chain
      // expect(await ONFTADst.ownerOf(newId)).to.be.equal(owner.address)
      balancedst = await ONFTADst.balanceOf(owner.address)
      expect(balancedst).to.equal(1)
      // verify that the owner on the srcChain still has the rest of the tokens
      balance0 = await ONFTASrc.balanceOf(owner.address)
      expect(balance0).to.equal(4)
  })
})