pragma solidity ^0.8.14;

//在交换代币时调用
interface IUniswapV3SwapCallback {
    function uniswapV3SwapCallback(
        int256 amount0,
        int256 amount1,
        bytes calldata data
    ) external;
}
