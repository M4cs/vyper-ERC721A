# @version ^0.3.4

interface IERC721A:

    @external
    def totalSupply() -> uint256: view

    @external
    def supportsInterface(interfaceId: bytes4) -> bool: view

    @external
    def balanceOf(owner: address) -> uint256: view

    @external
    def ownerOf(tokenId: uint256) -> address: view

    @external
    def approve(to: address, tokenId: uint256): nonpayable

    @external
    def setApprovalForAll(operator: address, approved: bool): nonpayable

    @external
    def getApproved(tokenId: uint256) -> address: view

    @external
    def isApprovedForAll(owner: address, operator: address) -> bool: view

    @external
    def name() -> String[32]: view

    @external
    def symbol() -> String[8]: view

    @external
    def tokenURI(tokenId: uint256) -> String[256]: view

    @external
    def safeTransferFrom(
        _from: address,
        to: address,
        tokenId: uint256
    ): nonpayable
    @external
    def transferFrom(
        _from: address,
        to: address,
        tokenId: uint256
    ): nonpayable
