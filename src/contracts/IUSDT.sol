pragma solidity >=0.5.16;

interface IUSDT {
    function approve(address _spender, uint256 _value) external;

    function balanceOf(address who) external view returns (uint256);
}
