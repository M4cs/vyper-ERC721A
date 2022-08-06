# @version ^0.3.4

from .interfaces.IERC721A import IERC721A

implements: IERC721A

struct TokenOwnership:
    addr: address
    startTimestamp: uint64
    burned: bool

struct TokenApprovalRef:
    value: address

event Transfer:
    _from: indexed(address)
    to: indexed(address)
    tokenId: indexed(uint256)

event Approval:
    owner: indexed(address)
    approved: indexed(address)
    tokenId: indexed(uint256)

event ApprovalForAll:
    owner: indexed(address)
    operator: indexed(address)
    approved: bool

event ConsecutiveTransfer:
    fromTokenId: indexed(uint256)
    toTokenId: uint256
    _from: indexed(address)
    to: indexed(address)

_BITMASK_ADDRESS_DATA_ENTRY: constant(uint256) = shift(1, 64) - 1
_BITPOS_NUMBER_MINTED: constant(uint256) = 64
_BITPOS_NUMBER_BURNED: constant(uint256) = 128
_BITPOS_AUX: constant(uint256) = 192
_BITMASK_AUX_COMPLEMENT: constant(uint256) = shift(1, 192) - 1
_BITPOS_START_TIMESTAMP: constant(uint256) = 160
_BITMASK_BURNED: constant(uint256) = shift(1, 224)
_BITPOS_NEXT_INITIALIZED: constant(uint256) = 225
_BITMASK_NEXT_INITIALIZED: constant(uint256) = shift(1, 225)
_BITPOS_EXTRA_DATA: constant(uint256) = 232
_BITMASK_EXTRA_DATA_COMPLEMENT: constant(uint256) = shift(1, 232) - 1
_BITMASK_ADDRESS: constant(uint256) = shift(1, 160) - 1
_MAX_MINT_ERC2309_QUANITTY_LIMIT: constant(uint256) = 5000

_TRANSFER_EVENT_SIGNATURE: constant(bytes32) = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef

_HIGH_INT: constant(uint256) = 100 ** 18

_currentIndex: uint256
_burnCounter: uint256
_name: String[32]
_symbol: String[8]
_baseURI: String[100]

_packedOwnerships: HashMap[uint256, uint256]

_packedAddressData: HashMap[address, uint256]

_tokenApprovals: HashMap[uint256, TokenApprovalRef]

_operatorApprovals: HashMap[address, HashMap[address, bool]]

@external
def __init__(
    name_: String[32],
    symbol_: String[8],
    baseURI_: String[100]
):
    self._name = name_
    self._symbol = symbol_
    self._baseURI = baseURI_
    self._currentIndex = self._startTokenId()

@external
def mint(quantity: uint256):
    self._mint(msg.sender, quantity)

@view
@external
def totalSupply() -> uint256:
    return self._currentIndex - self._burnCounter - self._startTokenId()

@view
@external
def balanceOf(owner: address) -> uint256:
    if (owner == empty(address)): raise "Cannot query ZeroAddress' balance"
    return self._packedAddressData[owner] & _BITMASK_ADDRESS_DATA_ENTRY

@view
@external
def supportsInterface(interfaceId: bytes4) -> bool:
    return interfaceId == 0x01ffc9a7 or interfaceId == 0x80ac58cd or interfaceId == 0x5b5e139f

@view
@external
def name() -> String[32]:
    return self._name

@view
@external
def symbol() -> String[8]:
    return self._symbol

@view
@external
def tokenURI(tokenId: uint256) -> String[110]:
    if not self._exists(tokenId): raise "URI Query for Non-existent token!"
    return concat(self._baseURI, self._tokenIdToString(tokenId))

@view
@external
def ownerOf(tokenId: uint256) -> address:
    return convert(convert(self._packedOwnershipOf(tokenId), uint160), address)

