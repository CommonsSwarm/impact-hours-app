const { assertRevert } = require('@aragon/contract-helpers-test/src/asserts')
const ImpactHours = artifacts.require('ImpactHours')
const MiniMeToken = artifacts.require('MiniMeToken')
const MiniMeTokenFactory = artifacts.require('MiniMeTokenFactory')
const Hatch = artifacts.require('HatchMock')
const TokenManager = artifacts.require('TokenManagerMock')

const { newDao, installNewApp, ANY_ENTITY } = require('@aragon/contract-helpers-test/src/aragon-os')
const { assertBn } = require('@aragon/contract-helpers-test/src/asserts')

const { hash: nameHash } = require('eth-ens-namehash')
const { bn, bigExp } = require('@aragon/contract-helpers-test/src/numbers')
const ZERO_ADDR = '0x' + '0'.repeat(40)

contract(
  'ImpactHours',
  ([appManager, accountIH90, accountIH10]) => {
    let impactHoursBase, tokenManagerBase, hatchBase, impactHours, hatch, hatchToken, impactHoursToken18, impactHoursToken10, tokenFactory
    let MINT_ROLE, CLOSE_ROLE

    const PPM = 1000000
    const EXCHANGE_RATE = 10 * PPM
    const MAX_RATE = 100
    const EXPECTED_RAISE = bigExp(100, 18)

    before('deploy base apps', async () => {
      impactHoursBase = await ImpactHours.new()
      tokenManagerBase = await TokenManager.new()
      hatchBase = await Hatch.new()
      tokenFactory = await MiniMeTokenFactory.new()
      MINT_ROLE = await tokenManagerBase.MINT_ROLE()
      CLOSE_ROLE = await hatchBase.CLOSE_ROLE()
    })

    before('create tokens', async () => {
      const initializeToken = async (decimals) => {
        const impactHoursToken = await MiniMeToken.new(tokenFactory.address, ZERO_ADDR, 0, "Impact Hours", decimals, "IH", false, { from: appManager })
        await impactHoursToken.generateTokens(accountIH90, bigExp(90, decimals))
        await impactHoursToken.generateTokens(accountIH10, bigExp(10, decimals))
        return impactHoursToken
      }
      impactHoursToken18 = await initializeToken(18)
      impactHoursToken10 = await initializeToken(10)
    })

    beforeEach('deploy dao and apps', async () => {
      ({dao, acl} = await newDao(appManager))

      impactHours = await ImpactHours.at(await installNewApp(
        dao,
        nameHash('impact-hours.aragonpm.test'),
        impactHoursBase.address,
        appManager
      ))

      tokenManager = await TokenManager.at(await installNewApp(
        dao,
        nameHash('token-manager.aragonpm.test'),
        tokenManagerBase.address,
        appManager
      ))

      hatch = await Hatch.at(await installNewApp(
        dao,
        nameHash('hatch.aragonpm.test'),
        hatchBase.address,
        appManager
      ))

      hatchToken = await MiniMeToken.new(tokenFactory.address, ZERO_ADDR, 0, "Community Token", 18, "CT", true, { from: appManager })

      await hatchToken.changeController(tokenManager.address, { from: appManager })
      await tokenManager.initialize(hatchToken.address)
      await hatch.initialize(tokenManager.address, EXCHANGE_RATE)

      await acl.createPermission(impactHours.address, tokenManager.address, MINT_ROLE, appManager)
      await acl.createPermission(impactHours.address, hatch.address, CLOSE_ROLE, appManager)
    })

    describe('initialize(MiniMeToken _token, address _hatch, uint256 _maxRate, uint256 _expectedRaise)', () => {
      beforeEach('initialize impact hours', async () => {
        await impactHours.initialize(impactHoursToken18.address, hatch.address, MAX_RATE, EXPECTED_RAISE)
      })

      it('sets variables as expected', async () => {
        const actualHatch = await impactHours.hatch()
        const actualMaxRate = await impactHours.maxRate()
        const actualExpectedRaise = await impactHours.expectedRaise()
        const hasInitialized = await impactHours.hasInitialized()

        assert.strictEqual(actualHatch, hatch.address)
        assert.strictEqual(actualMaxRate.toString(), MAX_RATE.toString())
        assert.strictEqual(actualExpectedRaise.toString(), EXPECTED_RAISE.toString())
        assert.isTrue(hasInitialized)
      })

      it('has cloned the token and the control is kept by the impact hours contract', async () => {
        const actualToken = await MiniMeToken.at(await impactHours.token())
        assert.strictEqual(await actualToken.parentToken(), impactHoursToken18.address)
        assert.strictEqual(await actualToken.controller(), impactHours.address)
      })

      it('reverts on reinitialization', async () => {
        await assertRevert(
          impactHours.initialize(impactHoursToken18.address, hatch.address, MAX_RATE, EXPECTED_RAISE),
          'INIT_ALREADY_INITIALIZED'
        )
      })
    })

    describe('claimReward(address[] _contributors)', async () => {
      beforeEach('initialize impact hours', async () => {
        await impactHours.initialize(impactHoursToken18.address, hatch.address, MAX_RATE, EXPECTED_RAISE)
      })

      it('can not claim if state is Pending', async () => {
        await hatch.setState(0) // Pending
        await assertRevert(impactHours.claimReward([accountIH90, accountIH10]), 'IH_HATCH_NOT_GOAL_REACHED')
      })

      it('can not claim if state is Funding', async () => {
        await hatch.setState(1) // Funding
        await assertRevert(impactHours.claimReward([accountIH90, accountIH10]), 'IH_HATCH_NOT_GOAL_REACHED')
      })

      it('can not claim if state is Refunding', async () => {
        await hatch.setState(2) // Refunding
        await assertRevert(impactHours.claimReward([accountIH90, accountIH10]), 'IH_HATCH_NOT_GOAL_REACHED')
      })

      it('can claim if state is Goal Reached', async () => {
        await hatch.setState(3) // Goal Reached
        await impactHours.claimReward([accountIH90, accountIH10])
      })

      it('can not claim if state is Closed', async () => {
        await hatch.setState(4) // Closed
        await assertRevert(impactHours.claimReward([accountIH90, accountIH10]), 'IH_HATCH_NOT_GOAL_REACHED')
      })

      it('destroys impact hours tokens when they are claimed', async() => {
        await hatch.setState(3)
        await impactHours.claimReward([accountIH90, accountIH10])
        const clonedToken = await MiniMeToken.at(await impactHours.token())
        assertBn(await clonedToken.balanceOf(accountIH90), bn(0))
        assertBn(await clonedToken.balanceOf(accountIH10), bn(0))
        assertBn(await clonedToken.totalSupply(), bn(0))
      })
    })

    const reward = async (amount, tokenDecimals, maxRate, expectedRaise, raised) =>
      await hatch.contributionToTokens(amount.mul(maxRate).div(bigExp(1, tokenDecimals)).mul(raised).div(raised.add(expectedRaise)))
    const loop = f => {
      for (let maxRate of [10, 100]) {
        for (let expectedRaise of [100, 10000]) {
          for (let raised of [0, 1000, 100000000]) {
            it(
              `maxRate = ${maxRate}, expectedRaise = ${expectedRaise}, totalRaised = ${raised}`,
              () => f(bigExp(maxRate, 18), bigExp(expectedRaise, 18), bigExp(raised, 18))
            )
          }
        }
      }
    }

    const rewardTest = (impactHoursTokenDecimals) => {
      loop(async (maxRate, expectedRaise, raised) => {
        impactHoursToken = impactHoursTokenDecimals === 18 ? impactHoursToken18 : impactHoursToken10
        await impactHours.initialize(impactHoursToken.address, hatch.address, maxRate, expectedRaise)
        assertBn(
          await impactHours.reward(raised, accountIH90),
          await reward(await impactHoursToken.balanceOf(accountIH90), impactHoursTokenDecimals, maxRate, expectedRaise, raised)
        )
        assertBn(
          await impactHours.reward(raised, accountIH10),
          await reward(await impactHoursToken.balanceOf(accountIH10), impactHoursTokenDecimals, maxRate, expectedRaise, raised)
        )
      })
    }

    describe('reward(uint256 totalRaised, address contributor', () => {
      context('Impact hours token with 18 decimals', () => rewardTest(18))
      context('Impact hours token with 10 decimals', () => rewardTest(10))
    })

    describe('claimReward(address[] _contributors)', async() => {
      loop(async (maxRate, expectedRaise, raised) => {
        await hatch.setState(3)
        await hatch.contribute(raised)
        await impactHours.initialize(impactHoursToken18.address, hatch.address, maxRate, expectedRaise)
        await impactHours.claimReward([accountIH90, accountIH10])
        for (let account of [accountIH90, accountIH10]) {
          const expectedReward = await reward(await impactHoursToken18.balanceOf(account), 18, maxRate, expectedRaise, raised)
          assertBn(await hatchToken.balanceOf(account), expectedReward)
        }
      })
    })

    describe('closeHatch()', async() => {
      beforeEach('initialize impact hours', async () => {
        await impactHours.initialize(impactHoursToken18.address, hatch.address, MAX_RATE, EXPECTED_RAISE)
      })

      context('with permission', async() => {
        beforeEach('add CLOSE_ROLE permission', async() => {
          await acl.createPermission(ANY_ENTITY, impactHours.address, CLOSE_ROLE, appManager)
        })

        it('can perform when all cloned impact hour tokens have been burned', async() => {
          await hatch.setState(3)
          await impactHours.claimReward([accountIH90, accountIH10])
          await impactHours.closeHatch()
          assert.strictEqual((await hatch.state()).toNumber(), 4)
        })
  
        it('can not perform when not all cloned impact hour tokens have been burned', async() => {
          await hatch.setState(3)
          await impactHours.claimReward([accountIH90])
          await assertRevert(impactHours.closeHatch(), 'ERROR_IMPACT_HOURS_NOT_FULLY_CLAIMED')
        })
      })

      it('can not close hatch if addess do not have permission', async() => {
        await hatch.setState(3)
        await impactHours.claimReward([accountIH90, accountIH10])
        await assertRevert(impactHours.closeHatch(), 'APP_AUTH_FAILED')
      })
    })
  }
)
