// Note that basic BEP20 functions will not be tested. Only custom code will have UTs.
const Token = artifacts.require('Token');
const MasterChef = artifacts.require('MasterChef');

contract('Test Token Dynamic Burn Rate', async () => {
	const maxSupplyInt = 1000000;
	const deadAddress = '0x000000000000000000000000000000000000dEaD';
	const maxSupply = web3.utils.toWei(maxSupplyInt.toString());

	it('2.5% of burn at start', async () => {
		const token = await Token.new('Test', 'test', maxSupply);
		assert.equal((await token.getCurrentBurnPercent()).toString(), '250');
	});

	it('1.25% burn when current supply is up to 25% or max supply', async () => {
		const oneFourthOfTotalSupply = web3.utils.toWei(
			(maxSupplyInt / 4).toString()
		);

		const token = await Token.new('Test', 'test', maxSupply);
		await token.mint(oneFourthOfTotalSupply);

		await token.transfer(deadAddress, 0);
		assert.equal((await token.getCurrentBurnPercent()).toString(), '125');
	});

	it('3.75% burn when current supply is up to 75% or max supply', async () => {
		const token = await Token.new('Test', 'test', maxSupply);
		await token.mint(maxSupply);

		// 1/4
		const oneFourthOfTotalSupply = web3.utils.toWei(
			(maxSupplyInt / 4).toString()
		);

		await token.transfer(deadAddress, oneFourthOfTotalSupply);
		assert.equal((await token.getCurrentBurnPercent()).toString(), '375');
	});

	it("5% (max) burn when current supply is above or equal to max supply's soft cap", async () => {
		const token = await Token.new('Test', 'test', maxSupply);
		await token.mint(maxSupply);

		// Transfer is updating the burn percentage
		await token.transfer(deadAddress, 0);
		assert.equal((await token.getCurrentBurnPercent()).toString(), '500');

		let moreSupply = web3.utils.toWei('1');
		// Add some supply to get above max
		await token.mint(moreSupply);

		// Transfer is updating the burn percentage
		await token.transfer(deadAddress, 0);
		assert.equal((await token.getCurrentBurnPercent()).toString(), '500');

		moreSupply = web3.utils.toWei('999999');
		// Add even more supply to get way above max
		await token.mint(moreSupply);

		// Transfer is updating the burn percentage
		await token.transfer(deadAddress, 0);
		assert.equal((await token.getCurrentBurnPercent()).toString(), '500');
	});

	it('0% burn when current supply below 10% of max supply', async () => {
		const tenthOfMaxSupply = web3.utils.toWei(
			(maxSupplyInt / 10 - 10).toString()
		);

		const token = await Token.new('Test', 'test', maxSupply);
		await token.mint(tenthOfMaxSupply);

		// Transfer is updating the burn percentage
		await token.transfer(deadAddress, 0);
		assert.equal((await token.getCurrentBurnPercent()).toString(), '0');
	});
});
