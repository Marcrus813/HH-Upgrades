const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

const { boxModule } = require("ProxyModule");

const upgradeModule = buildModule("UpgradeModule", (m) => {
    const proxyAdminOwner = m.getAccount(0);

    const { proxyAdmin, proxy } = m.useModule(boxModule);

    const boxV2 = m.contract("BoxV2");

    const encodedFunctionCall = m.encodeFunctionCall(boxV2, "increment");

    m.call(proxyAdmin, "upgradeAndCall", [proxy, boxV2, encodedFunctionCall], {
        from: proxyAdminOwner,
    });

    return { proxyAdmin, proxy };
});

const boxV2Module = buildModule("BoxV2Module", (m) => {
    const { proxy } = m.useModule(upgradeModule);

    const box = m.contractAt("BoxV2", proxy);

    return { box };
});

module.exports = boxV2Module;
