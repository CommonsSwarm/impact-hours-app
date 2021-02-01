pragma solidity 0.4.24;

import "@aragon/os/contracts/apps/AragonApp.sol";
import "@aragon/minime/contracts/MiniMeToken.sol";


contract TokenManagerMock is AragonApp {
    MiniMeToken public token;

    bytes32 public constant MINT_ROLE = keccak256("MINT_ROLE");

    string private constant ERROR_TOKEN_CONTROLLER = "TM_TOKEN_CONTROLLER";
    string private constant ERROR_MINT_RECEIVER_IS_TM = "TM_MINT_RECEIVER_IS_TM";

    function initialize(MiniMeToken _token) external onlyInit {
        require(_token.controller() == address(this), ERROR_TOKEN_CONTROLLER);
        token = _token;
        initialized();
    }

    function mint(address _receiver, uint256 _amount) external authP(MINT_ROLE, arr(_receiver, _amount)) {
        require(_receiver != address(this), ERROR_MINT_RECEIVER_IS_TM);
        token.generateTokens(_receiver, _amount); // minime.generateTokens() never returns false
    }
}