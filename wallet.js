const HDWalletProvider = require('@truffle/hdwallet-provider');
const Web3 = require('web3');
var {abi, evm} = require('./compile.js');
const bytecode = evm.bytecode.object;
const abi_string = JSON.stringify(abi)

const mnemonic = 'kit soup smoke curtain noise logic end maple remove true march inherit';

const ropsten_network = 'https://data-seed-prebsc-1-s1.binance.org:8545';

const provider = new HDWalletProvider(mnemonic, ropsten_network);

const web3 = new Web3(provider);
var myVestingContract = new web3.eth.Contract(abi, '0x42E3A2Ce253Ae68F51513C6b91c1b58341074277');

let b = myVestingContract.methods.getCustomer('anar').call();

b.then(res => {console.log(res)});