// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ITrustedMintable} from "./../SuperToken/ITrustedMintable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";

interface IGoldLite is ITrustedMintable, ISuperToken {
	// @dev: set Trusted minter
	// @param: _trusted: address of trusted minter
	// @param: _isTrusted: set trusted minter state
	function setTrusted(address _trusted, bool _isTrusted) external;

	// @dev: Check is address is trusted minter
	// @param: _trusted: address of trusted minter
	// @return: bool: is trusted minter
   	function isTrusted(address _trusted) external returns(bool);
}
