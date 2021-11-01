import fs from 'fs';
import path from 'path';
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { MockERC721__factory, ERC721SwapAgent__factory } from "../typechain";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  if (!process.env.DST_CHAIN_ID) {
    throw new Error("no DST_CHAIN_ID");
  }
  const dstChainId = parseInt(process.env.DST_CHAIN_ID, 10);
  const deployedFilePath = path.join(__dirname, `../chains/${hre.network.config.chainId}/deployed.json`);
  const deployed = JSON.parse(fs.readFileSync(deployedFilePath).toString());
  const agentAddr = deployed.agentAddress;

  const signers = await ethers.getSigners();

  const MockERC721 = (await ethers.getContractFactory("MockERC721", signers[0])) as MockERC721__factory
  const mockERC721 = await MockERC721.attach(deployed.tokenAddr);

  const ERC721SwapAgent = (await ethers.getContractFactory("ERC721SwapAgent", signers[0])) as ERC721SwapAgent__factory;
  const agent = await ERC721SwapAgent.attach(agentAddr);

  await agent.swap(mockERC721.address, signers[0].address, deployed.tokenId, dstChainId);
  console.log(">> Forward Swap!!");
}

func.tags = ["ForwardSwapERC721"];

export default func;
