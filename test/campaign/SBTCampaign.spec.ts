import hre from 'hardhat';
import { expect, use } from 'chai';
import { solidity } from 'ethereum-waffle';
import { expandDecimals } from "../../shared/utils";
import { hextopusProtocolFixture } from '../fixtures/hextopus-protocols';

use(solidity);

describe("Campaign", async () => {
    let deployer;
    let user1;
    let user2;
    let user3;
    let user4;

    let hxto;
    let esHXTO;
    let staker;
    let NFTCampaignReader;
    let timelock;
    let NFTCampaign;
    let baseNFT;
    let NFTSocialAction;
    let NFTCapReader;

    const defaultLinkBytes = "0x44454641554c5400000000000000000000000000000000000000000000000000";

    before(async () => {
        [deployer, user1, user2, user3, user4] = await hre.ethers.getSigners();

        ({ hxto, esHXTO, staker, NFTCampaignReader, timelock, baseNFT, NFTSocialAction, NFTCampaign, NFTCapReader } = await hextopusProtocolFixture());

        // Campaign setting
        await timelock.setCampaignManager(NFTCampaign.address, deployer.address, true);
        await timelock.setCampaignManager(NFTCampaign.address, user1.address, true);

        await timelock.signalSetBeforeNFTAddRewards(NFTCampaign.address, BigInt(100 * Math.pow(10, 18)).toString(), 2, 1, 4);
        await timelock.connect(user1).signSetBeforeNFTAddRewards(NFTCampaign.address, BigInt(100 * Math.pow(10, 18)).toString(), 2, 1, 4);
        await timelock.connect(user1).setBeforeNFTAddRewards(NFTCampaign.address, BigInt(100 * Math.pow(10, 18)).toString(), 2, 1, 4);

        // Token mint & add rewards
        await hxto.setMinter(deployer.address, true);
        await hxto.mint(deployer.address, expandDecimals(1000, 18));
        await NFTCampaign.addRewards();
    })

    it('should revert if not verified yet', async () => {
        await expect(NFTCampaign.participate(hre.ethers.constants.AddressZero, deployer.address, defaultLinkBytes, hre.ethers.constants.AddressZero)).to.be.revertedWith('BaseSocialAction: Not verified yet');
    })

    it("calls participate by root user", async () => {
        await NFTSocialAction.setFulfilled(deployer.address);

        await NFTCampaign.participate(hre.ethers.constants.AddressZero, deployer.address, defaultLinkBytes, hre.ethers.constants.AddressZero);

        // Root user info check
        const rootUserInfo = await NFTCampaign.userInfo(deployer.address);
        expect(rootUserInfo.link).to.equal(defaultLinkBytes);
        expect(rootUserInfo.referral).to.equal(hre.ethers.constants.AddressZero);

        // Claimed participation reward check
        expect((await baseNFT.balanceOf(deployer.address)).toString()).to.equal("1");
    });

    it("calls participate by direct referral user", async () => {
        const beforePoolHxtoAmount = await NFTCampaign.hxtoPoolAmount();
        await NFTSocialAction.setFulfilled(user1.address);

        await NFTCampaign.participate(deployer.address, user1.address, defaultLinkBytes, hre.ethers.constants.AddressZero);

        const afterPoolHxtoAmount = await NFTCampaign.hxtoPoolAmount();

        // Root user info check
        const rootUserInfo = await NFTCampaign.userInfo(deployer.address);
        expect(rootUserInfo.referralHxtoAmount.toString()).to.equal((await NFTCampaign.directReferralHxtoAmount()).toString());

        // Referral user info check
        const referralUserInfo = await NFTCampaign.userInfo(user1.address);
        expect(referralUserInfo.link).to.equal(defaultLinkBytes);
        expect(referralUserInfo.referral).to.equal(deployer.address);

        // Remain referral reward check
        expect((BigInt(beforePoolHxtoAmount)- BigInt(afterPoolHxtoAmount)).toString()).to.equal((await NFTCampaign.directReferralHxtoAmount()).toString());
    });

    it("calls participate by indirect referral user", async () => {
        const beforePoolHxtoAmount = await NFTCampaign.hxtoPoolAmount();
        await NFTSocialAction.setFulfilled(user2.address);

        await NFTCampaign.participate(user1.address, user2.address, defaultLinkBytes, hre.ethers.constants.AddressZero);

        const afterPoolHxtoAmount = await NFTCampaign.hxtoPoolAmount();

        // Root user info check
        const rootUserInfo = await NFTCampaign.userInfo(deployer.address);
        expect(rootUserInfo.referralHxtoAmount.toString()).to.equal((BigInt(await NFTCampaign.directReferralHxtoAmount()) + BigInt(await NFTCampaign.indirectReferralHxtoAmount())).toString());

        // Direct referral user info check
        const referralUserInfo = await NFTCampaign.userInfo(user1.address);
        expect(referralUserInfo.referralHxtoAmount).to.equal(await NFTCampaign.directReferralHxtoAmount());

        // Indirect referral user info check
        const indirectReferralUserInfo = await NFTCampaign.userInfo(user2.address);
        expect(indirectReferralUserInfo.link).to.equal(defaultLinkBytes);
        expect(indirectReferralUserInfo.referral).to.equal(user1.address);

        // Remain referral reward check
        expect((BigInt(beforePoolHxtoAmount) - BigInt(afterPoolHxtoAmount)).toString()).to.equal((BigInt(await NFTCampaign.directReferralHxtoAmount()) + BigInt(await NFTCampaign.indirectReferralHxtoAmount())).toString());
    });

    it("checks root user's claim amount", async () => {
        await NFTCapReader.editNFTUtil(0, 0);

        await NFTSocialAction.setFulfilled(user3.address);

        await NFTCampaign.participate(deployer.address, user3.address, defaultLinkBytes, hre.ethers.constants.AddressZero);
        
        await NFTCampaign.claim(deployer.address);
        
        // Root user info check
        const rootUserInfo = await NFTCampaign.userInfo(deployer.address);
        console.log("rootUserInfo.referralHxtoAmount.toString()", rootUserInfo.referralHxtoAmount.toString());

        expect(rootUserInfo.referralHxtoAmount.toString()).to.equal((BigInt(await NFTCampaign.directReferralHxtoAmount()) * BigInt(2) + BigInt(await NFTCampaign.indirectReferralHxtoAmount())).toString());
        expect(rootUserInfo.referralHxtoDebt.toString()).to.equal((BigInt(await NFTCampaign.directReferralHxtoAmount()) * BigInt(2)).toString());

        expect(BigInt(await esHXTO.balanceOf(deployer.address)).toString()).to.equal((BigInt(await NFTCampaign.directReferralHxtoAmount()) * BigInt(2)).toString());
    });

    it("checks root user's claim amount with NFT", async () => {
        await NFTCapReader.editNFTUtil(0, 3);

        await NFTCampaign.claim(deployer.address);

        // Root user info check
        const rootUserInfo = await NFTCampaign.userInfo(deployer.address);

        expect(rootUserInfo.referralHxtoAmount.toString()).to.equal((BigInt(await NFTCampaign.directReferralHxtoAmount()) * BigInt(2) + BigInt(await campaign.indirectReferralHxtoAmount())).toString());
        expect(rootUserInfo.referralHxtoDebt.toString()).to.equal((BigInt(await NFTCampaign.directReferralHxtoAmount()) * BigInt(2) + BigInt(await campaign.indirectReferralHxtoAmount())).toString());

        expect(BigInt(await esHXTO.balanceOf(deployer.address)).toString()).to.equal((BigInt(await NFTCampaign.directReferralHxtoAmount()) * BigInt(2) + BigInt(await campaign.indirectReferralHxtoAmount())).toString());
    });

    it("checks root user's additional cap by staking", async () => {
        await NFTCapReader.editNFTUtil(0, 0);

        await NFTSocialAction.setFulfilled(user4.address);

        await NFTCampaign.participate(deployer.address, user4.address, defaultLinkBytes, hre.ethers.constants.AddressZero);

        let requiredAmount = (await NFTCampaignReader.getHxtoRequirement(deployer.address, "0")).toString();
        
        await NFTCampaign.claim(deployer.address);
        await hxto.approve(staker.address, requiredAmount);
        await staker.stake(requiredAmount, 3);

        requiredAmount = (await NFTCampaignReader.getHxtoRequirement(deployer.address, "0")).toString();

        expect(requiredAmount).to.equal("0");

        await NFTCampaign.claim(deployer.address);

        // Root user info check
        const rootUserInfo = await NFTCampaign.userInfo(deployer.address);

        expect(rootUserInfo.referralHxtoAmount.toString()).to.equal((BigInt(await NFTCampaign.directReferralHxtoAmount()) * BigInt(2) + BigInt(await NFTCampaign.indirectReferralHxtoAmount())).toString());
        expect(rootUserInfo.referralHxtoDebt.toString()).to.equal(rootUserInfo.referralHxtoAmount.toString());
    });

    it("checks BaseNFT is not transferable", async () => {
        await expect(baseNFT.transferFrom(deployer.address, user1.address, "1")).to.be.revertedWith('BaseNFT: must transferable');
    })
})