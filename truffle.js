// Allows us to use ES6 in our migrations and tests.
require('babel-register')

module.exports = {
  networks: {
    development: {
      host: '127.0.0.1',
      port: 7545,
      network_id: '*' // Match any network id
    },
    rinkeby: {
      host: 'localhost',
      port: 8545,
      gas: 4600000,
      gasprice: 100e9,
      network_id: '4', // Match any network id
      from: "0xf522e15C23145D4F934e393A147A6dbba0f16809",
    }
  }
}
