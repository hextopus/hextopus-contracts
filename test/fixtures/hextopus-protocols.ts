import { deployments } from "hardhat";
import { deployContract, encodeParams } from "../../shared/utils";

import BaseSocialActionABI from "../../artifacts/contracts/action/BaseSocialAction.sol/BaseSocialAction.json"
import BaseCampaignABI from "../../artifacts/contracts/campaign/BaseCampaign.sol/BaseCampaign.json"
import BaseLockupCampaignABI from "../../artifacts/contracts/campaign/BaseLockupCampaign.sol/BaseLockupCampaign.json"

export const hextopusProtocolFixture = deployments.createFixture(async hre => {
    const [deployer, user1, user2, user3, user4, user5] = await hre.ethers.getSigners();

    // Deploy
    const hxto = await deployContract("HXTO", ["HXTO", "HXTO"]);
    const esHXTO = await deployContract("esHXTO", ["esHXTO", "esHXTO"]);

    const staker = await deployContract("Staker", [hxto.address]);
    const vester = await deployContract("Vester", [esHXTO.address, hxto.address]);

    const capReader = await deployContract("CapReader", [esHXTO.address, hxto.address, staker.address]);
    const NFTCapReader = await deployContract("NFTCapReader", []);
    const campaignReader = await deployContract("CampaignReader", []);
    const NFTCampaignReader = await deployContract("NFTCampaignReader", []);

    const timelock = await deployContract("Timelock", [0]);

    const baseCampaign = await deployContract("BaseCampaign", []);
    const campaignFactory = await deployContract("CampaignFactory", [baseCampaign.address]);

    const baseLockupCampaign = await deployContract("BaseLockupCampaign", []);
    const lockupCampaignFactory = await deployContract("CampaignFactory", [baseLockupCampaign.address]);

    const baseSocialAction = await deployContract("BaseSocialAction", []);
    const socialActionFactory = await deployContract("SocialActionFactory", [baseSocialAction.address]);

    const baseNFT = await deployContract("BaseNFT", ["BaseNFT", "BaseNFT"]);
    const baseNFTCampaign = await deployContract("BaseNFTCampaign", []);
    const NFTCampaignFactory = await deployContract("NFTCampaignFactory", [baseNFTCampaign.address]);

    // Clone action encode
    const actionConfig = [
        { type: 'address', value: deployer.address }, // Owner
    ];

    const encodedActionConfig = encodeParams(actionConfig);

    // Clone action
    let tx = await socialActionFactory.clone(`0x${encodedActionConfig}`);
    let receipt = await tx.wait();
    let clonedAction = receipt.events[0].args[0];
    let socialAction = await hre.ethers.getContractAt(BaseSocialActionABI.abi, clonedAction);

    // Clone campaign encode
    const campaignConfig = [
        { type: 'address', value: hxto.address }, // rewardToken
        { type: 'address', value: clonedAction }, // action
        { type: 'address', value: deployer.address }, // owner
        { type: 'bool', value: false }, // isWhiteListCampaign
        { type: 'uint256', value: 0 }, // minimumRequirement
        { type: 'address', value: NFTCapReader.address }, // NFTCapReader
    ];
    const campaignTokenConfig = [
        { type: 'address', value: hxto.address }, // hxto
        { type: 'address', value: esHXTO.address }, // esHxto
        { type: 'address', value: vester.address }, // vester
        { type: 'address', value: staker.address }, // staker
        { type: 'address', value: capReader.address }, // capReader
        { type: 'address', value: user5.address }, // treasury
    ];

    const encodedCampaignConfig = encodeParams(campaignConfig);
    const encodedCampaignTokenConfig = encodeParams(campaignTokenConfig);

    // Clone campaign
    tx = await campaignFactory.clone(`0x${encodedCampaignConfig}`, `0x${encodedCampaignTokenConfig}`);
    receipt = await tx.wait();
    let clonedCampaign = receipt.events[0].args[0];
    let campaign = await hre.ethers.getContractAt(BaseCampaignABI.abi, clonedCampaign);

    // Token setter
    tx = await esHXTO.setMinter(vester.address, true);
    await tx.wait();

    tx = await esHXTO.setHandler(vester.address, true);
    await tx.wait();

    tx = await esHXTO.setMinter(campaign.address, true);
    await tx.wait();

    tx = await esHXTO.setHandler(campaign.address, true);
    await tx.wait();

    tx = await hxto.setHandler(campaign.address, true);
    await tx.wait();

    tx = await hxto.setHandler(vester.address, true);
    await tx.wait();

    tx = await vester.setActiveCampaign(campaign.address, true);
    await tx.wait();

    // Util setter
    // 7 days
    tx = await staker.setStakePeriod(1, 604800);
    await tx.wait();

    // 30 days
    tx = await staker.setStakePeriod(2, 2592000);
    await tx.wait();

    tx = // 90 days
        await staker.setStakePeriod(3, 7776000);
    await tx.wait();

    // esHxto
    tx = await capReader.setStakeAdditionalCap(0, 5000);
    await tx.wait();

    // 7 days stake
    tx = await capReader.setStakeAdditionalCap(1, 1000);
    await tx.wait();

    // 30 days stake
    tx = await capReader.setStakeAdditionalCap(2, 5000);
    await tx.wait();

    // 90 days stake
    tx = await capReader.setStakeAdditionalCap(3, 16000);
    await tx.wait();

    // Reader setter
    tx = await campaignReader.addCampaign(campaign.address);
    await tx.wait();

    tx = await campaignReader.setCapReader(capReader.address);
    await tx.wait();

    tx = await campaignReader.setStaker(staker.address);
    await tx.wait();

    // Action setter
    tx = await socialAction.setCampaign(clonedCampaign);
    await tx.wait();

    // Campaign setter
    tx = await campaign.setGov(timelock.address);
    await tx.wait();

    /*
    --------------NFT Campaign--------------
    */

    // Clone NFT action
    tx = await socialActionFactory.clone(`0x${encodedActionConfig}`);
    receipt = await tx.wait();
    clonedAction = receipt.events[0].args[0];
    let NFTSocialAction = await hre.ethers.getContractAt(BaseSocialActionABI.abi, clonedAction);

    // Clone NFT camapaign encode
    const NFTCampaignConfig = [
        { type: 'address', value: baseNFT.address }, // rewardNFT
        { type: 'address', value: clonedAction }, // action
        { type: 'address', value: deployer.address }, // owner
        { type: 'bool', value: false }, // isWhiteListCampaign
        { type: 'uint256', value: 0 }, // minimumRequirement
        { type: 'address', value: NFTCapReader.address }, // NFTCampaignReader

    ];
    const NFTCampaignTokenConfig = [
        { type: 'address', value: hxto.address }, // hxto
        { type: 'address', value: esHXTO.address }, // esHxto
        { type: 'address', value: vester.address }, // vester
        { type: 'address', value: staker.address }, // staker
        { type: 'address', value: capReader.address }, // capReader
        { type: 'address', value: user5.address }, // treasury
    ];

    const encodedNFTCampaignConfig = encodeParams(NFTCampaignConfig);
    const encodedNFTCampaignTokenConfig = encodeParams(NFTCampaignTokenConfig);

    // Clone NFT campaign
    tx = await NFTCampaignFactory.clone(`0x${encodedNFTCampaignConfig}`, `0x${encodedNFTCampaignTokenConfig}`);
    receipt = await tx.wait();
    let clonedNFTCampaign = receipt.events[0].args[0];
    let NFTCampaign = await hre.ethers.getContractAt(BaseCampaignABI.abi, clonedNFTCampaign);

    // NFT setter
    tx = await baseNFT.addMinter(NFTCampaign.address);
    await tx.wait();

    tx = await baseNFT.addMinter(deployer.address);
    await tx.wait();

    tx = await baseNFT.setURI("https://www.hextopus.app/ipfs/Qmc1expD7te1rybMgVHpyj4PwEMqUcosjbHo6w82QNz9PT");
    await tx.wait();

    tx = await baseNFT.setTransferable(false);
    await tx.wait();

    // NFT cap reader setter
    tx = await NFTCapReader.setNFTUtil(baseNFT.address, 3);
    await tx.wait();

    // NFT campaign token setter
    tx = await esHXTO.setMinter(NFTCampaign.address, true);
    await tx.wait();

    tx = await esHXTO.setHandler(NFTCampaign.address, true);
    await tx.wait();

    tx = await hxto.setHandler(NFTCampaign.address, true);
    await tx.wait();

    tx = await vester.setActiveCampaign(NFTCampaign.address, true);
    await tx.wait();

    // NFT campaign reader setter
    tx = await NFTCampaignReader.addCampaign(NFTCampaign.address);
    await tx.wait();

    tx = await NFTCampaignReader.setCapReader(capReader.address);
    await tx.wait();

    tx = await NFTCampaignReader.setStaker(staker.address);
    await tx.wait();

    // Action setter
    tx = await NFTSocialAction.setCampaign(NFTCampaign.address);
    await tx.wait();

    // NFT campaign setter
    tx = await NFTCampaign.setGov(timelock.address);
    await tx.wait();

    /*
    --------------Lockup Campaign--------------
    */

    // Clone lockup action
    tx = await socialActionFactory.clone(`0x${encodedActionConfig}`);
    receipt = await tx.wait();
    clonedAction = receipt.events[0].args[0];
    let lockupCampaignSocialAction = await hre.ethers.getContractAt(BaseSocialActionABI.abi, clonedAction);

    // Clone lockup camapaign encode
    const lockupCampaignConfig = [
        { type: 'address', value: hxto.address }, // reward token
        { type: 'address', value: clonedAction }, // action
        { type: 'address', value: deployer.address }, // owner
        { type: 'bool', value: false }, // isWhiteListCampaign
        { type: 'uint256', value: 0 }, // minimumRequirement
        { type: 'address', value: NFTCapReader.address }, // NFTCampaignReader

    ];
    const lockupCampaignTokenConfig = [
        { type: 'address', value: hxto.address }, // hxto
        { type: 'address', value: esHXTO.address }, // esHxto
        { type: 'address', value: vester.address }, // vester
        { type: 'address', value: staker.address }, // staker
        { type: 'address', value: capReader.address }, // capReader
        { type: 'address', value: user5.address }, // treasury
    ];

    const encodedLockupCampaignConfig = encodeParams(lockupCampaignConfig);
    const encodedLockupCampaignTokenConfig = encodeParams(lockupCampaignTokenConfig);

    // Clone lockup campaign
    tx = await lockupCampaignFactory.clone(`0x${encodedLockupCampaignConfig}`, `0x${encodedLockupCampaignTokenConfig}`);
    receipt = await tx.wait();
    let clonedLockupCampaign = receipt.events[0].args[0];
    let lockupCampaign = await hre.ethers.getContractAt(BaseLockupCampaignABI.abi, clonedLockupCampaign);

    // Token setter
    tx = await esHXTO.setMinter(lockupCampaign.address, true);
    await tx.wait();

    tx = await esHXTO.setHandler(lockupCampaign.address, true);
    await tx.wait();

    tx = await hxto.setHandler(lockupCampaign.address, true);
    await tx.wait();

    tx = await vester.setActiveCampaign(lockupCampaign.address, true);
    await tx.wait();

    // Reader setter
    tx = await campaignReader.addCampaign(lockupCampaign.address);
    await tx.wait();

    // Action setter
    tx = await lockupCampaignSocialAction.setCampaign(lockupCampaign.address);
    await tx.wait();

    // Campaign setter
    tx = await lockupCampaign.setGov(timelock.address);
    await tx.wait();

    return {
        hxto,
        esHXTO,
        campaignReader,
        NFTCampaignReader,
        capReader,
        NFTCapReader,
        staker,
        vester,
        timelock,
        campaign,
        socialAction,
        NFTCampaign,
        NFTSocialAction,
        lockupCampaign,
        lockupCampaignSocialAction,
        baseCampaign,
        campaignFactory,
        baseSocialAction,
        socialActionFactory,
        baseNFT,
    }
})