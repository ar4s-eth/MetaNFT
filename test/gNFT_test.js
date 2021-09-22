const { assert } = require('chai')

const Color = artifacts.require('./gNFT.sol')

require('chai')
  .use(require('chai-as-promised'))
  .should()

contract('gNFT', (accounts) => {
    let contract

    before(async () => {
        contract = await Color.deployed()
    })

    describe('construtor', async() => {
        it('deploys successfully', async () => {
            const address = contract.address
            assert.notEqual(address, 0x0)
            assert.notEqual(address, '')
            assert.notEqual(address, null)
            assert.notEqual(address, undefined)
        })

        it('has a house', async () =>{
            const name = await contract.name();
            const symbol = await contract.symbol();
            assert.equal(name, "House");
            assert.equal(symbol, 'BUILDING');
        })
        
        it('has a attr of house', async () =>{
            const name = await contract.name(1);
            const symbol = await contract.symbol(1);
            assert.equal(name, "HOUSE");
            assert.equal(symbol, 'house');
        })

        it('has a attr of base', async () => {
            const name = await contract.name(2);
            const symbol = await contract.symbol(2);
            assert.equal(name, "BASE");
            assert.equal(symbol, 'base');
        })
    })

    describe('mint', async() => {
        it('getSubToken', async () => {
            //claim token of 818 building
            await contract.claim(818); 
            const result = await contract.getSubTokens(818);
            assert.equal(result[0], 101);
            assert.equal(result[1], 102);
            assert.equal(result[2], 103);
        })

        it('get attr name', async () => {

            //await contract.claim(818); 
            const result = await contract.getSubTokens(818);
            const house = await contract.name(818);
            assert.equal(result[0], 101);
            assert.equal(house, 'HOUSE');
        })
    })
})