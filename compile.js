//path module
const path = require('path');
//filesystem module
const fs = require('fs');
//solidity compiler module
const solc = require('solc');

const contractPath = path.resolve(__dirname, 'contracts', 'Metafluence.sol');
const source = fs.readFileSync(contractPath, 'utf8');

//compiling the contract

var input = {
    language: 'Solidity',
    sources: {
      'Metafluence.sol': {
        content: source,
      }
    },
    settings: {
      outputSelection: {
        '*': {
          '*': ['*']
        }
      }
    }
  };

  var output = JSON.parse(solc.compile(JSON.stringify(input)));

  console.log('==========================================', __filename, '=============================');
  console.log(output.contracts);

  module.exports = output.contracts['Metafluence.sol']['Metafluence'];