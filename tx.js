const HDWalletProvider = require('@truffle/hdwallet-provider');

Web3 = require('web3');

Contract = require('web3-eth-contract');
let contractAddress = '0x13ff27d013d8c8237a8881837dD529367EEd584a';
let testNetwork = 'https://data-seed-prebsc-1-s1.binance.org:8545';

const mnemonic = 'kit soup smoke curtain noise logic end maple remove true march inherit';

const provider = new HDWalletProvider(mnemonic, testNetwork);

web3 = new Web3(new Web3.providers.HttpProvider(testNetwork));

var accounts = web3.eth.getAccounts();

accounts.then(res => {
    console.log(res);
});


let balance = web3.eth.getBalance('0x6B6f5425206cD00694268017Aa62255856fDaA78');
balance.then(res => {
    console.log(res);
});

abiS = '';
var tokenInstance = new Contract(JSON.parse(abiS), '0x93461affe109b720d1c83261b74de3ff96885b60');
console.log(tokenInstance.methods);
// bal = tokenInstance.methods.balanceOf('0x6B6f5425206cD00694268017Aa62255856fDaA78');

// bal.then(res => {
//     console.log('cur balance', bal);
// })

// txs = [];
// var block = web3.eth.getBlock('latest');
// me = '0x6B6f5425206cD00694268017Aa62255856fDaA78';
// block.then(res => {

//     for (let txHash of res.transactions) {
//         let tr = web3.eth.getTransaction(txHash).then(resp => {
            
//             if (me == resp.to.toLowerCase()) {
//                 console.log('yesss');
//             } else {
//                 console.log(resp);
//             }

//         }).catch(err => console.log('opss'));
//     }

// });