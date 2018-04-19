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
      gas: 6000000,
      //gasPrice: 100e9,
      network_id: '4', // Match any network id
      from: "0x9f470a827b37d0970f794f814a298b32199f1c9e",
    }
  }
}
