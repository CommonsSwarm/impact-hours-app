pragma solidity 0.4.24;

import "@aragon/os/contracts/apps/AragonApp.sol";
import "@aragon/os/contracts/lib/token/ERC20.sol";
import "@aragon/os/contracts/lib/math/SafeMath.sol";
import {TokenManagerMock as TokenManager} from  "./TokenManagerMock.sol";


contract HatchMock is AragonApp {

    using SafeMath for uint256;

    bytes32 public constant CLOSE_ROLE = keccak256("CLOSE_ROLE");

    enum State {
        Pending,     // hatch is idle and pending to be started
        Funding,     // hatch has started and contributors can purchase tokens
        Refunding,   // hatch has not reached min goal within period and contributors can claim refunds
        GoalReached, // hatch has reached min goal within period and trading is ready to be open
        Closed       // hatch has reached min goal within period, has been closed and trading has been open
    }
    State private internalState = State.Pending;

    TokenManager public tokenManager;
    ERC20 public token;
    uint256 public exchangeRate;
    uint32 public constant PPM = 1000000;
    uint256 public totalRaised = 1000000 * 10 ^ 18;

    event Close();

    function initialize(TokenManager _tokenManager, uint256 _exchangeRate) external onlyInit {
        token = ERC20(_tokenManager.token());
        exchangeRate = _exchangeRate;
        tokenManager = _tokenManager;
        initialized();
    }

    function contribute(uint256 _amount) external {
        totalRaised = totalRaised.add(_amount);
    }

    function setState(State _state) external isInitialized {
        internalState = _state;
    }


    function close() external auth(CLOSE_ROLE) {
        internalState = State.Closed;
        emit Close();
    }

    function state() public view isInitialized returns (State) {
        return internalState;
    }

    function contributionToTokens(uint256 _value) public view isInitialized returns (uint256) {
        return _value.mul(exchangeRate).div(PPM);
    }
}