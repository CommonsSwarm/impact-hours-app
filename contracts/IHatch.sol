pragma solidity ^0.4.24;

import { ITokenManager as TokenManager } from "./ITokenManager.sol";


interface IHatch {
    function state() external view returns (uint8);
    function tokenManager() external view returns (TokenManager);
    function contributionToTokens(uint256 _value) external view returns (uint256);
    function totalRaised() external view returns (uint256);
    function close() external;
}
