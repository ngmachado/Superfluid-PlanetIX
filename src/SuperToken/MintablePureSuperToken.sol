// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {SuperTokenBase} from "./base/SuperTokenBase.sol";

import {ITrustedMintable} from "./ITrustedMintable.sol";

/// @title Minimal Pure Super Token
/// @author jtriley.eth changed by shinra-corp.eth
/// @notice No pre-minted supply.
contract MintablePureSuperToken is SuperTokenBase, ITrustedMintable, Ownable {

    mapping(address => bool) private s_trustedAddresses;

    //Modifiers
    modifier onlyTrusted() {
        if (!s_trustedAddresses[msg.sender]) revert ITrustedMintable.TM__NotTrusted(msg.sender);
        _;
    }
    
	/// @dev Upgrades the super token with the factory, then initializes.
    /// @param factory super token factory for initialization
	/// @param name super token name
	/// @param symbol super token symbol
    function initialize(
        address factory,
        string memory name,
        string memory symbol,
        address owner
    ) external {
        _initialize(factory, name, symbol);
        transferOwnership(owner);
        s_trustedAddresses[owner] = true;
    }

    /**
    * @notice Used to mint tokens by trusted contracts
     * @param _to Recipient of newly minted tokens
     * @param _amount Number of tokens to mint
     *
     * Throws TM_NotTrusted on caller not being trusted
     */
    function trustedMint(
        address _to,
        uint256, //_tokenId,
        uint256 _amount
    ) external onlyTrusted override {
        _mint(_to, _amount, "");
    }

    /**
	 * @notice Used to mint tokens by trusted contracts
     * @param _to Recipient of newly minted tokens
     * @param _tokenIds Ids of newly minted tokens MUST be ignored on ERC-721
     * @param _amounts Number of tokens to mint
     *
     * Throws TM_NotTrusted on caller not being trusted
     */
    function trustedBatchMint(
        address _to,
        uint256[] calldata _tokenIds,
        uint256[] calldata _amounts
    ) external onlyTrusted override {

    }

    /**
     * @notice Used to set trusted minter
     * @param _trusted Address of trusted minter
     * @param _isTrusted set trusted or not
     *
     * Throws NotOwner on caller not being owner of the contract
     */
    function setTrusted(address _trusted, bool _isTrusted) external onlyOwner {
        s_trustedAddresses[_trusted] = _isTrusted;
    }

    /**
     * @notice Used to check if trusted is registered
     * @param _trusted Address of trusted minter
     * @return true if trusted is registered
     */
    function isTrusted(address _trusted) external view returns (bool) {
        return s_trustedAddresses[_trusted];
    }
}
