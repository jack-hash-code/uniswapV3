pragma solidity ^0.8.14;

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV3MintCallback.sol";
import "./interfaces/IUniswapV3SwapCallback.sol";

import "./lib/Tick.sol";
import "./lib/Position.sol";

contract UniswapV3Pool {
    //using...for 将某个库的函数扩展到特定数据类型上。这使得你可以像调用类型的方法一样，直接调用库中的函数，从而提高代码的可读性和可维护性
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    error InvalidTickRange();
    error ZeroLuquidity();
    error InsufficientInputAmount();

    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    //跟踪两个代币地址 地址将是静态的，在池子部署期间一次性设置（因此，它们将是不可变的）
    address public immutable token0;
    address public immutable token1;

    //流动性L
    uint128 public liquidity;

    //维护一个 tick 注册表 ，其中键是 tick 索引，值是存储 tick 信息的结构体。
    mapping(int24 => Tick.Info) public ticks;

    //键是唯一的头寸标识符，值是存储头寸信息的结构体。
    mapping(bytes32 => Position.Info) public positions;

    //跟踪当前价格与相应的tick，这些变量是一起读取与写入的
    struct Slot0 {
        //当前 sqrt(p)
        uint160 sqrtPriceX96;
        //当前的tick
        int24 tick;
    }
    Slot0 public slot0;

    struct CallbackData {
        address token0;
        address token1;
        address payer;
    }

    event Mint(
        address sender,
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    constructor(
        address token0_,
        address token1_,
        uint160 sqrtPriceX96,
        int24 tick
    ) {
        token0 = token0_;
        token1 = token1_;
        slot0 = Slot0({sqrtPriceX96: sqrtPriceX96, tick: tick});
    }

    //amount 是L的数量
    //流程：用户指定一个价格范围和流动性数量； 合约更新 ticks 和 positions 映射； 合约计算用户必须发送的代币数量（我们将预先计算并硬编码它们）； 合约从用户那里获取代币并验证是否设置了正确的数量。
    function mint(
        address owner,
        int24 lowerTick,
        int24 upperTick,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1) {
        if (
            lowerTick >= upperTick ||
            lowerTick < MIN_TICK ||
            upperTick > MAX_TICK
        ) revert InvalidTickRange();
        if (0 == amount) revert ZeroLuquidity();

        ticks.update(lowerTick, amount);
        ticks.update(upperTick, amount);

        Position.Info storage position = positions.get(
            owner,
            lowerTick,
            upperTick
        );
        position.update(amount);

        amount0 = 0.998976618347425280 ether;
        amount1 = 5000 ether;

        liquidity += uint128(amount);

        uint256 balance0before;
        uint256 balance1before;

        if (amount0 > 0) balance0before = balance0();
        if (amount1 > 0) balance1before = balance1();

        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(
            amount0,
            amount1,
            data
        );

        if (amount0 > 0 && balance0before + amount0 > balance0())
            revert InsufficientInputAmount();

        if (amount1 > 0 && balance1before + amount1 > balance1())
            revert InsufficientInputAmount();

        emit Mint(
            msg.sender,
            owner,
            lowerTick,
            upperTick,
            amount,
            amount0,
            amount1
        );
    }

    //recipient 代币的接收者
    //返回在交换中使用的代币数量(可以是正数/负数)
    function swap(
        address recipient,
        bytes calldata data
    ) public returns (int256 amount0, int256 amount1) {
        // 用 42 USDC 购买 ETH

        //1.找到目标价格和tick
        //2.计算代币数量
        int24 nextTick = 85184;
        uint160 nextPrice = 5604469350942327889444743441197;

        amount0 = -0.008396714242162444 ether;
        amount1 = 42 ether;

        //3.更新当前的tick和sqrtP
        (slot0.tick, slot0.sqrtPriceX96) = (nextTick, nextPrice);

        //4.合约将代币发送给接收者
        IERC20(token0).transfer(recipient, uint256(-amount0));
        //5.调用者将输入金额转入合约
        uint256 balance1Before = balance1();
        IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(
            amount0,
            amount1,
            data
        );

        if (balance1Before + uint256(amount1) < balance1())
            revert InsufficientInputAmount();

        emit Swap(
            msg.sender,
            recipient,
            amount0,
            amount1,
            slot0.sqrtPriceX96,
            liquidity,
            slot0.tick
        );
    }

    function balance0() internal returns (uint256 balance) {
        balance = IERC20(token0).balanceOf(address(this));
    }

    function balance1() internal returns (uint256 balance) {
        balance = IERC20(token1).balanceOf(address(this));
    }
}
