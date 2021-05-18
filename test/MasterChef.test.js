// Note that basic BEP20 functions will not be tested. Only custom code will have UTs.

// We are only testing masterchef, we don't want burn system to bring troubles :)
// More seriously, lp-pair tokens are not set under burn conditions
// This means we should not test masterchef with custom token but with a standard one
const MockBEP20 = artifacts.require('libs/MockBEP20');
const MasterChef = artifacts.require('MasterChef');
const Token = artifacts.require('Token');

const truffleAssert = require('truffle-assertions');

contract('Test MasterChef contract', async (accounts) => {
	const maxSupplyInt = 1000000;
	const deadAddress = '0x000000000000000000000000000000000000dEaD';
	const maxSupply = web3.utils.toWei(maxSupplyInt.toString());

	it("Don't allow more than 6% of LP's deposit fees", async () => {
		const masterChef = await MasterChef.new(
			deadAddress, // _token
			accounts[0], // _devaddr
			accounts[0], // _feeAddress
			1, // _tokenPerBlock
			0, // _startBlock
			false, // _devFees
			0, // _devFeesPercent
			1, // _baseEmissionRate
			3 // _maxEmissionRate
		);

		// Testing add() function
		await truffleAssert.reverts(
			masterChef.add(100, deadAddress, 601, true),
			'add: invalid deposit fee basis points'
		);

		// Testing set() function (which update an existing pid)
		await masterChef.add(100, deadAddress, 100, true);
		await truffleAssert.reverts(
			masterChef.set(0, 100, 601, true),
			'set: invalid deposit fee basis points'
		);
	});

	it("Deposit to fee's wallet", async () => {
		const token = await MockBEP20.new('Test', 'test', maxSupply);
		await token.mint(maxSupply);

		const masterChef = await MasterChef.new(
			token.address, // _token
			accounts[0], // _devaddr
			accounts[1], // _feeAddress
			1, // _tokenPerBlock
			0, // _startBlock
			false, // _devFees
			0, // _devFeesPercent
			1, // _baseEmissionRate
			3 // _maxEmissionRate
		);

		await masterChef.add(100, token.address, 400, true);
		await token.approve(masterChef.address, 100);
		await masterChef.deposit(0, 100);

		assert.equal((await token.balanceOf(accounts[1])).toString(), '4');
	});

	it('Emission rate same as defined right after deployment', async () => {
		const token = await Token.new('Test', 'test', maxSupply);
		await token.mint(maxSupply);

		const masterChef = await MasterChef.new(
			token.address, // _token
			accounts[0], // _devaddr
			accounts[1], // _feeAddress
			web3.utils.toWei('1'), // _tokenPerBlock
			0, // _startBlock
			false, // _devFees
			0, // _devFeesPercent
			0, // _baseEmissionRate
			0 // _maxEmissionRate
		);

		assert.equal(
			web3.utils.fromWei(await masterChef.tokenPerBlock.call()),
			'1'
		);
	});

	it('Emission rate increases if current supply gets belows starting supply', async () => {
		const halfMaxSupply = web3.utils.toWei((maxSupplyInt / 2).toString());
		const token = await Token.new('Test', 'test', maxSupply);
		await token.mint(halfMaxSupply);

		const masterChef = await MasterChef.new(
			token.address, // _token
			accounts[0], // _devaddr
			accounts[0], // _feeAddress
			web3.utils.toWei('1'), // _tokenPerBlock
			0, // _startBlock
			false, // _devFees
			0, // _devFeesPercent
			web3.utils.toWei('1'), // _baseEmissionRate
			web3.utils.toWei('3') // _maxEmissionRate
		);

		assert.equal(
			web3.utils.fromWei(await masterChef.tokenPerBlock.call()),
			'1'
		);

		// Burn a part of the current supply to increase emission rate
		// Current supply = 400,000
		await token.transfer(deadAddress, web3.utils.toWei('100000'));

		// New emission rate will be calculated with the following
		// _baseEmissionRate * (token.maxSupply()/token.totalSupply()) - _baseEmissionRate
		// i.e: 1 * (1,000,000/400,000) - 1 = 1.5
		await masterChef.updateEmissionRatePerBlock();

		assert.equal(
			web3.utils.fromWei(await masterChef.tokenPerBlock.call()),
			'1.5'
		);
	});

	it('Emission rate get capped if current supply gets too much belows starting supply', async () => {
		const halfMaxSupply = web3.utils.toWei((maxSupplyInt / 2).toString());
		const token = await Token.new('Test', 'test', maxSupply);
		await token.mint(halfMaxSupply);

		const masterChef = await MasterChef.new(
			token.address, // _token
			accounts[0], // _devaddr
			accounts[0], // _feeAddress
			web3.utils.toWei('1'), // _tokenPerBlock
			0, // _startBlock
			false, // _devFees
			0, // _devFeesPercent
			web3.utils.toWei('1'), // _baseEmissionRate
			web3.utils.toWei('3') // _maxEmissionRate
		);

		assert.equal(
			web3.utils.fromWei(await masterChef.tokenPerBlock.call()),
			'1'
		);

		// Current supply = 100,000
		await token.transfer(deadAddress, web3.utils.toWei('400000'));
		await masterChef.updateEmissionRatePerBlock();

		assert.equal(
			web3.utils.fromWei(await masterChef.tokenPerBlock.call()),
			'3'
		);
	});

	it('Emission rate decreases if current supply gets higher than starting supply', async () => {
		const halfMaxSupply = web3.utils.toWei((maxSupplyInt / 2).toString());
		const token = await Token.new('Test', 'test', maxSupply);
		await token.mint(halfMaxSupply);

		const masterChef = await MasterChef.new(
			token.address, // _token
			accounts[0], // _devaddr
			accounts[0], // _feeAddress
			web3.utils.toWei('1'), // _tokenPerBlock
			0, // _startBlock
			false, // _devFees
			0, // _devFeesPercent
			web3.utils.toWei('1'), // _baseEmissionRate
			web3.utils.toWei('3') // _maxEmissionRate
		);

		assert.equal(
			web3.utils.fromWei(await masterChef.tokenPerBlock.call()),
			'1'
		);

		// Current supply = 800,000
		await token.mint(web3.utils.toWei('300000'));
		await masterChef.updateEmissionRatePerBlock();

		assert.equal(
			web3.utils.fromWei(await masterChef.tokenPerBlock.call()),
			'0.25'
		);
	});

	it("Emission rate decreases to 0 if current supply gets higher then (or is equal to) maximum supply's soft cap", async () => {
		const halfMaxSupply = web3.utils.toWei((maxSupplyInt / 2).toString());
		const token = await Token.new('Test', 'test', maxSupply);
		await token.mint(halfMaxSupply);

		const masterChef = await MasterChef.new(
			token.address, // _token
			accounts[0], // _devaddr
			accounts[0], // _feeAddress
			web3.utils.toWei('1'), // _tokenPerBlock
			0, // _startBlock
			false, // _devFees
			0, // _devFeesPercent
			web3.utils.toWei('1'), // _baseEmissionRate
			web3.utils.toWei('3') // _maxEmissionRate
		);

		assert.equal(
			web3.utils.fromWei(await masterChef.tokenPerBlock.call()),
			'1'
		);

		// Current supply = 800,000
		// Current supply = 1,000,000
		await token.mint(web3.utils.toWei('500000'));
		await masterChef.updateEmissionRatePerBlock();

		assert.equal(
			web3.utils.fromWei(await masterChef.tokenPerBlock.call()),
			'0'
		);

		// Current supply = 1,000,001
		await token.mint(web3.utils.toWei('1'));
		await masterChef.updateEmissionRatePerBlock();

		assert.equal(
			web3.utils.fromWei(await masterChef.tokenPerBlock.call()),
			'0'
		);
	});
});
