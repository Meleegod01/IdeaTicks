import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const FactoryModule = buildModule("FactoryModule", (m) => {
  // Replace with your actual EventFactory contract name and constructor params if any
  const eventFactory = m.contract("EventFactory", [10n, 10n]);

  return { eventFactory };
});

export default FactoryModule;
