pragma solidity >=0.5.16;

import "./SafeMath.sol";

interface IFeed {
    function latestAnswer() external view returns (uint256);

    function decimals() external view returns (uint256);
}

contract TestingEthOracle is IFeed {
    using SafeMath for uint256;

    function latestAnswer() public view returns (uint256) {
        return 100 * 10**18;
    }

    function decimals() public view returns (uint256) {
        return 18;
    }
}
