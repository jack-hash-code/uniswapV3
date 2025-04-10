pragma solidity ^0.8.14;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../src/UniswapV3Pool.sol";
import "../src/UniswapV3Manager.sol";
import "../test/ERC20Mintable.sol";

/*
forge script script/DeployDevelopment.s.sol --broadcast --fork-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80  --code-size-limit 50000 
*/

//本质上，部署合约意味着：
// 将源代码编译成 EVM 字节码。
// 发送一个包含字节码的交易。
// 创建一个新地址，执行字节码的构造函数部分，并在该地址上存储部署的字节码。当您的合约创建交易被挖矿时，以太坊节点会自动完成这一步。
// 部署通常包括多个步骤：准备参数、部署辅助合约、部署主合约、初始化合约等。脚本可以帮助自动化这些步骤，我们将用 Solidity 编写脚本！
contract DeployDevelopmentScript is Script {
    function setUp() public {}

    function run() public {
        uint256 wethBalance = 1 ether;
        uint256 usdcBalance = 5042 ether; //其中 5000 USDC 将作为流动性提供给资金池，42 USDC 将在交换中出售。
        int24 currentTick = 85176;
        uint160 currentSqrtP = 5602277097478614198912276234240;

        //在 broadcast() 作弊码之后或 startBroadcast()/stopBroadcast() 之间的所有内容都会被转换为交易，这些交易会被发送到执行脚本的节点。
        vm.startBroadcast();

        //部署代币
        ERC20Mintable token0 = new ERC20Mintable("Wrapped Ether", "WETH", 18);
        ERC20Mintable token1 = new ERC20Mintable("USD Coin", "USDC", 18);

        //部署资金池合约
        UniswapV3Pool pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            currentSqrtP,
            currentTick
        );

        //Manager 合约的部署
        UniswapV3Manager manager = new UniswapV3Manager();

        //为我们的地址铸造一些 ETH 和 USDC
        //在 Foundry 脚本中，msg.sender 是在 broadcast 块内发送交易的地址。我们在运行脚本时可以设置它
        token0.mint(msg.sender, wethBalance);
        token1.mint(msg.sender, usdcBalance);

        vm.stopBroadcast();

        console.log("WETH address", address(token0));
        console.log("USDC address", address(token1));
        console.log("Pool address", address(pool));
        console.log("Manager address", address(manager));
    }
}
