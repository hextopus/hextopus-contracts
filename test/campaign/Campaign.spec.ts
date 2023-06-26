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
    let user4;
    let user5;

    let hxto;
    let esHXTO;
    let staker;
    let campaignReader;
    let timelock;
    let socialAction;
    let campaign;

    const defaultLinkBytes = "0x44454641554c5400000000000000000000000000000000000000000000000000";

    before(async () => {
        [deployer, user1, user2, user3, user4, user5] = await hre.ethers.getSigners();

        ({ hxto, esHXTO, staker, campaignReader, timelock, socialAction, campaign } = await hextopusProtocolFixture());

        // Campaign setting
        await timelock.setCampaignManager(campaign.address, deployer.address, true);
        await timelock.setCampaignManager(campaign.address, user1.address, true);

        await timelock.signalSetBeforeAddRewards(campaign.address, BigInt(100 * Math.pow(10, 18)).toString(), BigInt(100 * Math.pow(10, 18)).toString(), 2, 1, 5, 4);
        await timelock.connect(user1).signSetBeforeAddRewards(campaign.address, BigInt(100 * Math.pow(10, 18)).toString(), BigInt(100 * Math.pow(10, 18)).toString(), 2, 1, 5, 4);
        await timelock.connect(user1).setBeforeAddRewards(campaign.address, BigInt(100 * Math.pow(10, 18)).toString(), BigInt(100 * Math.pow(10, 18)).toString(), 2, 1, 5, 4);

        // Token mint & add rewards
        await hxto.setMinter(deployer.address, true);
        await hxto.mint(deployer.address, expandDecimals(1000, 18));
        await campaign.addRewards();
    })

    it('should revert if not verified yet', async () => {
        await expect(campaign.participate(hre.ethers.constants.AddressZero, deployer.address, defaultLinkBytes, hre.ethers.constants.AddressZero)).to.be.revertedWith('BaseSocialAction: Not verified yet');
    })

    it("calls participate by root user", async () => {
        const beforeRewardTokenAmount = await hxto.balanceOf(deployer.address);
        const beforePoolRewardTokenAmount = await campaign.rewardTokenPoolAmount();

        await socialAction.setFulfilled(deployer.address);

        await campaign.participate(hre.ethers.constants.AddressZero, deployer.address, defaultLinkBytes, hre.ethers.constants.AddressZero);

        const afterRewardTokenAmount = await hxto.balanceOf(deployer.address);
        const afterPoolRewardTokenAmount = await campaign.rewardTokenPoolAmount();

        // Root user info check
        const rootUserInfo = await campaign.userInfo(deployer.address);
        expect(rootUserInfo.link).to.equal(defaultLinkBytes);
        expect(rootUserInfo.referral).to.equal(hre.ethers.constants.AddressZero);

        // Claimed participation reward check
        expect((afterRewardTokenAmount - beforeRewardTokenAmount).toString()).to.equal((await campaign.participationRewardTokenAmount()).toString());

        // Remain participation reward check
        expect((beforePoolRewardTokenAmount - afterPoolRewardTokenAmount).toString()).to.equal((await campaign.participationRewardTokenAmount()).toString());
    });

    it("calls participate by direct referral user", async () => {
        const beforeRewardTokenAmount = await hxto.balanceOf(user1.address);
        const beforePoolRewardTokenAmount = await campaign.rewardTokenPoolAmount();
        const beforePoolHxtoAmount = await campaign.hxtoPoolAmount();
        await socialAction.setFulfilled(user1.address);

        await campaign.participate(deployer.address, user1.address, defaultLinkBytes, hre.ethers.constants.AddressZero);

        const afterRewardTokenAmount = await hxto.balanceOf(user1.address);
        const afterPoolRewardTokenAmount = await campaign.rewardTokenPoolAmount();
        const afterPoolHxtoAmount = await campaign.hxtoPoolAmount();

        // Root user info check
        const rootUserInfo = await campaign.userInfo(deployer.address);
        expect(rootUserInfo.referralHxtoAmount.toString()).to.equal((await campaign.directReferralHxtoAmount()).toString());

        // Referral user info check
        const referralUserInfo = await campaign.userInfo(user1.address);
        expect(referralUserInfo.link).to.equal(defaultLinkBytes);
        expect(referralUserInfo.referral).to.equal(deployer.address);

        // Claimed participation reward check
        expect((afterRewardTokenAmount - beforeRewardTokenAmount).toString()).to.equal((await campaign.participationRewardTokenAmount()).toString());

        // Remain participaiton reward check
        expect((beforePoolRewardTokenAmount - afterPoolRewardTokenAmount).toString()).to.equal((await campaign.participationRewardTokenAmount()).toString());

        // Remain referral reward check
        expect((BigInt(beforePoolHxtoAmount) - BigInt(afterPoolHxtoAmount)).toString()).to.equal((await campaign.directReferralHxtoAmount()).toString());
    });

    it("calls participate by indirect referral user", async () => {
        const beforePoolRewardTokenAmount = await campaign.rewardTokenPoolAmount();
        const beforePoolHxtoAmount = await campaign.hxtoPoolAmount();
        await socialAction.setFulfilled(user2.address);

        await campaign.participate(user1.address, user2.address, defaultLinkBytes, hre.ethers.constants.AddressZero);

        const afterPoolRewardTokenAmount = await campaign.rewardTokenPoolAmount();
        const afterPoolHxtoAmount = await campaign.hxtoPoolAmount();

        // Root user info check
        const rootUserInfo = await campaign.userInfo(deployer.address);
        expect(rootUserInfo.referralHxtoAmount.toString()).to.equal((BigInt(await campaign.directReferralHxtoAmount()) + BigInt(await campaign.indirectReferralHxtoAmount())).toString());

        // Direct referral user info check
        const referralUserInfo = await campaign.userInfo(user1.address);
        expect(referralUserInfo.referralHxtoAmount).to.equal(await campaign.directReferralHxtoAmount());

        // Indirect referral user info check
        const indirectReferralUserInfo = await campaign.userInfo(user2.address);
        expect(indirectReferralUserInfo.link).to.equal(defaultLinkBytes);
        expect(indirectReferralUserInfo.referral).to.equal(user1.address);

        // Remain participaiton reward check
        expect((BigInt(beforePoolRewardTokenAmount) - BigInt(afterPoolRewardTokenAmount)).toString()).to.equal((await campaign.participationRewardTokenAmount()).toString());

        // Remain referral reward check
        expect((BigInt(beforePoolHxtoAmount) - BigInt(afterPoolHxtoAmount)).toString()).to.equal((BigInt(await campaign.directReferralHxtoAmount()) + BigInt(await campaign.indirectReferralHxtoAmount())).toString());
    });

    it("checks root user's claim amount", async () => {
        await socialAction.setFulfilled(user3.address);

        await campaign.participate(deployer.address, user3.address, defaultLinkBytes, hre.ethers.constants.AddressZero);

        await campaign.claim(deployer.address);

        // Root user info check
        const rootUserInfo = await campaign.userInfo(deployer.address);

        expect(rootUserInfo.referralHxtoAmount.toString()).to.equal((BigInt(await campaign.directReferralHxtoAmount()) * BigInt(2) + BigInt(await campaign.indirectReferralHxtoAmount())).toString());
        expect(rootUserInfo.referralHxtoDebt.toString()).to.equal((BigInt(await campaign.directReferralHxtoAmount()) * BigInt(2)).toString());

        expect(BigInt(await esHXTO.balanceOf(deployer.address)).toString()).to.equal((BigInt(await campaign.directReferralHxtoAmount()) * BigInt(2)).toString());
    });

    it("checks root user's additional cap by staking", async () => {
        let requiredAmount = (await campaignReader.getHxtoRequirement(deployer.address, "0")).toString();

        await campaign.claim(deployer.address);
        await hxto.approve(staker.address, requiredAmount);
        await staker.stake(requiredAmount, 3);

        requiredAmount = (await campaignReader.getHxtoRequirement(deployer.address, "0")).toString();

        expect(requiredAmount).to.equal("0");

        await campaign.claim(deployer.address);

        // Root user info check
        const rootUserInfo = await campaign.userInfo(deployer.address);

        expect(rootUserInfo.referralHxtoAmount.toString()).to.equal((BigInt(await campaign.directReferralHxtoAmount()) * BigInt(2) + BigInt(await campaign.indirectReferralHxtoAmount())).toString());
        expect(rootUserInfo.referralHxtoDebt.toString()).to.equal(rootUserInfo.referralHxtoAmount.toString());
    });

    it("should revert if the minimum campaign time is not over", async () => {
        await timelock.signalSetExitTrigger(campaign.address, true, deployer.address);
        await timelock.connect(user1).signSetExitTrigger(campaign.address, true, deployer.address);
        await expect(timelock.setExitTrigger(campaign.address, true, deployer.address)).to.be.revertedWith("BaseCampaign: Can not exit during campaign period");
    });

    it("calls exit campaign", async () => {
        increaseTime(hre.ethers.provider, 60 * 60 * 24 * 30);
        mineBlock(hre.ethers.provider);

        const beforeHxtoPoolAmount = await campaign.hxtoPoolAmount();
        const beforeRewardTokenPoolAmount = await campaign.rewardTokenPoolAmount();

        const beforeBalanceOfReceiver = await hxto.balanceOf(deployer.address);
        const beforeBalanceOfTreasury = await hxto.balanceOf(user5.address);

        await timelock.setExitTrigger(campaign.address, true, deployer.address);
        await campaign.exit();

        const afterBalanceOfReceiver = await hxto.balanceOf(deployer.address);
        const afterBalanceOfTreasury = await hxto.balanceOf(user5.address);

        expect((BigInt(beforeHxtoPoolAmount) + BigInt(beforeRewardTokenPoolAmount))).to.equal(
            (BigInt(afterBalanceOfReceiver) - BigInt(beforeBalanceOfReceiver)) +
            (BigInt(afterBalanceOfTreasury) - BigInt(beforeBalanceOfTreasury))
        );
    });

    it("calls claim through direct referral after exiting", async () => {
        await campaign.claim(user1.address);

        // Direct user info check
        const directUserInfo = await campaign.userInfo(user1.address);

        expect(directUserInfo.referralHxtoAmount.toString()).to.equal((BigInt(await campaign.directReferralHxtoAmount())).toString());
        expect(directUserInfo.referralHxtoDebt.toString()).to.equal((BigInt(await campaign.directReferralHxtoAmount())).toString());

        expect(BigInt(await esHXTO.balanceOf(user1.address)).toString()).to.equal((BigInt(await campaign.directReferralHxtoAmount())).toString());
    })
})