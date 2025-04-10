pragma solidity ^0.8.14;

library Tick {
    struct Info {
        bool Initialized;
        uint128 liquidity;
    }

    function update(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        uint128 liquidityDelta
    ) internal {
        Tick.Info storage info = self[tick];
        uint128 liquidityBefore = info.liquidity;
        uint128 liquidityAfter = liquidityBefore + liquidityDelta;

        if (liquidityBefore == 0) {
            info.Initialized = true;
        }
        info.liquidity = liquidityAfter;
    }
}
