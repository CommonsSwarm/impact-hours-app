pragma solidity ^0.4.24;

import "@aragon/os/contracts/apps/AragonApp.sol";
import "@aragon/os/contracts/lib/math/SafeMath.sol";
import "@aragon/minime/contracts/MiniMeToken.sol";
import { IHatch as Hatch } from "./IHatch.sol";


contract ImpactHours is AragonApp {
    using SafeMath for uint256;

    bytes32 public constant CLOSE_ROLE = keccak256("CLOSE_ROLE");
    uint8 private constant GOAL_REACHED = 3;

    MiniMeToken public token;
    Hatch public hatch;
    uint256 public maxRate;
    uint256 public expectedRaise;

    string private constant ERROR_HATCH_NOT_GOAL_REACHED = "IH_HATCH_NOT_GOAL_REACHED";
    string private constant ERROR_IMPACT_HOURS_NOT_FULLY_CLAIMED = "IH_NOT_FULLY_CLAIMED";

    /**
     * @notice Initialize Impact Hours app with the `_token.symbol(): string` impact hours token, for the hatch `_hatch`, and with a max rate of `_maxRate` and an expected raise of `_expectedRaise`
     * @dev We store a clone of the impact hours tokens that will be burn as soon as they are claimed
     * @param _token Impact hours token
     * @param _hatch Hatch to be closed
     * @param _maxRate Max rate limit per impact hour
     * @param _expectedRaise Expected raise, in which the rate is half the max rate
     */
    function initialize(MiniMeToken _token, address _hatch, uint256 _maxRate, uint256 _expectedRaise) external onlyInit {
        // We clone the IH token so we can burn it as soon as it is claimed
        token = _token.createCloneToken(_token.name(), _token.decimals(), _token.symbol(), 0, false);
        hatch = Hatch(_hatch);
        maxRate = _maxRate;
        expectedRaise = _expectedRaise;
        initialized();
    }

    /**
     * @notice Convert impact hour tokens into hatch tokens for multiple contributor addresses
     * @dev We calculate how much tokens must be minted with the reward formula, burn cloned impact hours token so they can not be claimed again
     * @param _contributors List of contributors 
     */
    function claimReward(address[] _contributors) external isInitialized {
        require(hatch.state() == GOAL_REACHED, ERROR_HATCH_NOT_GOAL_REACHED);
        for (uint256 i = 0; i < _contributors.length; i++) {
            uint256 _amount = reward(hatch.totalRaised(), _contributors[i]);
            token.destroyTokens(_contributors[i], token.balanceOf(_contributors[i]));
            require(token.balanceOf(_contributors[i]) == 0); // All claimed tokens should be burned
            hatch.tokenManager().mint(_contributors[i], _amount);
        }
    }

    /**
     * @notice Close hatch
     */
    function closeHatch() external auth(CLOSE_ROLE) {
        require(token.totalSupply() == 0, 'ERROR_IMPACT_HOURS_NOT_FULLY_CLAIMED');
        hatch.close();
    }

    /**
     * @dev Returns the amount of hatch tokens a contributor receives depending on the total raised by the hatch
     * @param _totalRaised Total raised by the hatch
     * @param _contributor Contributor with impact hours
     */
    function reward(uint256 _totalRaised, address _contributor) public view isInitialized returns (uint256) {
        if (_totalRaised == 0) {
            return 0;
        }
        return hatch.contributionToTokens(
            token.balanceOf(_contributor)
                .mul(maxRate)
                .div(10 ** uint256(token.decimals()))
                .mul(_totalRaised)
                .div(_totalRaised.add(expectedRaise))
        );
    }
}
