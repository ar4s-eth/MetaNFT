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
        
        it('has a name', async () =>{
            const name = await contract.name()
            assert.equal(name, "Fox");
        })

        it('has a symbol', async () => {
            const symbol = await contract.symbol()
            assert.equal(symbol, 'Role');
        })

        it('add a attr with level', async () => {
            await contract.addAttr(0, 'Level', 'LEVEL', 0);
            const level = await contract.attrsName(0);
            assert.equal(level, 'Level');
        })

        it('add a attr with gender', async () => {
            await contract.addAttr(1, 'Gender', 'GENDER', 1);
            const gender = await contract.attrsName(1);
            assert.notEqual(gender, 'jjksjelj');
        })

        it('No exist in attrs', async () => {
            await contract.attrsName(2).should.be.rejected;
        })
    })
})