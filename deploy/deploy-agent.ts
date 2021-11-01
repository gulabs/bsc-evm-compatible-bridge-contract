import path from 'path';
import fs from 'fs';
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, upgrades } from "hardhat";
import { ERC721SwapAgent, ERC721SwapAgent__factory } from "../typechain";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const ERC721SwapAgent = (await ethers.getContractFactory("ERC721SwapAgent", (await ethers.getSigners())[0])) as ERC721SwapAgent__factory

  console.log(`>> Deploying ERC721SwapAgent`);

  const agent = (await upgrades.deployProxy(ERC721SwapAgent)) as ERC721SwapAgent;

  console.log(">> ERC721SwapAgent is deployed!");
  console.log("ERC721SwapAgent address", agent.address);

  const deployedFilePath = path.join(__dirname, `../chains/${hre.network.config.chainId}/deployed.json`);
  fs.writeFileSync(deployedFilePath, JSON.stringify({
    agentAddress: agent.address,
  }));
}

func.tags = ["ERC721SwapAgent"];

export default func;
