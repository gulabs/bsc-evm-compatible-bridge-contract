import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { deployMockERC721 } from './utils/721-deploy';
import { get721Agent, set721MockToken } from './utils/721-cache';

const BASE_URI = 'https://creatures-api.opensea.io/api/box/';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const baseUri = process.env.BASE_URI === 'true' ? BASE_URI : '';
  const signers = await ethers.getSigners();
  const chainId = hre.network.config.chainId?.toString() || '';
  const cache = get721Agent(chainId);
  const mockToken = await deployMockERC721({
    baseUri,
    signers,
    agentAddr: cache.address,
  });

  set721MockToken(chainId, {
    address: mockToken.address,
    baseUri,
    symbol: await mockToken.symbol(),
    name: await mockToken.name(),
    tokenId: '',
  });
}

func.tags = ["ERC721MockToken"];

export default func;
