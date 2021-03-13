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
    uint256 public expectedRaisePerIH;
    uint256 public totalIH;

    string private constant ERROR_HATCH_NOT_GOAL_REACHED = "IH_HATCH_NOT_GOAL_REACHED";
    string private constant ERROR_IMPACT_HOURS_NOT_FULLY_CLAIMED = "IH_NOT_FULLY_CLAIMED";

    function initialize(MiniMeToken _token, address _hatch, uint256 _maxRate, uint256 _expectedRaisePerIH) external onlyInit {
        // We clone the IH token so we can burn it as soon as it is claimed
        token = _token.createCloneToken(_token.name(), _token.decimals(), _token.symbol(), 0, false);
        hatch = Hatch(_hatch);
        maxRate = _maxRate;
        expectedRaisePerIH = _expectedRaisePerIH;
        totalIH = token.totalSupply(); // We store a local copy of total amount of IH, because total supply will decrease as IH are claimed
        initialized();
    }

    function claimReward(address[] _contributors) external isInitialized {
        require(hatch.state() == GOAL_REACHED, ERROR_HATCH_NOT_GOAL_REACHED);
        for (uint256 i = 0; i < _contributors.length; i++) {
            uint256 _amount = hatch.contributionToTokens(reward(hatch.totalRaised(), _contributors[i]));
            token.destroyTokens(_contributors[i], token.balanceOf(_contributors[i]));
            require(token.balanceOf(_contributors[i]) == 0); // All claimed tokens should be burned
            hatch.tokenManager().mint(_contributors[i], _amount);
        }
    }

    function closeHatch() external auth(CLOSE_ROLE) {
        require(token.totalSupply() == 0, 'ERROR_IMPACT_HOURS_NOT_FULLY_CLAIMED');
        hatch.close();
    }

    function reward(uint256 totalRaised, address contributor) public view isInitialized returns (uint256) {
        if (totalRaised == 0) {
            return 0;
        }
        return token.balanceOf(contributor).mul(maxRate).mul(totalRaised).div(totalRaised.add(expectedRaisePerIH.mul(totalIH)));
    }
}
