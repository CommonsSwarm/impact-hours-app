# Impact Hours

The Impact Hours app complements the [Hatch app](https://github.com/tecommons/hatch-app). When the Hatch has reached it's goal, the Impact Hours app mints tokens for IH contributors at a rate dependant of how much funds the Hatch has raised.

The code in this repo has not been audited.

## How does it work?

The more funds that are raised, the higher the hourly wage for impact hours becomes. Additionally, the more funds that are raised, the lower the portion of tokens that go to pay for Impact Hours. These two properties mean working hatchers are incentivised to raise more funds, and funding hatchers are incentivised to invest more funds.

## Initialization

The Impact Hours is initialized with `address _hatch`, `uint256 _maxRate_`, and `uint256 _expectedRaisePerIH` parameters.
- The `address _hatch` parameter is the address of the Hatch that Impact Hours are for.
- The `uint256 _maxRate` and `uint256 _expectedRaisePerIH` are used to determine how much tokens will be minted per IH based on the total raised amount.

We determine the rate of each impact hour with the following formula where the independent variable (x) is the total funds raised:

![R*x/(x+m*H)](https://forum.tecommons.org/uploads/default/original/1X/ed187f4401c6a8901199a6bf1e5916eec597905d.png)

The formula has three parameters:
* _H_ : Total number of impact hours.
* _m_ : Expected raise per impact hour, in which the rate is half the max rate. A low number makes a more curved function, whereas a high number flattens the curve.
* _R_ : Max IH rate limit. It’s an asymptotic limit never reached, no matter how much funds are raised.

## Roles

The Impact Hours app should implement the following roles:
- **ADD_IMPACT_HOURS_ROLE**: This allows for changing the token address that the Hatch Oracle tracks.

The Impact Hours app should have the following roles:
- **MINT_ROLE**: It should be able to mint tokens in the Hatch's Token Manager.

The Impact Hours app can be used as ACL oracle for the following role:
- **CLOSE_ROLE**: It can prevent calling the Hatch's `close()` function if all impact hours has not been claimed.

## Interface

The Hatch Oracle does not have an interface. It is meant as a back-end contract to be used with other Aragon applications.

## How to run Hatch Oracle locally

The Impact Hours app works in tandem with other Aragon applications. While we do not explore this functionality as a stand alone demo, the [TEC template](https://github.com/TECommons/tec-template) uses the Impact Hours and it can be run locally.

## Deploying to an Aragon DAO

TBD

## Contributing

We welcome community contributions!

Please check out our [open Issues](https://github.com/TECommons/impact-hours/issues) to get started.

If you discover something that could potentially impact security, please notify us immediately. The quickest way to reach us is via the #dev channel in our [Discord chat](https://discord.gg/n58U4hA). Just say hi and that you discovered a potential security vulnerability and we'll DM you to discuss details.
