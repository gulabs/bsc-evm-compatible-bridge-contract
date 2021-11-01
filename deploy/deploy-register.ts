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

  console.log(`>> Deploying MockERC721`);

  const mockERC721 = await MockERC721.deploy('Mock721', 'M721');

  console.log(">> MockERC721 is deployed!");
  console.log("MockERC721 address", mockERC721.address);
  const tokenId = 1;
  const tokenURI = "https://www.google.com"
  fs.writeFileSync(deployedFilePath, JSON.stringify({
    ...deployed,
    tokenAddr: mockERC721.address,
    tokenId,
    tokenURI,
  }));

  await mockERC721.safeMint(signers[0].address, tokenId);
  console.log(">> Minted MockERC721 to the deployer");

  await mockERC721.setTokenURI(tokenId, tokenURI);
  console.log(">> Set MockERC721 tokenURI");

  await mockERC721.approve(agentAddr, 1);
  console.log(">> Approved MockERC721 to SwapAgent from the deployer");

  const ERC721SwapAgent = (await ethers.getContractFactory("ERC721SwapAgent", signers[0])) as ERC721SwapAgent__factory;
  const agent = await ERC721SwapAgent.attach(agentAddr);

  await agent.registerSwapPair(mockERC721.address, dstChainId);
  console.log(">> Registered!!")
}

func.tags = ["MockERC721"];

export default func;