@external
def transferFrom(
    _from: address,
    to: address,
    tokenId: uint256
):
    prevOwnershipPacked: uint256 = self._packedOwnershipOf(tokenId)
    if (convert(convert(prevOwnershipPacked, uint160), address) != _from): raise "Transfer Request from Incorrect Owner!"

    approvedAddress: address = self._getApprovedAddress(tokenId)

    if not self._isSenderApprovedOrOwner(approvedAddress, _from, msg.sender): 
        if not self._isApprovedForAll(_from, msg.sender):
            raise "Transfer Caller Not Owner or Approved"

    if (to == empty(address)): raise "Transfer to Zero Address. Use burn()."

    self._tokenApprovals[tokenId] = empty(TokenApprovalRef)

    self._packedAddressData[_from] -= 1
    self._packedAddressData[to] += 1

    self._packedOwnerships[tokenId] = self._packOwnershipData(
        to,
        _BITMASK_NEXT_INITIALIZED
    )

    if (prevOwnershipPacked & _BITMASK_NEXT_INITIALIZED == 0):
        nextTokenId: uint256 = tokenId + 1
        if self._packedOwnerships[nextTokenId] == 0:
            if nextTokenId != self._currentIndex:
                self._packedOwnerships[nextTokenId] = prevOwnershipPacked

    log Transfer(_from, to, tokenId)

@internal
def _mint(to: address, quantity: uint256):
    startTokenId: uint256 = self._currentIndex
    if (quantity == 0): raise "Minting Zero Quantity"

    self._packedAddressData[to] += quantity * (shift(1, _BITPOS_NUMBER_MINTED) | 1)

    self._packedOwnerships[startTokenId] = self._packOwnershipData(
        to,
        self._nextInitializedFlag(quantity)
    )

    log Transfer(empty(address), to, startTokenId)

    end: uint256 = startTokenId + quantity

    for i in range(_HIGH_INT):
        if (startTokenId + i) > end:
            break
        log Transfer(empty(address), to, startTokenId+i)

    if (to == empty(address)): raise "Cannot Mint to Zero Address!"

    self._currentIndex = end

@internal
def _burn(tokenId: uint256, approvalCheck: bool):
    prevOwnershipPacked: uint256 = self._packedOwnershipOf(tokenId)

    _from: address = convert(convert(prevOwnershipPacked, uint160), address)

    approvedAddress: address = self._getApprovedAddress(tokenId)

    if approvalCheck:
        if not (self._isSenderApprovedOrOwner(approvedAddress, _from, msg.sender)):
            if not (self._isApprovedForAll(_from, msg.sender)): raise "Transfer Caller Not Owner or Approved!"
    
    self._tokenApprovals[tokenId] = empty(TokenApprovalRef)

    packed: uint256 = self._packedAddressData[_from]
    packed -= 1
    packed += shift(1, _BITPOS_NUMBER_BURNED)
    self._packedAddressData[_from] = packed

    self._packedOwnerships[tokenId] = self._packOwnershipData(
        _from,
        (_BITMASK_BURNED | _BITMASK_NEXT_INITIALIZED)
    )

    if (prevOwnershipPacked & _BITMASK_NEXT_INITIALIZED == 0):
        nextTokenId: uint256 = tokenId + 1

        if self._packedOwnerships[nextTokenId] == 0:
            if nextTokenId != self._currentIndex:
                self._packedOwnerships[nextTokenId] = prevOwnershipPacked
    
    log Transfer(_from, empty(address), tokenId)

    self._burnCounter += 1

@view
@external
def getApproved(tokenId: uint256) -> address:
    if not self._exists(tokenId): raise 'Approval Query for Non-Existent Token!'

    return self._tokenApprovals[tokenId].value


@external
def setApprovalForAll(operator: address, approved: bool):
    if (operator == msg.sender): raise "Cannot Approve Yourself"

    self._operatorApprovals[msg.sender][operator] = approved
    log ApprovalForAll(msg.sender, operator, approved)

@view
@external
def isApprovedForAll(owner: address, operator: address) -> bool:
    return self._operatorApprovals[owner][operator]

@view
@internal
def _isApprovedForAll(owner: address, operator: address) -> bool:
    return self._operatorApprovals[owner][operator]

@view
@internal
def _numberMinted(owner: address) -> uint256:
    return shift((self._packedAddressData[owner]), -(_BITPOS_NUMBER_MINTED)) & _BITMASK_ADDRESS_DATA_ENTRY

@view
@internal
def _numberBurned(owner: address) -> uint256:
    return shift((self._packedAddressData[owner]), -(_BITPOS_NUMBER_BURNED)) & _BITMASK_ADDRESS_DATA_ENTRY

@view
@internal
def _getAux(owner: address) -> uint64:
    return convert(shift(self._packedAddressData[owner], -(_BITPOS_AUX)), uint64)

