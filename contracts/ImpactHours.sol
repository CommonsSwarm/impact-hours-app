pragma solidity ^0.4.24;

import "@aragon/os/contracts/apps/AragonApp.sol";
import "@aragon/os/contracts/acl/IACLOracle.sol";
import "@aragon/os/contracts/lib/math/SafeMath.sol";
import { IHatch as Hatch } from "./IHatch.sol";


contract ImpactHours is AragonApp, IACLOracle {
    using SafeMath for uint256;

    bytes32 public constant ADD_IMPACT_HOURS_ROLE = keccak256("ADD_IMPACT_HOURS_ROLE");
    uint8 private constant GOAL_REACHED = 3; // Position 3 in Hatch's state enum

    bool finalized = false;
    mapping(address => uint256) impactHours;
    uint256 totalImpactHours = 0;
    uint256 claimedImpactHours = 0;
    Hatch hatch;
    uint256 maxRate;
    uint256 expectedRaisePerIH;

    string private constant ERROR_ALREADY_FINALIZED            = "IH_ALREADY_FINALIZED";
    string private constant ERROR_CONTRIBUTORS_HOURS_MISMATCH  = "IH_CONTRIBUTORS_HOURS_MISMATCH";
    string private constant ERROR_NOT_FINALIZED_YET            = "IH_NOT_FINALIZED_YET";
    string private constant ERROR_HATCH_NOT_GOAL_REACHED       = "IH_HATCH_NOT_GOAL_REACHED";

    function initialize(address _hatch, uint256 _maxRate, uint256 _expectedRaisePerIH) external onlyInit {
        hatch = Hatch(_hatch);
        maxRate = _maxRate;
        expectedRaisePerIH = _expectedRaisePerIH;
    }

    function addImpactHours(address[] _contributors, uint256[] _hours, bool _last) external auth(ADD_IMPACT_HOURS_ROLE) {
        require(!finalized, ERROR_ALREADY_FINALIZED);
        require(_contributors.length == _hours.length, ERROR_CONTRIBUTORS_HOURS_MISMATCH);
        for (uint256 i = 0; i < _contributors.length; i++) {
            impactHours[_contributors[i]] = _hours[i];
            totalImpactHours = totalImpactHours.add(_hours[i]);
        }
        // We won't allow adding more hours if `_last` is true
        finalized = _last;
    }

    function claimReward(address[] _contributors) external isInitialized {
        require(finalized, ERROR_NOT_FINALIZED_YET);
        require(hatch.state() == GOAL_REACHED, ERROR_HATCH_NOT_GOAL_REACHED);
        for (uint256 i = 0; i < _contributors.length; i++) {
            uint256 _amount = hatch.contributionToTokens(reward(hatch.totalRaised(), _contributors[i]));
            claimedImpactHours = claimedImpactHours.add(impactHours[_contributors[i]]);
            impactHours[_contributors[i]] = 0;
            hatch.tokenManager().mint(_contributors[i], _amount);
        }
    }

    function canPerform(address, address, bytes32, uint256[]) external view isInitialized returns (bool) {
        return finalized && claimedImpactHours == totalImpactHours;
    }

    function reward(uint256 totalRaised, address contributor) public view isInitialized returns (uint256) {
        return impactHours[contributor].mul(maxRate).mul(totalRaised).div(totalRaised.add(expectedRaisePerIH.mul(totalImpactHours)));
    }
}
