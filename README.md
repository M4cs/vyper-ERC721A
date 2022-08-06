# ERC721A - Vyper Implementation

I was bored and couldn't find an ERC721A specific implementation written in Vyper. I decided to translate it from Solidity over into Vyper. This should implement everything apart from the extraData from ERC721A... maybe even better? I hear Vyper is pretty efficient on gas, haven't done any testing yet.

Feel free to contribute. This is just a starting point, I basically just picked up Vyper to write this so I'm sure it's awful to any Vyper OGs.

The language is cool though, definitely enjoyed writing a contract basically using Python.

## What's Available Out of the Box?

This Vyper implementation offers a (mostly) 1:1 rewrite of ERC721A. I decided to not include `_safeTransferFrom` because it's not really necessary and just spends more gas. The contract itself includes an internal `_burn` and `_mint` function, and the functionality you'd expect from `transferFrom`. There is no `_beforeTokenTransfers` or `_afterTokenTransfers` because those are also pretty useless and if you want to do that, just edit the functionality in the Vyper contract.

Vyper doesn't support virtual or overridable functions so instead you will just have to edit whatever functions you'd normally override.

There is also a basic implementation of `toString()` included which allows you to convert uint256 tokenIds to strings.

Any contribution is most welcome. Hope this helps somebody! Plan to update with more contracts as I learn Vyper.

## To Compile:

Install Vyper:
```
pip3 install vyper
```

Compile Bytecode and export ABI:
```
# To get Bytecode:
vyper ./contracts/ERC721A.vy

# To get ABI:
vyper -f abi ./contracts/ERC721A.vy
```
