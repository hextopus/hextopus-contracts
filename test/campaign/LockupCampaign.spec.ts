import hre from 'hardhat';
import { expect, use } from 'chai';
import { solidity } from 'ethereum-waffle';
import { expandDecimals, increaseTime, mineBlock } from "../../shared/utils";
import { hextopusProtocolFixture } from '../fixtures/hextopus-protocols';

use(solidity);

describe("Campaign", async () => {
    let deployer;
    let user1;
    let user2;
    let user3;
    let user5;

    let hxto;
    let esHXTO;
    let timelock;
    let lockupCampaignSocialAction;
    let lockupCampaign;

    const defaultLinkBytes = "0x44454641554c5400000000000000000000000000000000000000000000000000";

    before(async () => {
        [deployer, user1, user2, user3, , user5] = await hre.ethers.getSigners();

        ({ hxto, esHXTO, timelock, lockupCampaignSocialAction, lockupCampaign } = await hextopusProtocolFixture());

        // Campaign setting
        await timelock.setCampaignManager(lockupCampaign.address, deployer.address, true);
        await timelock.setCampaignManager(lockupCampaign.address, user1.address, true);

        await timelock.signalSetBeforeAddRewards(lockupCampaign.address, expandDecimals(10000, 18), expandDecimals(15000, 18), 3, 1, 1000, 1000);
        await timelock.connect(user1).signSetBeforeAddRewards(lockupCampaign.address, expandDecimals(10000, 18), expandDecimals(15000, 18), 3, 1, 1000, 1000);
        await timelock.connect(user1).setBeforeAddRewards(lockupCampaign.address, expandDecimals(10000, 18), expandDecimals(15000, 18), 3, 1, 1000, 1000);

        // Token mint & add rewards
        await hxto.setMinter(deployer.address, true);
        await hxto.mint(deployer.address, expandDecimals(25000, 18));
        await lockupCampaign.addRewards();
    })

    it('should revert if not verified yet', async () => {
        await expect(lockupCampaign.participate(hre.ethers.constants.AddressZero, deployer.address, defaultLinkBytes, hre.ethers.constants.AddressZero)).to.be.revertedWith('BaseSocialAction: Not verified yet');
    })

    it("calls participate by root user", async () => {
        const beforePoolRewardTokenAmount = BigInt(await lockupCampaign.rewardTokenPoolAmount());
        
        await lockupCampaignSocialAction.setFulfilled(deployer.address);
        
        await lockupCampaign.participate(hre.ethers.constants.AddressZero, deployer.address, defaultLinkBytes, hre.ethers.constants.AddressZero);
        
        const afterPoolRewardTokenAmount = BigInt(await lockupCampaign.rewardTokenPoolAmount());

        // Root user info check
        const rootUserInfo = await lockupCampaign.userInfo(deployer.address);
        expect(rootUserInfo.link).to.equal(defaultLinkBytes);
        expect(rootUserInfo.referral).to.equal(hre.ethers.constants.AddressZero);
        expect(rootUserInfo.participationRewardAmount).to.equal((await lockupCampaign.participationRewardTokenAmount()).toString());
        expect(rootUserInfo.participationRewardDebt).to.equal(0);

        // Remain participation reward check
        expect((beforePoolRewardTokenAmount - afterPoolRewardTokenAmount).toString()).to.equal((await lockupCampaign.participationRewardTokenAmount()).toString());
    });

    it("calls participate by direct referral user", async () => {
        const beforePoolRewardTokenAmount = BigInt(await lockupCampaign.rewardTokenPoolAmount());
        const beforePoolHxtoAmount = BigInt(await lockupCampaign.hxtoPoolAmount());
        await lockupCampaignSocialAction.setFulfilled(user1.address);

        await lockupCampaign.participate(deployer.address, user1.address, defaultLinkBytes, hre.ethers.constants.AddressZero);

        const afterPoolRewardTokenAmount =BigInt(await lockupCampaign.rewardTokenPoolAmount());
        const afterPoolHxtoAmount = BigInt(await lockupCampaign.hxtoPoolAmount());

        // Root user info check
        const rootUserInfo = await lockupCampaign.userInfo(deployer.address);
        expect(rootUserInfo.referralHxtoAmount.toString()).to.equal((await lockupCampaign.directReferralHxtoAmount()).toString());

        // Referral user info check
        const referralUserInfo = await lockupCampaign.userInfo(user1.address);
        expect(referralUserInfo.link).to.equal(defaultLinkBytes);
        expect(referralUserInfo.referral).to.equal(deployer.address);
        expect(referralUserInfo.participationRewardAmount).to.equal((await lockupCampaign.participationRewardTokenAmount()).toString());
        expect(referralUserInfo.participationRewardDebt).to.equal(0);

        // Remain participaiton reward check
        expect((beforePoolRewardTokenAmount - afterPoolRewardTokenAmount).toString()).to.equal((await lockupCampaign.participationRewardTokenAmount()).toString());

        // Remain referral reward check
        expect((beforePoolHxtoAmount - afterPoolHxtoAmount).toString()).to.equal((await lockupCampaign.directReferralHxtoAmount()).toString());
    });

    it("calls participate by indirect referral user", async () => {
        const beforePoolRewardTokenAmount = BigInt(await lockupCampaign.rewardTokenPoolAmount());
        const beforePoolHxtoAmount = BigInt(await lockupCampaign.hxtoPoolAmount());
        await lockupCampaignSocialAction.setFulfilled(user2.address);

        await lockupCampaign.participate(user1.address, user2.address, defaultLinkBytes, hre.ethers.constants.AddressZero);

        const afterPoolRewardTokenAmount = BigInt(await lockupCampaign.rewardTokenPoolAmount());
        const afterPoolHxtoAmount = BigInt(await lockupCampaign.hxtoPoolAmount());

        // Root user info check
        const rootUserInfo = await lockupCampaign.userInfo(deployer.address);
        expect(rootUserInfo.referralHxtoAmount.toString()).to.equal((BigInt(await lockupCampaign.directReferralHxtoAmount()) + BigInt(await lockupCampaign.indirectReferralHxtoAmount())).toString());

        // Direct referral user info check
        const referralUserInfo = await lockupCampaign.userInfo(user1.address);
        expect(referralUserInfo.referralHxtoAmount).to.equal(await lockupCampaign.directReferralHxtoAmount());

        // Indirect referral user info check
        const indirectReferralUserInfo = await lockupCampaign.userInfo(user2.address);
        expect(indirectReferralUserInfo.link).to.equal(defaultLinkBytes);
        expect(indirectReferralUserInfo.referral).to.equal(user1.address);
        expect(indirectReferralUserInfo.participationRewardAmount).to.equal((await lockupCampaign.participationRewardTokenAmount()).toString());
        expect(indirectReferralUserInfo.participationRewardDebt).to.equal(0);

        // Remain participaiton reward check
        expect((beforePoolRewardTokenAmount - afterPoolRewardTokenAmount).toString()).to.equal((await lockupCampaign.participationRewardTokenAmount()).toString());

        // Remain referral reward check
        expect((beforePoolHxtoAmount - afterPoolHxtoAmount).toString()).to.equal((BigInt(await lockupCampaign.directReferralHxtoAmount()) + BigInt(await lockupCampaign.indirectReferralHxtoAmount())).toString());
    });

    it('should revert if not claimable yet', async () => {
        await expect(lockupCampaign.claimParticipationReward(deployer.address)).to.be.revertedWith("BaseCampaign: Can't claim yet");
    });

    it("checks root user's claim amount", async () => {
        await timelock.signalSetIsClaimable(lockupCampaign.address, true);
        await timelock.connect(user1).signSetIsClaimable(lockupCampaign.address, true);
        await timelock.connect(user1).setIsClaimable(lockupCampaign.address, true);

        await lockupCampaignSocialAction.setFulfilled(user3.address);

        await lockupCampaign.participate(deployer.address, user3.address, defaultLinkBytes, hre.ethers.constants.AddressZero);

        const beforeClaimParticipationReward = BigInt(await hxto.balanceOf(deployer.address)); 

        await lockupCampaign.claimParticipationReward(deployer.address);

        const afterClaimParticipationReward = BigInt(await hxto.balanceOf(deployer.address)); 

        expect((afterClaimParticipationReward - beforeClaimParticipationReward)).to.equal((await lockupCampaign.participationRewardTokenAmount()));

        await lockupCampaign.claimReferralReward(deployer.address);

        // Root user info check
        const rootUserInfo = await lockupCampaign.userInfo(deployer.address);

        expect(rootUserInfo.referralHxtoAmount.toString()).to.equal((BigInt(await lockupCampaign.directReferralHxtoAmount()) * BigInt(2) + BigInt(await lockupCampaign.indirectReferralHxtoAmount())).toString());
        expect(rootUserInfo.referralHxtoDebt.toString()).to.equal((BigInt(await lockupCampaign.directReferralHxtoAmount()) * BigInt(2)).toString());

        expect(BigInt(await esHXTO.balanceOf(deployer.address)).toString()).to.equal((BigInt(await lockupCampaign.directReferralHxtoAmount()) * BigInt(2)).toString());
    });

    it("should revert if the minimum campaign time is not over", async () => {
        await timelock.signalSetExitTrigger(lockupCampaign.address, true, deployer.address);
        await timelock.connect(user1).signSetExitTrigger(lockupCampaign.address, true, deployer.address);
        await expect(timelock.setExitTrigger(lockupCampaign.address, true, deployer.address)).to.be.revertedWith("BaseCampaign: Can not exit during campaign period");
    });

    it("calls exit campaign", async () => {
        increaseTime(hre.ethers.provider, 60 * 60 * 24 * 30);
        mineBlock(hre.ethers.provider);

        const beforeHxtoPoolAmount = await lockupCampaign.hxtoPoolAmount();
        const beforeRewardTokenPoolAmount = await lockupCampaign.rewardTokenPoolAmount();

        const beforeBalanceOfReceiver = await hxto.balanceOf(deployer.address);
        const beforeBalanceOfTreasury = await hxto.balanceOf(user5.address);

        await timelock.setExitTrigger(lockupCampaign.address, true, deployer.address);
        await lockupCampaign.exit();

        const afterBalanceOfReceiver = await hxto.balanceOf(deployer.address);
        const afterBalanceOfTreasury = await hxto.balanceOf(user5.address);

        expect((BigInt(beforeHxtoPoolAmount) + BigInt(beforeRewardTokenPoolAmount))).to.equal(
            (BigInt(afterBalanceOfReceiver) - BigInt(beforeBalanceOfReceiver)) +
            (BigInt(afterBalanceOfTreasury) - BigInt(beforeBalanceOfTreasury))
        );
    });

    it("calls claim through direct referral after exiting", async () => {
        await lockupCampaign.claimReferralReward(user1.address);

        // Direct user info check
        const directUserInfo = await lockupCampaign.userInfo(user1.address);

        expect(directUserInfo.referralHxtoAmount.toString()).to.equal((BigInt(await lockupCampaign.directReferralHxtoAmount())).toString());
        expect(directUserInfo.referralHxtoDebt.toString()).to.equal((BigInt(await lockupCampaign.directReferralHxtoAmount())).toString());

        expect(BigInt(await esHXTO.balanceOf(user1.address)).toString()).to.equal((BigInt(await lockupCampaign.directReferralHxtoAmount())).toString());
    })
})