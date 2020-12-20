pragma solidity ^0.4.24;


interface ITokenManager {
    function mint(address _receiver, uint256 _amount) external;
}