@internal
def _setAux(owner: address, aux: uint64):
    packed: uint256 = self._packedAddressData[owner]
    auxCasted: uint256 = convert(aux, uint256)
    packed = (packed & _BITMASK_AUX_COMPLEMENT) | shift(auxCasted, convert(_BITPOS_AUX, int256))
    self._packedAddressData[owner] = packed

@view
@internal
def _ownershipOf(tokenId: uint256) -> TokenOwnership:
    return self._unpackedOwnership(self._packedOwnershipOf(tokenId))

@view
@internal
def _ownershipAt(index: uint256) -> TokenOwnership:
    return self._unpackedOwnership(self._packedOwnerships[index])

@internal
def _initializeOwnershipAt(index: uint256):
    if (self._packedOwnerships[index] == 0): self._packedOwnerships[index] = self._packedOwnershipOf(index)

@pure
@internal
def _unpackedOwnership(packed: uint256) -> TokenOwnership:
    return TokenOwnership({
        addr: convert(convert(packed, uint160), address),
        startTimestamp: convert(shift(packed, -(_BITPOS_START_TIMESTAMP)), uint64),
        burned: packed & _BITMASK_BURNED != 0,
    })

@view
@internal
def _packedOwnershipOf(tokenId: uint256) -> uint256:
    curr: uint256 = tokenId
    if self._startTokenId() <= curr:
        if curr <= self._currentIndex:
            packed: uint256 = self._packedOwnerships[curr]
            if (packed & _BITMASK_BURNED == 0):
                for i in range(_HIGH_INT):
                    if packed != 0:
                        return packed
                    packed = self._packedOwnerships[curr]
                    curr -= 1
    raise "Query for Non-Existent Token!"

@view
@internal
def _packOwnershipData(owner: address, flags: uint256) -> uint256:
    _owner: uint160 = convert(owner, uint160) & convert(_BITMASK_ADDRESS, uint160)
    return convert(owner, uint256) | (shift(block.timestamp, convert(_BITPOS_START_TIMESTAMP, int256))) | flags

@view
@internal
def _nextInitializedFlag(quantity: uint256) -> uint256:
    return shift(convert(quantity == 1, uint256), -(_BITPOS_NEXT_INITIALIZED))

@view
@internal
def _startTokenId() -> uint256:
    return 0

@view
@internal
def _nextTokenId() -> uint256:
    return self._currentIndex

@view
@internal
def _totalMinted() -> uint256:
    return self._currentIndex - self._startTokenId()

@view
@internal
def _totalBurned() -> uint256:
    return self._burnCounter

@view
@internal
def _exists(tokenId: uint256) -> bool:
    return self._startTokenId() <= tokenId and tokenId < self._currentIndex and self._packedOwnerships[tokenId] & _BITMASK_BURNED == 0

@pure
@internal
def _isSenderApprovedOrOwner(
    approvedAddress: address,
    owner: address,
    msgSender: address
) -> bool:
    _owner: uint160 = convert(owner, uint160) & convert(_BITMASK_ADDRESS, uint160)
    _msgSender: uint160 = convert(msgSender, uint160) & convert(_BITMASK_ADDRESS, uint160)
    return convert(convert(_msgSender == _owner, uint256) | convert(_msgSender == convert(approvedAddress, uint160), uint256), bool)

@view
@internal
def _getApprovedAddress(tokenId: uint256) -> address:
    tokenApproval: TokenApprovalRef = self._tokenApprovals[tokenId]
    approvedAddress: address = tokenApproval.value
    return approvedAddress

@pure                                            
@internal                                                         
def _digitToString(digit: uint256) -> String[1]:
    assert digit < 10  # only works with digits 0-9                           
    digit_bytes32: bytes32 = convert(digit + 48, bytes32)  # ASCII `0` is 0x30 (48 in decimal)
    digit_bytes1: Bytes[1] = slice(digit_bytes32, 31, 1)  # Remove padding bytes
    return convert(digit_bytes1, String[1])

@view             
@internal                                     
def _tokenIdToString(tokenId: uint256) -> String[4]:
    # NOTE: Only handles up to 4 digits, e.g. tokenId in [0, 9999]
    digit1: uint256 = tokenId % 10                  
    digit2: uint256 = (tokenId % 100) / 10                        
    digit3: uint256 = (tokenId % 1000) / 100
    digit4: uint256 = tokenId / 1000               
                                                        
    return concat(                                              
        self._digitToString(digit1),
        self._digitToString(digit2),                   
        self._digitToString(digit3),
        self._digitToString(digit4),
    )                               
