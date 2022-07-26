pragma solidity ^0.5.16;

interface Feed {
    function decimals() external view returns (uint8);

    function latestAnswer() external view returns (uint256);
}

/*
 * Mock oracle feed for local testing
 */
contract OracleFeed is Feed {
    uint8 private _decimals;
    uint256 private _answer;

    constructor(uint8 decimals_, uint256 initialAnswer) public {
        _decimals = decimals_;
        _answer = initialAnswer;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function submitAnswer(uint256 answer) public {
        _answer = answer;
    }

    /*
     * @dev for simplicity sake
     */
    function latestAnswer() external view returns (uint256) {
        return _answer;
    }
}
